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
    active_workers/1,
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
-define(SIG_RECONFIG, reconfig).
-define(SIG_HOSTS(Hosts), {hosts, Hosts}).

%% --------------------------------------------------------------------
%% Type definitions
%% --------------------------------------------------------------------

-export_types(
   [hosts/0,
    options/0,
    option/0,
    pool_ref/0
   ]).

-type hosts() :: [{aerospike_socket:host(), inet:port_number()}].

-type options() :: [option()].

-type option() ::
        {name, RegisteredName :: atom()} |
        {configure_period, Seconds :: number()} |
        {configurator, fun(() -> hosts())}.

-type pool_ref() ::
        pid() |
        (RegisteredName :: atom()).

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

%% @doc Fetch PID list for active workers.
-spec active_workers(pool_ref()) -> [pid()].
active_workers(PoolRef) ->
    PoolPID =
        if is_atom(PoolRef) ->
                whereis(PoolRef);
           true ->
                PoolRef
        end,
    if is_pid(PoolPID) ->
            {dictionary, List} = process_info(PoolPID, dictionary),
            case lists:keyfind(iterator, 1, List) of
                {iterator, ETS} ->
                    ets:lookup_element(ETS, pool, 2);
                false ->
                    []
            end;
       true ->
            []
    end.

%% @doc Return 'true' if at least one connection is established
%% and 'false' otherwise.
-spec connected(PoolRef :: pool_ref()) -> boolean().
connected(PoolRef) ->
    [] /= active_workers(PoolRef).

%% @doc Close the connection pool. Calling the function for already terminated
%% process is allowed.
-spec close(PoolRef :: pool_ref()) -> ok.
close(PoolRef) ->
    _Sent = PoolRef ! ?SIG_CLOSE,
    ok.

%% @doc Return Aerospike cluster information.
-spec info(PoolRef :: pool_ref(), Timeout :: timeout()) ->
                  {ok, aerospike_socket:info()} | {error, Reason :: any()}.
info(PoolRef, Timeout) ->
    req_loop(
      active_workers(PoolRef),
      fun(Worker) ->
              aerospike_socket:info(Worker, Timeout)
      end).

%% @doc Send AerospikeMessage (AS_MSG) request to the Aerospike node,
%% receive and decode response.
-spec msg(PoolRef :: pool_ref(),
          Fields :: list(),
          Ops :: list(),
          Options :: aerospike_socket:msg_options(),
          Timeout :: timeout()) ->
                 {ok, Response :: any()} | {error, Reason :: any()}.
msg(PoolRef, Fields, Ops, Options, Timeout) ->
    req_loop(
      active_workers(PoolRef),
      fun(Worker) ->
              aerospike_socket:msg(Worker, Fields, Ops, Options, Timeout)
      end).

%% ----------------------------------------------------------------------
%% gen_server callbacks
%% ----------------------------------------------------------------------

