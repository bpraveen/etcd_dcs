-module(etcd_dcs_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: #{id => Id, start => {M, F, A}}
%% Optional keys are restart, shutdown, type, modules.
%% Before OTP 18 tuples must be used to specify a child. e.g.
%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([]) ->
    RestartStrategy = one_for_all,
    MaxRestarts = 1000,
    MaxSecondsBetweenRestarts = 3600,
    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

    {ok, {SupFlags, child_specs()}}.

%%====================================================================
%% Internal functions
%%====================================================================
-spec child_specs() -> Result
    when Result :: [#{id => atom(), start =>
                        {Module :: atom(),
                            Function :: start_link,
                            Arguments :: [term()]}
                        }].
child_specs() ->
    [worker_child_spec(lock_mgr),
     worker_child_spec(lock_info_db),
     supervisor_child_spec(lock_sup)].

worker_child_spec(Id) ->
    #{id => Id, start => {Id,start_link,[]}}.

supervisor_child_spec(Module) ->
    Id = Module,
    #{id => Id, start => {Module,start_link,[]}, type => supervisor}.
