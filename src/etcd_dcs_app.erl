%%%-------------------------------------------------------------------
%% @doc etcd_dcs public API
%% @end
%%%-------------------------------------------------------------------

-module(etcd_dcs_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%%====================================================================
%% API
%%====================================================================

start(_StartType, _StartArgs) ->
    etcd_dcs_sup:start_link().

%%--------------------------------------------------------------------
stop(_State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================
