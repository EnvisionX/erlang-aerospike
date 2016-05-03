%%% @doc
%%% Aerospike connection pool implementation.

%%% @author Aleksey Morarash <aleksey.morarash@gmail.com>
%%% @since 03 May 2016
%%% @copyright 2016, Aleksey Morarash <aleksey.morarash@gmail.com>

-module(aerospike_pool).

-behaviour(gen_server).

%% API exports
-export(
   [start_link/2,
    set_hosts/2,
    next/1,
    connected/1,
    close/1,
    info/2,
    msg/5
   ]).

%% gen_server callback exports
-export(
   [init/1, handle_call/3, handle_info/2, handle_cast/2,
    terminate/2, code_change/3]).

-include("aerospike.hrl").
-include("aerospike_defaults.hrl").
-include("aerospike_constants.hrl").

%% --------------------------------------------------------------------
%% Internal signals
%% --------------------------------------------------------------------

%% to tell the client to close the connection and exit
-define(SIG_CLOSE, close).
-define(SIG_NEXT, next).
-define(SIG_CONNECTED, connected).
-define(SIG_RECONFIG, reconfig).
-define(SIG_HOSTS(Hosts), {hosts, Hosts}).

%% --------------------------------------------------------------------
%% Type definitions
%% --------------------------------------------------------------------

-export_types(
   [hosts/0,
    options/0,
    option/0
   ]).

-type hosts() :: [{aerospike_socket:host(), inet:port_number()}].

-type options() :: [option()].

-type option() ::
        {name, RegisteredName :: atom()} |
        {configure_period, Seconds :: number()} |
        {configurator, fun(() -> hosts())}.

%% --------------------------------------------------------------------
%% API functions
%% --------------------------------------------------------------------

%% @doc Start Aerospike connection pool
-spec start_link(Hosts :: hosts(), options()) ->
                        {ok, Pid :: pid()} | {error, Reason :: any()}.
start_link(Hosts, Options) ->
    gen_server:start_link(?MODULE, _Args = {Hosts, Options}, []).

%% @doc Reconfigure connection pool.
-spec set_hosts(PoolPID :: pid(), NewHosts :: hosts()) -> ok.
set_hosts(PoolPID, NewHosts) ->
    ok = gen_server:cast(PoolPID, ?SIG_HOSTS(NewHosts)).

%% @doc Get next active connection.
-spec next(PoolPID :: pid()) -> {ok, ConnPID :: pid()} | not_connected.
next(PoolPID) ->
    gen_server:call(PoolPID, ?SIG_NEXT).

%% @doc Return 'true' if at least one connection is established
%% and 'false' otherwise.
-spec connected(PoolPID :: pid()) -> boolean().
connected(PoolPID) ->
    gen_server:call(PoolPID, ?SIG_CONNECTED).

%% @doc Close the connection pool. Calling the function for already terminated
%% process is allowed.
-spec close(PoolPID :: pid()) -> ok.
close(PoolPID) ->
    _Sent = PoolPID ! ?SIG_CLOSE,
    ok.

%% @doc Return Aerospike cluster information.
-spec info(PoolPID :: pid(), Timeout :: timeout()) ->
                  {ok, aerospike_socket:info()} | {error, Reason :: any()}.
info(PoolPID, Timeout) ->
    case next(PoolPID) of
        {ok, Socket} ->
            aerospike_socket:info(Socket, Timeout);
        not_connected = Reason ->
            {error, Reason}
    end.

%% @doc Send AerospikeMessage (AS_MSG) request to the Aerospike node,
%% receive and decode response.
-spec msg(PoolPID :: pid(),
          Fields :: list(),
          Ops :: list(),
          Options :: aerospike_socket:msg_options(),
          Timeout :: timeout()) ->
                 {ok, Response :: any()} | {error, Reason :: any()}.
msg(PoolPID, Fields, Ops, Options, Timeout) ->
    case next(PoolPID) of
        {ok, Socket} ->
            aerospike_socket:msg(Socket, Fields, Ops, Options, Timeout);
        not_connected = Reason ->
            {error, Reason}
    end.

%% ----------------------------------------------------------------------
%% gen_server callbacks
%% ----------------------------------------------------------------------

-record(
   state,
   {options :: options(),
    hosts = [] :: [{aerospike_socket:host(), inet:port_number(),
                    Worker :: pid()}],
    active = sets:new() :: sets:set(ConnectedWorker :: pid()),
    queue = [] :: [ConnectedWorker :: pid()]
   }).

