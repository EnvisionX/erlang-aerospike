%%% @doc
%%% Aerospike connection implementation.

%%% @author Aleksey Morarash <aleksey.morarash@gmail.com>
%%% @since 02 May 2016
%%% @copyright 2016, Aleksey Morarash <aleksey.morarash@gmail.com>

-module(aerospike_socket).

-behaviour(gen_server).

%% API exports
-export(
   [start_link/3,
    connected/1,
    close/1,
    reconnect/1,
    info/3,
    msg/5
   ]).

%% other exports
-export([req/3]).

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
-define(CLOSE, '*close*').

%% to tell the client to re-establish the connection immediately
-define(RECONNECT, '*reconnect*').

-define(REQ(Request, Timeout), {'*req*', Request, Timeout}).

%% --------------------------------------------------------------------
%% Type definitions
%% --------------------------------------------------------------------

-export_types(
   [host/0,
    options/0,
    option/0,
    info/0,
    info_item/0,
    info_item_value/0,
    msg_options/0,
    msg_option/0,
    flag/0
   ]).

-type host() ::
        (HostnameOrIP :: nonempty_string() | atom() | binary()) |
        inet:ip_address().

-type options() :: [option()].

-type option() ::
        reconnect |
        sync_start |
        {connect_timeout, non_neg_integer()} |
        {reconnect_period, non_neg_integer()} |
        {state_listener, pid() | atom()}.

-type info() :: [info_item()].

-type info_item() ::
        {Key :: atom(), Value :: info_item_value()}.

-type info_item_value() ::
        string() |
        [string() | {Key :: atom(), Value :: any()}] |
        undefined.

-type msg_options() :: [msg_option()].

-type msg_option() ::
        {generation, integer()} |
        {record_ttl, integer()} |
        {transaction_ttl, integer()} |
        flag().

-type flag() ::
        %% read flags
        read | get_all | batch | xdr | nobindata |
        read_consistency_level_one | read_consistency_level_all |
        %% write flags
        write | delete | generation | generation_gt | create_only |
        bin_create_only | respond_all_ops |
        last | write_commit_level_all | write_commit_level_master |
        update_only | create_or_replace | replace_only | bin_replace_only.

%% --------------------------------------------------------------------
%% API functions
%% --------------------------------------------------------------------

%% @doc Start a linked process. It will connect to the node in
%% background.
%%
%% Available options:
%% <ul>
%%  <li>reconnect - do not terminate on connection error or disconnect,
%%     reconnect to the node automatically;</li>
%%  <li>sync_start - only for 'reconnect' mode. If defined, connection
%%     attempt will be made during process init and if connection will
%%     fail whole process will fail too. After successfull connection
%%     the process will behave just like normal process with 'reconnect'
%%     mode enabled;</li>
%%  <li>{connect_timeout, Millis} - set TCP connect timeout;</li>
%%  <li>{reconnect_period, Millis} - set sleep time before reconnecting.
%%     Does sense only when 'reconnect' is set;</li>
%%  <li>{state_listener, pid() | atom()} - PID or registered name of
%%     the Erlang process which will receive notifications about
%%     TCP connection state change: {aerospike_socket, ClientPID, connected}
%%     on connect and {aerospike_socket, ClientPID, disconnected} on
%%     disconnection.</li>
%% </ul>
-spec start_link(Host :: host(), Port :: inet:port_number(),
                 Options :: options()) ->
                        {ok, Pid :: pid()} | {error, Reason :: any()}.
start_link(Host, Port, Options) ->
    Caller = self(),
    gen_server:start_link(?MODULE, _Args = {Host, Port, Options, Caller}, []).

%% @doc Return 'true' if connection is established and 'false' otherwise.
-spec connected(pid()) -> boolean().
connected(Pid) ->
    %% It was done in such non-usual manner to not block this
    %% request if the process is busy by network transfers.
    case process_info(Pid, dictionary) of
        {dictionary, List} ->
            lists:keyfind(connected, 1, List) /= false;
        undefined ->
            false
    end.

%% @doc Close the connection. Calling the function for already terminated
%% process is allowed.
-spec close(pid()) -> ok.
close(Pid) ->
    _Sent = Pid ! ?CLOSE,
    ok.

%% @doc Force the process to re-establish connection to the Aerospike node.
-spec reconnect(pid()) -> ok.
reconnect(Pid) ->
    gen_server:cast(Pid, ?RECONNECT).

%% @doc Return Aerospike cluster information.
-spec info(pid(), Command :: binary(), Timeout :: timeout()) ->
                  {ok, info()} | {error, Reason :: any()}.
