%%%----------------------------------------------------------------------
%%% File        : aerospike.hrl
%%% Author      : Aleksey Morarash <aleksey.morarash@gmail.com>
%%% Description : aerospike definitions file
%%% Created     : 02 May 2016
%%%----------------------------------------------------------------------

-ifndef(_AEROSPIKE).
-define(_AEROSPIKE, true).

%% ----------------------------------------------------------------------
%% debugging

-ifdef(TRACE).
-define(
   trace(Format, Args),
   ok = io:format(
          "TRACE> mod:~w; line:~w; pid:~w; msg:" ++ Format ++ "~n",
          [?MODULE, ?LINE, self() | Args]
         )).
-else.
-define(trace(F, A), ok).
-endif.

%% ----------------------------------------------------------------------
%% eunit

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-endif.