%% @hidden
-spec init({hosts(), options()}) ->
                  {ok, InitialState :: #state{}} |
                  {stop, Reason :: any()}.
init({Hosts0, Options}) ->
    ?trace("init(~9999, ~9999p)", [Hosts0, Options]),
    case lists:keyfind(name, 1, Options) of
        {name, RegisteredName} ->
            true = register(RegisteredName, self()),
            ok;
        false ->
            ok
    end,
    Hosts = apply_hosts([], Hosts0),
    case proplists:is_defined(configurator, Options) of
        true ->
            %% schedule first reconfig immediately
            _Sent = self() ! ?SIG_RECONFIG,
            ok;
        false ->
            ok
    end,
    {ok, #state{options = Options, hosts = Hosts}}.

%% @hidden
-spec handle_cast(Request :: any(), State :: #state{}) ->
                         {noreply, NewState :: #state{}}.
handle_cast(?SIG_HOSTS(NewHosts), State) ->
    Hosts = apply_hosts(State#state.hosts, NewHosts),
    {noreply, State#state{hosts = Hosts}};
handle_cast(_Request, State) ->
    ?trace("unknown cast message:~n\t~p", [_Request]),
    {noreply, State}.

%% @hidden
-spec handle_info(Info :: any(), State :: #state{}) ->
                         {noreply, State :: #state{}} |
                         {stop, Reason :: any(), #state{}}.
handle_info(?SIG_CLOSE, State) ->
    _NewHosts = apply_hosts(State#state.hosts, []),
    {stop, normal, State};
handle_info({aerospike_socket, PID, Status}, State) ->
    NewActive =
        if Status == connected ->
                sets:add_element(PID, State#state.active);
           true ->
                sets:del_element(PID, State#state.active)
        end,
    {noreply, State#state{active = NewActive, queue = []}};
handle_info(?SIG_RECONFIG, State) ->
    Options = State#state.options,
    case lists:keyfind(configurator, 1, Options) of
        {configurator, Function} when is_function(Function, 0) ->
            NewHosts = apply_hosts(State#state.hosts, Function()),
            {ok, _TRef} = timer:send_after(reconfig_period(Options), ?SIG_RECONFIG),
            {noreply, State#state{hosts = NewHosts}};
        false ->
            {noreply, State}
    end;
handle_info(_Request, State) ->
    ?trace("unknown info message:~n\t~p", [_Request]),
    {noreply, State}.

%% @hidden
-spec handle_call(Request :: any(), From :: any(), State :: #state{}) ->
                         {reply, Reply :: any(), NewState :: #state{}} |
                         {noreply, NewState :: #state{}}.
handle_call(?SIG_NEXT, _From, #state{queue = [Next | Tail]} = State) ->
    {reply, {ok, Next}, State#state{queue = Tail}};
handle_call(?SIG_NEXT, _From, State) ->
    case sets:to_list(State#state.active) of
        [Next | Tail] ->
            {reply, {ok, Next}, State#state{queue = Tail}};
        [] ->
            {reply, not_connected, State}
    end;
handle_call(?SIG_CONNECTED, _From, State) ->
    {reply, sets:size(State#state.active) > 0, State};
handle_call(_Request, _From, State) ->
    ?trace("unknown call from ~w:~n\t~p", [_From, _Request]),
    {noreply, State}.

%% @hidden
-spec terminate(Reason :: any(), State :: #state{}) -> ok.
terminate(_Reason, _State) ->
    ok.

%% @hidden
-spec code_change(OldVersion :: any(), State :: #state{}, Extra :: any()) ->
                         {ok, NewState :: #state{}}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% --------------------------------------------------------------------
%% Internal functions
%% --------------------------------------------------------------------

%% @doc
-spec apply_hosts([{aerospike_socket:host(),
                    inet:port_number(),
                    ConnPID :: pid()}],
                  hosts()) ->
                         [{aerospike_socket:host(),
                           inet:port_number(),
                           ConnPID :: pid()}].
apply_hosts([{H, P, _} = Elem | T1], [{H, P} | T2]) ->
    [Elem | apply_hosts(T1, T2)];
apply_hosts([{_H1, _P1, S1} | T1], [{H2, P2} | T2]) ->
    ok = aerospike_socket:close(S1),
    {ok, S2} = aerospike_socket:start_link(H2, P2, [reconnect, {state_listener, self()}]),
    [{H2, P2, S2} | apply_hosts(T1, T2)];
apply_hosts([] = T1, [{H2, P2} | T2]) ->
    {ok, S2} = aerospike_socket:start_link(H2, P2, [reconnect, {state_listener, self()}]),
    [{H2, P2, S2} | apply_hosts(T1, T2)];
apply_hosts([{_H1, _P1, S1} | T1], [] = T2) ->
    ok = aerospike_socket:close(S1),
    apply_hosts(T1, T2);
apply_hosts([], []) ->
    [].

%% @doc
-spec reconfig_period(options()) -> Millis :: integer().
reconfig_period(Options) ->
    Seconds = proplists:get_value(configure_period, Options, 15),
    round(Seconds * 1000).
