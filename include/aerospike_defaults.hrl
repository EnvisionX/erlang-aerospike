%%%----------------------------------------------------------------------
%%% File        : aerospike_defaults.hrl
%%% Author      : Aleksey Morarash <aleksey.morarash@gmail.com>
%%% Description : default values for configuration options
%%% Created     : 02 May 2016
%%%----------------------------------------------------------------------

-ifndef(_AEROSPIKE_DEFAULTS).
-define(_AEROSPIKE_DEFAULTS, true).

-define(SERVER_TCP_PORT_NUMBER, 3000).
-define(CONNECT_TIMEOUT, 2000). %% two seconds
-define(CONNECT_RETRY_PERIOD, 2000). %% two seconds

-endif.
