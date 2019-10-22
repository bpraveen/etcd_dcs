-module(lock_srv_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("eqc/include/eqc.hrl").
-include_lib("kernel/include/file.hrl").


-export([all/0, mutual_ex_and_failover/1, lease_renewal/1]).


all() ->
    [mutual_ex_and_failover, lease_renewal].

mutual_ex_and_failover(_Config) ->
    SubscriberPid = self(),
    LockName = test_mutex_failover,
    {ok, First} = lock_srv:start(lock_parameters(LockName, SubscriberPid, 3,2)),

    Timeout = 5000,
    ok = should_receive_msg({lock_acquired, First}, Timeout),

    {ok, Second} = lock_srv:start(lock_parameters(LockName, SubscriberPid, 3,2)),

    ok = should_receive_msg({lock_failed, Second}, Timeout),

    exit(First, kill),

    ok = should_receive_msg({lock_released, Second}, Timeout * 2),
    ok = should_receive_msg({lock_acquired, Second}, Timeout),
    exit(Second, kill).

lease_renewal(_Config) ->
    SubscriberPid = self(),
    LockName = test_renewal,
    {ok, LockSrvPid1} = lock_srv:start(lock_parameters(LockName, SubscriberPid, 3,1)),
    Timeout = 5000,
    ok = should_receive_msg({lock_acquired, LockSrvPid1}, Timeout),
    ok = should_receive_msg({lease_renewed, LockSrvPid1}, Timeout*2),
    exit(LockSrvPid1, kill).

should_receive_msg(Msg, Timeout) ->
    receive
         Msg -> ok
    after Timeout ->
        {error, {timeout, Timeout}}
    end.

lock_parameters(Name, Subscriber, LeaseDurationSec, LeaseRenewalSec) ->
    #{
        name => Name,
        from => Subscriber,
        lease_duration_s => LeaseDurationSec,
        lease_renewal_s => LeaseRenewalSec,
        host => "localhost",
        port => 23790,
        debug_pid => self(),
        trace => [lock_status]
    }.
