-module(lock_mgr_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("eqc/include/eqc.hrl").
-include_lib("kernel/include/file.hrl").


%% API
-export([all/0, basic/1, there_should_be_only_one_master/1, create_lock/4, lock_registration_deregistration_on_lock_srv_process_died/1, failover/1,
    lock_mgr_should_handle_etcd_connection_loss/1]).
-export([init_per_testcase/2, end_per_testcase/2]).

all() ->
    [basic, there_should_be_only_one_master, lock_registration_deregistration_on_lock_srv_process_died, failover, lock_mgr_should_handle_etcd_connection_loss].

init_per_testcase(_Testcase, Config) ->
    case application:ensure_all_started(etcd_dcs) of
        {ok,_}-> ok;
        {error, {already_started,etcd_dcs}} -> ok
    end,
    Config.

end_per_testcase(_Testcase, _Config) ->
    lock_mgr:stop().

basic(_Config) ->
    gen_server_common:registered_gen_server(lock_mgr),
    gen_server_common:stop(lock_mgr).

there_should_be_only_one_master(_Config) ->
    NumberOfSubscribers =10,
    Name = ebox0,
    Timeout = 5000,
    lists:foreach(
        fun(_N) ->
            erlang:spawn(?MODULE, create_lock, [self(), Name, Timeout, false])
       end,
    lists:seq(1, NumberOfSubscribers)),
    {1, 9, 0} = gather_status(NumberOfSubscribers, 0,0,0).

lock_registration_deregistration_on_lock_srv_process_died(_Config) ->
    Sub =self(),
    LockName =ebox1,
    Timeout  =5000,
    LockSrvPid = setup_lock_subscription(Sub,LockName, Timeout),
    exit(LockSrvPid, kill),
    ok = receive
             {deregistered_lock,{LockName,Sub}} -> ok
         after Timeout -> {error, {timeout, Timeout}}
         end.

lock_mgr_should_handle_etcd_connection_loss(_Config) ->
    NumberOfSubscribers = 2,
    Name = ebox_connection_loss,
    ProcessAliveTime = 60 *1000,
    Timeout = 5000,

    Subscribers = lists:map(
        fun(_N) ->
            erlang:spawn(?MODULE, create_lock, [self(), Name, ProcessAliveTime, true])
        end,
        lists:seq(1, NumberOfSubscribers)),
    [First, Second] = Subscribers,

    {1,1,0} = gather_status(NumberOfSubscribers, 0,0,0),
    lock_mgr:cl({set_debug_pid, self()}),

    LockRegistry = maps:get(lock_registry, lock_mgr:cl(debug_state)),
    {First, FirstLockSrvPid}= get_subscriber_lock_srv(LockRegistry, First),

    {MasterPid, SlavePid} =
        receive
            {lock_acquired, LockSrvPid} ->  if LockSrvPid == FirstLockSrvPid ->
                {First, Second};
                                                true -> {Second, First}
                                            end
        end,


    {MasterPid, MasterLockSrvPid}= get_subscriber_lock_srv(LockRegistry, MasterPid),

    {SlavePid, SlaveLockSrvPid}= get_subscriber_lock_srv(LockRegistry, SlavePid),

    close_connection(MasterLockSrvPid, Name, MasterPid, Timeout),
    close_connection(SlaveLockSrvPid, Name, SlavePid, Timeout).


failover(_Config) ->
    NumberOfSubscribers = 2,
    Name = ebox3,
    ProcessAliveTime = 60 *1000,
    lock_mgr:cl({set_debug_pid, self()}),

    Subscribers = lists:map(
        fun(_N) ->
            erlang:spawn(?MODULE, create_lock, [self(), Name, ProcessAliveTime, true])
        end,
        lists:seq(1, NumberOfSubscribers)),
    [First, Second] = Subscribers,

    {1,1,0} = gather_status(NumberOfSubscribers, 0,0,0),

    LockRegistry = maps:get(lock_registry, lock_mgr:cl(debug_state)),
    {First, FirstLockSrvPid}= get_subscriber_lock_srv(LockRegistry, First),

%% notify changes
    {MasterPid, SlavePid} =
        receive
                    {lock_acquired, LockSrvPid} ->  if LockSrvPid == FirstLockSrvPid ->
                                                                {First, Second};
                                                        true -> {Second, First}
                                                    end
        end,
    exit(MasterPid, kill),
    {SlavePid, SlaveLockSrvPid}= get_subscriber_lock_srv(LockRegistry, SlavePid),
    ok = receive
            {lock_released, SlaveLockSrvPid} -> ok
         end,
    ok = receive
            {lock_acquired, SlaveLockSrvPid} -> ok
         end.



create_lock(Parent, Name, Timeout, ProcessWait) ->
    From = self(),
    L = lock_parameters(Name, From, Parent),
    ok = lock_mgr:apply_for_lock(L),
    Ref = make_ref(),
    lock_mgr:has_lock_async({Name, From , Ref}),
    receive
        Tuple ->
            Parent ! Tuple
        after Timeout ->
            Tuple = {error, {timeout, Timeout}},
            Parent ! Tuple
    end,
    case ProcessWait of
        true -> receive
                after Timeout -> error_logger:info_msg("process create lock timedout"), ok
                end;
        false -> ok
    end.

lock_parameters(Name, From, DebugPid) ->
    #{
        name => Name,
        from => From,
        lease_duration_s => 5,
        lease_renewal_s => 2,
        host => "localhost",
        port => 23790,
        debug_pid => DebugPid
    }.

gather_status(0, TAcc, FAcc, EAcc) -> {TAcc, FAcc, EAcc};
gather_status(N, TrueAcc, FalseAcc, Error) ->
    Timeout = 5000,
    receive
        {has_lock, _Ref, true} -> gather_status(N-1, TrueAcc + 1, FalseAcc, Error);
        {has_lock, _Ref, false} -> gather_status(N-1, TrueAcc, FalseAcc +1, Error)

    after Timeout ->
        gather_status(N-1, TrueAcc, FalseAcc, Error + 1)
    end.


get_subscriber_lock_srv(LockRegistry, Pid) ->
    LockRegistryEntries = maps:to_list(LockRegistry),
    [{S, L}] = [{SubscriberPid, LockSrvPid} || {{_N,SubscriberPid}, {_LR, LockSrvPid}} <- LockRegistryEntries, SubscriberPid =:= Pid],
    {S,L}.


close_connection(LockSrvPid, Name, SubPid, Timeout) ->
    gen_server:cast(LockSrvPid, close_connection),
    ok = receive
             {deregistered_lock, {Name, SubPid}} -> ok
         after Timeout -> {error, {timeout, Timeout}}
         end.


setup_lock_subscription(Subscriber, LockName, Timeout) ->
    Subscriber = self(),
    create_lock(Subscriber, LockName, Timeout, false),
    true = lock_mgr:is_registered({LockName, Subscriber}),
    ok = receive
             {has_lock, _Ref, true} -> ok
         after Timeout -> {error, {timeout, Timeout}}
         end,
    lock_mgr:cl({set_debug_pid, Subscriber}),
    #{lock_registry := NewLockRegistry} = lock_mgr:cl(debug_state),
    {_LockRequest, LockSrvPid} = maps:get({LockName, Subscriber}, NewLockRegistry),
    LockSrvPid.
