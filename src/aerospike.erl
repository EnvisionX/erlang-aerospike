%%% @doc
%%% Erlang Client for the Aerospike.
%%%
%%% Unlike most Erlang libraries, this main module contains almost
%%% nothing interesting.
%%% To manage connection to the Aerospike node and issue requests
%%% use aerospike_socket module instead.

%%% @author Aleksey Morarash <aleksey.morarash@gmail.com>
%%% @since 02 May 2016
%%% @copyright 2016, Aleksey Morarash <aleksey.morarash@gmail.com>

-module(aerospike).

%% API exports
-export(
   [info/0, info/1, info/2, info/3
   ]).

-include("aerospike.hrl").
-include("aerospike_defaults.hrl").

%% ----------------------------------------------------------------------
%% API functions
%% ----------------------------------------------------------------------

%% @equiv info(localhost)
%% @doc Fetch Aerospike cluster information from local Aerospike node.
%% Will connect to the node, poll it and disconnect.
-spec info() -> {ok, aerospike_socket:info()} | {error, Reason :: any()}.
info() ->
    info(localhost).

%% @equiv info(Host, 3000)
%% @doc Fetch Aerospike cluster information from Aerospike node.
%% Will connect to the node, poll it and disconnect.
-spec info(Host :: aerospike_socket:host()) ->
                  {ok, aerospike_socket:info()} | {error, Reason :: any()}.
info(Host) ->
    info(Host, ?SERVER_TCP_PORT_NUMBER).

%% @doc Fetch Aerospike cluster information from Aerospike node.
%% Will connect to the node, poll it and disconnect.
-spec info(Host :: aerospike_socket:host(), Port :: inet:port_number()) ->
                  {ok, aerospike_socket:info()} | {error, Reason :: any()}.
info(Host, Port) ->
    info(Host, Port, <<>>).

%% @doc Execute info request to Aerospike node.
%% Will connect to the node, do request and disconnect.
-spec info(Host :: aerospike_socket:host(), Port :: inet:port_number(),
           Command :: binary()) ->
                  {ok, Response :: binary()} | {error, Reason :: any()}.
info(Host, Port, Command) ->
    case aerospike_socket:start_link(Host, Port, [reconnect, sync_start]) of
        {ok, Socket} ->
            Result = aerospike_socket:info(Socket, Command, 5000),
            ok = aerospike_socket:close(Socket),
            Result;
        {error, _Reason} = Error ->
            Error
    end.
