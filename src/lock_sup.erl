-module(lock_sup).
-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

-spec(start_link() ->
    {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => simple_one_for_one,
        intensity => 3,
        period => 60},
    Child = lock_srv,
    ChildSpecs = [#{id => Child,
        start => {Child, start_link, []},
        shutdown => brutal_kill, type => worker, restart => temporary}],
    {ok, {SupFlags, ChildSpecs}}.