info(Pid, Command0, Timeout) when is_binary(Command0) ->
    Command =
        if Command0 == <<>> ->
                Command0;
           true ->
                %% add trailing new line, if not present
                case split_binary(Command0, size(Command0) - 1) of
                    {_, <<$\n>>} ->
                        Command0;
                    _ ->
                        <<Command0/binary, $\n>>
                end
        end,
    MsgSize = size(Command),
    AerospikeRequest =
        <<?VERSION:8, ?AerospikeInfo:8, MsgSize:48/big-unsigned,
          Command/binary>>,
    case req(Pid, AerospikeRequest, Timeout) of
        {ok, BinResp} when Command == <<>> ->
            {ok, aerospike_decoder:decode_info(BinResp)};
        {ok, BinResp} ->
            {ok,
             lists:map(
               fun(Line) ->
                       case string:tokens(Line, "\t") of
                           [C, Res] ->
                               {list_to_binary(C), list_to_atom(Res)};
                           Other ->
                               Other
                       end
               end, string:tokens(binary_to_list(BinResp), "\n\r"))};
        {error, _Reason} = Error ->
            Error
    end.

%% @doc Send AerospikeMessage (AS_MSG) request to the Aerospike node,
%% receive and decode response.
-spec msg(pid(),
          Fields :: list(),
          Ops :: list(),
          Options :: msg_options(),
          Timeout :: timeout()) ->
                 {ok, Response :: any()} |
                 {error, Reason :: any()}.
msg(Pid, Fields, Ops, Options, Timeout) ->
    Request = aerospike_encoder:encode(Fields, Ops, Options),
    case req(Pid, Request, Timeout) of
        {ok, EncodedResponse} ->
            aerospike_decoder:decode(EncodedResponse);
        {error, _Reason} = Error ->
             Error
    end.

%% @hidden
%% @doc Send raw request to the Aerospike node, receive the raw response.
-spec req(pid(), Request :: binary(), Timeout :: timeout()) ->
                 {ok, ResponsePayload :: binary()} | {error, Reason :: any()}.
req(Pid, Request, Timeout) ->
    case gen_server:call(Pid, ?REQ(Request, Timeout), infinity) of
        {ok, _Encoded} = Ok ->
            Ok;
        {error, _Reason} = Error ->
            Error
    end.

%% ----------------------------------------------------------------------
%% gen_server callbacks
%% ----------------------------------------------------------------------

-record(
   state,
   {host :: host(),
    port :: inet:port_number(),
    reconnect :: boolean(),
    listener :: pid() | atom(),
    opts = [] :: options(),
    socket :: port(),
    caller :: pid(),
    caller_mon :: reference()
   }).