-record(
   state,
   {options :: options(),
    hosts = [] :: [{aerospike_socket:host(), inet:port_number(),
                    Worker :: pid()}],
    active = sets:new() :: sets:set(ConnectedWorker :: pid())
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
    undefined = put(iterator, ets:new(?MODULE, [])),
    true = ets:insert(get(iterator), {pool, []}),
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
    Active = State#state.active,
    NewStatus = Status == connected,
    OldStatus = sets:is_element(PID, Active),
    if OldStatus /= NewStatus ->
            NewActive =
                if NewStatus ->
                        sets:add_element(PID, Active);
                   true ->
                        sets:del_element(PID, Active)
                end,
            true = ets:update_element(
                     get(iterator), pool, {2, sets:to_list(NewActive)}),
            {noreply, State#state{active = NewActive}};
       true ->
            {noreply, State}
    end;
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
    [{H2, P2, connect(H2, P2)} | apply_hosts(T1, T2)];
apply_hosts([] = T1, [{H2, P2} | T2]) ->
    [{H2, P2, connect(H2, P2)} | apply_hosts(T1, T2)];
apply_hosts([{_H1, _P1, S1} | T1], [] = T2) ->
    ok = aerospike_socket:close(S1),
    apply_hosts(T1, T2);
apply_hosts([], []) ->
    [].

%% @doc Spawn Aerospike connection process.
-spec connect(aerospike_socket:host(), inet:port_number()) ->
                     Socket :: pid().
connect(Host, Port) ->
    {ok, Socket} =
        aerospike_socket:start_link(
          Host, Port, [reconnect, {state_listener, self()}]),
    Socket.

%% @doc
-spec reconfig_period(options()) -> Millis :: integer().
reconfig_period(Options) ->
    Seconds = proplists:get_value(configure_period, Options, 15),
    round(Seconds * 1000).

%% @doc Helper for the info/2 and msg/5 API functions.
%% Iterate over all active workers, doing failover on some errors.
-spec req_loop(ActiveWorkers :: [pid()],
               Task :: fun((Worker :: pid()) ->
                                  {ok, any()} | {error, Reason :: any()})) ->
                      Result :: any() | {error, Reason :: any()}.
req_loop([], _Task) ->
    {error, not_connected};
req_loop(Workers, Task) ->
    {Worker, TailWorkers} = pop_random(Workers),
    case Task(Worker) of
        {error, _Reason} = Error when TailWorkers == [] ->
            Error;
        {error, not_connected} ->
            req_loop(TailWorkers, Task);
        {error, closed} ->
            req_loop(TailWorkers, Task);
        {error, [{code, ?AS_PROTO_RESULT_FAIL_UNAVAILABLE} | _]} ->
            %% Server is not accepting requests. Occur during
            %% single node on a quick restart to join existing cluster.
            req_loop(TailWorkers, Task);
        {error, _Reason} = Error ->
            Error;
        Result ->
            Result
    end.

%% @doc Pop random element from the list. Return the element and new
%% list without fetched element.
-spec pop_random(list(A :: any())) -> {A :: any(), NewList :: list(A :: any())}.
pop_random([Elem]) ->
    {Elem, []};
pop_random(List) ->
    %% initialize RNG, if not yet
    case get(random_seed) of
        undefined ->
            undefined = random:seed(os:timestamp());
        _Seed ->
            undefined
    end,
    {List1, [Elem | List2]} = lists:split(random:uniform(length(List)) - 1, List),
    {Elem, List1 ++ List2}.

%% ----------------------------------------------------------------------
%% Unit tests
%% ----------------------------------------------------------------------

-ifdef(TEST).

req_loop_test_() ->
    ?_assertMatch(
       {error, not_connected},
       req_loop([], fun(_) -> {ok, ok} end)).

req_loop_failover_1_test() ->
    lists:foreach(
      fun(_) ->
              ?assertMatch(
                 ok,
                 req_loop(
                   [1, 2, 3, 4],
                   fun(1) ->
                           {error, not_connected};
                      (2) ->
                           {error, closed};
                      (3) ->
                           {error, [{code, ?AS_PROTO_RESULT_FAIL_UNAVAILABLE}]};
                      (4) ->
                           ok
                   end))
      end, lists:seq(1, 10000)).

req_loop_failover_2_test() ->
    lists:foreach(
      fun(_) ->
              ?assertMatch(
                 {error, myreason},
                 req_loop(
                   [1, 2, 3, 4],
                   fun(1) ->
                           {error, not_connected};
                      (2) ->
                           {error, closed};
                      (3) ->
                           {error, [{code, ?AS_PROTO_RESULT_FAIL_UNAVAILABLE}]};
                      (4) ->
                           {error, myreason}
                   end))
      end, lists:seq(1, 10000)).

pop_random_test() ->
    List = lists:seq(1, 10000),
    {[], Shuffled} =
        lists:foldl(
          fun(_, {L, Fetched}) ->
                  {Elem, Tail} = pop_random(L),
                  {Tail, [Elem | Fetched]}
          end, {List, []}, List),
    ?assert(List /= Shuffled),
    ?assert(List /= lists:reverse(Shuffled)),
    ?assert(length(List) == length(Shuffled)),
    ?assert(List == lists:sort(Shuffled)),
    ?assert(List == lists:usort(Shuffled)).

-endif.