%% @hidden
-spec init({host(), inet:port_number(), options(), Caller :: pid()}) ->
                  {ok, InitialState :: #state{}} |
                  {stop, Reason :: any()}.
init({Host, Port, Options, Caller}) ->
    ?trace("init(~9999p)", [{Host, Port, Options}]),
    Reconnect = lists:member(reconnect, Options),
    SyncStart = lists:member(sync_start, Options),
    State0 =
        #state{
           host = Host,
           port = Port,
           reconnect = Reconnect,
           listener = proplists:get_value(state_listener, Options),
           opts = Options,
           caller = Caller,
           caller_mon = monitor(process, Caller)
          },
    if Reconnect andalso not SyncStart ->
            %% schedule reconnect in background
            ok = reconnect(self()),
            {ok, State0};
       true ->
            %% try to connect right here
            case connect(State0) of
                {ok, Socket} ->
                    {ok, State0#state{socket = Socket}};
                {error, Reason} ->
                    {stop, Reason}
            end
    end.

%% @hidden
-spec handle_cast(Request :: any(), State :: #state{}) ->
                         {noreply, NewState :: #state{}}.
handle_cast(?RECONNECT, State) ->
    State1 = disconnect(State),
    case connect(State1) of
        {ok, Socket} ->
            {noreply, State1#state{socket = Socket}};
        {error, _Reason} when State1#state.reconnect ->
            {noreply, State1};
        {error, Reason} ->
            {stop, {reconnect_failed, Reason}, State1}
    end;
handle_cast(_Request, State) ->
    ?trace("unknown cast message:~n\t~p", [_Request]),
    {noreply, State}.

%% @hidden
-spec handle_info(Info :: any(), State :: #state{}) ->
                         {noreply, State :: #state{}} |
                         {stop, Reason :: any(), #state{}}.
handle_info({tcp_closed, Socket}, State)
  when Socket == State#state.socket ->
    ?trace("connection closed", []),
    _OldStatus = erase(connected),
    ok = notify(State, disconnected),
    State1 = State#state{socket = undefined},
    if State#state.reconnect ->
            case connect(State1) of
                {ok, NewSocket} ->
                    {noreply, State1#state{socket = NewSocket}};
                {error, _Reason} ->
                    {noreply, State1}
            end;
       true ->
            {stop, tcp_closed, State1}
    end;
handle_info({tcp_error, Socket, Reason}, State)
  when Socket == State#state.socket ->
    ?trace("tcp_error occured: ~9999p", [Reason]),
    State1 = disconnect(State),
    if State#state.reconnect ->
            case connect(State1) of
                {ok, NewSocket} ->
                    {noreply, State1#state{socket = NewSocket}};
                {error, _Reason} ->
                    {noreply, State1}
            end;
       true ->
            {stop, {tcp_error, Reason}, State1}
    end;
handle_info({tcp, Socket, _Data}, State)
  when Socket == State#state.socket, Socket /= undefined ->
    ?trace("unexpected socket data: ~9999p", [_Data]),
    case inet:setopts(Socket, [{active, once}]) of
        ok ->
            {noreply, State};
        {error, _Reason} when State#state.reconnect ->
            ?trace("disconnected: ~9999p", [_Reason]),
            ok = reconnect(self()),
            {noreply, disconnect(State)};
        {error, Reason} ->
            {stop, Reason, disconnect(State)}
    end;
handle_info(?CLOSE, State) ->
    {stop, normal, disconnect(State)};
handle_info({'DOWN', CallerMon, process, Caller, _Reason}, State)
  when CallerMon == State#state.caller_mon, Caller == State#state.caller ->
    ?trace("owner process terminated: ~9999p", [_Reason]),
    {stop, normal, disconnect(State)};
handle_info(_Request, State) ->
    ?trace("unknown info message:~n\t~p", [_Request]),
    {noreply, State}.

%% @hidden
-spec handle_call(Request :: any(), From :: any(), State :: #state{}) ->
                         {reply, Reply :: any(), NewState :: #state{}} |
                         {noreply, NewState :: #state{}}.
handle_call(?REQ(_, _), _From, #state{socket = undefined} = State) ->
    {reply, {error, not_connected}, State};
handle_call(?REQ(Request, Timeout), _From, State) ->
    try handle_req(State, Request, Timeout) of
        {ok, _Response} = Ok ->
            {reply, Ok, State};
        {error, closed} when State#state.reconnect ->
            ?trace("connection lost. reconnecting...", []),
            State1 = disconnect(State),
            case connect(State1) of
                {ok, Socket} ->
                    State2 = State1#state{socket = Socket},
                    case handle_req(State2, Request, Timeout) of
                        {ok, _Response} = Ok ->
                            {reply, Ok, State2};
                        {error, _Reason} = Error ->
                            {reply, Error, State2}
                    end;
                {error, _Reason} = Error ->
                    {reply, Error, State1}
            end;
        {error, Reason} ->
            ok = reconnect(self()),
            {reply, {error, Reason}, disconnect(State)}
    catch
        ExcType:ExcReason ->
            FinalReason =
                {crashed,
                 [{type, ExcType},
                  {reason, ExcReason},
                  {stacktrace, erlang:get_stacktrace()},
                  {request, Request}]},
            ok = reconnect(self()),
            {reply, {error, FinalReason}, disconnect(State)}
    end;
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

%% @doc Close the connection to the broker.
-spec disconnect(State :: #state{}) -> NewState :: #state{}.
disconnect(#state{socket = undefined} = State) ->
    %% already disconnected
    State;
disconnect(State) ->
    ?trace("disconnecting from ~w",
           [element(2, inet:peername(State#state.socket))]),
    ok = gen_tcp:close(State#state.socket),
    _OldStatus = erase(connected),
    ok = notify(State, disconnected),
    State#state{socket = undefined}.

%% @doc Try to establish connection to the broker.
-spec connect(State :: #state{}) ->
                     {ok, Socket :: port()} | {error, Reason :: any()}.
connect(State) ->
    Host = State#state.host,
    Port = State#state.port,
    Options = [binary, {active, once}, {keepalive, true}],
    ConnectTimeout =
        proplists:get_value(
          connect_timeout, State#state.opts, ?CONNECT_TIMEOUT),
    ?trace("connecting to ~9999p:~w with opts ~9999p...",
           [Host, Port, Options]),
    case gen_tcp:connect(Host, Port, Options, ConnectTimeout) of
        {ok, Socket} ->
            _OldStatus = put(connected, true),
            ?trace("connected to ~9999p:~w", [Host, Port]),
            ok = notify(State, connected),
            {ok, Socket};
        {error, _Reason} = Error ->
            ?trace("failed to connect to ~9999p:~w: ~9999p",
                   [Host, Port, _Reason]),
            if State#state.reconnect ->
                    Period =
                        proplists:get_value(
                          reconnect_period, State#state.opts,
                          ?CONNECT_RETRY_PERIOD),
                    ?trace("reconnect scheduled after ~w millis", [Period]),
                    {ok, _TRef} =
                        timer:apply_after(
                          Period, ?MODULE, reconnect, [self()]), ok;
               true ->
                    ok
            end,
            Error
    end.

%% @doc Send notification to state listener process (if set).
-spec notify(#state{}, Message :: any()) -> ok.
notify(#state{listener = undefined}, _Message) ->
    ?trace("skip notifying: ~9999p", [_Message]);
notify(#state{listener = Listener}, Message) ->
    ?trace("notifying ~w: ~9999p", [Listener, Message]),
    _Sent = Listener ! {?MODULE, self(), Message},
    ok.

%% @doc Perform synchronous request to the connected broker.
-spec handle_req(#state{}, Request :: binary(), timeout()) ->
                        {ok, Response :: binary()} | {error, Reason :: any()}.
handle_req(State, Request, Timeout) ->
    Socket = State#state.socket,
    case inet:setopts(Socket, [{active, false}]) of
        ok ->
            <<?VERSION:8, MsgType:8, _/binary>> = Request,
            ?trace("sending ~w bytes to ~9999p:~w",
                   [size(Request), State#state.host, State#state.port]),
            case gen_tcp:send(Socket, Request) of
                ok ->
                    case gen_tcp:recv(Socket, 8, Timeout) of
                        {ok, <<?VERSION:8, MsgType:8, RespLen:48/big-unsigned>>} ->
                            ?trace("got header. waiting for payload of size ~w...",
                                   [RespLen]),
                            case gen_tcp:recv(Socket, RespLen, Timeout) of
                                {ok, Resp} when size(Resp) == RespLen ->
                                    ?trace("encoded response: ~s",
                                           [base64:encode(zlib:gzip(Resp))]),
                                    case inet:setopts(Socket, [{active, once}]) of
                                        ok ->
                                            ok;
                                        {error, _Reason} ->
                                            ?trace("failed to restore active mode"
                                                   " for the socket: ~9999p", [_Reason]),
                                            if State#state.reconnect ->
                                                    ok = reconnect(self());
                                               true ->
                                                    ok
                                            end
                                    end,
                                    {ok, Resp};
                                {ok, BadResp} ->
                                    {error, {incomplete_response, BadResp}};
                                {error, Reason} ->
                                    {error, {payload_recv, Reason}}
                            end;
                        {ok, BadHeader} ->
                            {error, {bad_resp_header, BadHeader}};
                        {error, closed} = Error ->
                            Error;
                        {error, Reason} ->
                            {error, {resp_header_recv, Reason}}
                    end;
                {error, Reason} ->
                    ?trace("failed to send request: ~9999p", [Reason]),
                    {error, Reason}
            end;
        {error, _Reason} = Error ->
            Error
    end.

%% ----------------------------------------------------------------------
%% Unit tests
%% ----------------------------------------------------------------------

-ifdef(TEST).

state_listening_test_() ->
    ServerName = aerospike_node,
    Port = 13000,
    {setup,
     _Startup =
         fun() ->
                 spawn_link(
                   fun() ->
                           true = register(ServerName, self()),
                           {ok, ServerSocket} =
                               gen_tcp:listen(Port, [{reuseaddr, true}]),
                           {ok, S1} = gen_tcp:accept(ServerSocket),
                           receive cut -> gen_tcp:close(S1) end,
                           {ok, S2} = gen_tcp:accept(ServerSocket),
                           receive advent -> ok end,
                           gen_tcp:close(S2)
                   end)
         end,
     _Cleanup =
         fun(_) ->
                 true = erlang:exit(whereis(ServerName), normal)
         end,
     fun() ->
             {ok, S} = start_link(localhost, Port, [reconnect,
                                                    {reconnect_period, 200},
                                                    {state_listener, self()}]),
             receive {?MODULE, S, connected} -> ok
             after 1000 -> throw(no_connect_notify) end,
             ?assert(connected(S)),
             ServerName ! cut,
             receive {?MODULE, S, disconnected} -> ok
             after 1000 -> throw(no_disconnect_notify) end,
             ?assertNot(connected(S)),
             %% wait until the client reconnects
             receive {?MODULE, S, connected} -> ok
             after 1000 -> throw(no_connect_notify) end,
             ?assert(connected(S)),
             ok = close(S),
             receive {?MODULE, S, disconnected} -> ok
             after 1000 -> throw(no_disconnect_notify) end,
             ?assertNot(connected(S))
     end}.

-endif.
