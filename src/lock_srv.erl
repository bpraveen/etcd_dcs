-module(lock_srv).
-behaviour(gen_statem).

%% API
-export([start_link/1, callback_mode/0,
        init_lock/3, lock_acquired/3,
        lock_failed/3,
        lock_acquired_watch/3,
        unexpected_error/3,
        lock_failed_watch/3]).
%% gen_statem callbacks
-export([
    init/1,
    terminate/3,
    code_change/4
]).

%% test methods
-export([start/1]).

-define(WATCHER_CREATION_TIMEOUT_MS, 2000).
-define(LEASE_RENEW_TIMEOUT_MS, 2000).
-define(WATCH_INTERVAL_MS, 2000).

-define(SERVER, ?MODULE).
-define(HAS_LOCK, has_lock).

%% Dailyzer fails to correctly intrepret the genstate_m
-dialyzer({nowarn_function, reset_lock/3}).

start_link(Args) ->
    gen_statem:start_link(?MODULE, Args, []).

start(Args) ->
    gen_statem:start(?MODULE, Args, []).

init(Args) ->
    process_flag(trap_exit, true),
    Host = maps:get(host, Args),
    Port = maps:get(port, Args),
    Name = maps:get(name, Args),
    DebugPid = maps:get(debug_pid, Args, undefined),
    Trace = maps:get(trace, Args, [lock_status]),
    LeaseDuration = maps:get(lease_duration_s, Args),
    LeaseRenewalFreq = maps:get(lease_renewal_freq_s, Args, round(LeaseDuration / 3)),
    Data =
        #{
            name => Name,
            connection_config => [{host, Host}, {port, Port}],
            key => erlang:list_to_binary(erlang:atom_to_list(Name) ++"_lock"),
            lease_id => lease_id(Name),
            lease_duration_s => LeaseDuration,
            lease_renewal_freq_s => LeaseRenewalFreq,
            trace => Trace,
            debug_pid => DebugPid
        },
    {ok, init_lock, Data, [{next_event, internal, create_lock}]}.

callback_mode() ->
    [state_functions].

init_lock(internal, create_lock, #{connection_config := [{host, Host}, {port, Port}]}=Data) ->
    {ok, Connection} = grpc_client:connect(tcp, Host, Port),
    NewData = maps:merge(Data, #{connection => Connection}),
    debug_trace(NewData, lock_status, created_connection),
    create_lock(NewData);

init_lock(internal, recreate_lock, Data) ->
    create_lock(Data);

init_lock(internal, lock_released, Data) ->
    create_lock(Data);

init_lock(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

lock_acquired(internal, init_watcher, #{connection := Connection}= Data) ->
    NewData = init_watcher(Connection, Data),
    {next_state, lock_acquired_watch, NewData, [{next_event, internal, check_watcher_ack}]};

lock_acquired(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

lock_acquired_watch(internal, check_watcher_ack, #{watcher:= Watcher} = Data) ->
    is_watcher_created(lock_acquired_watch, Watcher, Data);

lock_acquired_watch(state_timeout, check_status, Data) ->
    waiting(Data);

lock_acquired_watch(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

unexpected_error(internal, put_failed, #{connection := Connection, lease_id := LeaseId} = Data) ->
   reset_lock(Connection, LeaseId, Data);

unexpected_error(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

lock_failed_watch(internal, check_watcher_ack, #{watcher:=  Watcher} = Data) ->
    is_watcher_created(lock_failed_watch, Watcher, Data);

lock_failed_watch(state_timeout, check_status, Data) ->
    waiting(Data);

lock_failed_watch(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

lock_failed(internal, init_watcher, #{connection := Connection} = Data) ->
    NewData = init_watcher(Connection, Data),
    {next_state, lock_failed_watch, NewData, [{next_event, internal, check_watcher_ack}]};

lock_failed(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

terminate(Reason, StateName, Data) ->
    error_logger:info_msg("~p: Terminated Reason ~p StateName ~p ~n Data ~p ~n", [self(), Reason, StateName, Data]).

code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================


is_watcher_created(State, #{stream := Stream}=Watcher, #{connection:=Connection, lease_id := LeaseId}=Data) ->
    case grpc_client:rcv(Stream, ?WATCHER_CREATION_TIMEOUT_MS) of
        {error, timeout} ->
            error_logger:error_msg("~p_watcher creation FAILED, timeout ~p ~n", [State, ?WATCHER_CREATION_TIMEOUT_MS]),
            reset_lock(Connection, LeaseId, Data);

        {data, #{cancel_reason := [], canceled := false, created := true, watch_id := WatchId}} ->
            WatcherUpdate = maps:merge(Watcher, #{id => WatchId}),
            NewData = maps:merge(Data, #{watcher => WatcherUpdate}),
            {next_state, State, NewData, [{state_timeout, ?WATCH_INTERVAL_MS, check_status}]};

        {headers, #{<<":status">> := <<"200">>, <<"content-type">> := _}} ->
            is_watcher_created(State, Watcher, Data);

        Unknown ->
            {next_state, unexpected_error, Data, [{next_event, internal, {unknown_event, is_watcher_created, Unknown}}]}
    end.

reset_lock(Connection, LeaseId, Data) ->
    LeaseRevokeResponse = etcdrpc_client:'LeaseRevoke'(Connection, #{'ID' => LeaseId}, []),
    debug_trace(Data, lock_status, {lease_revoked, LeaseRevokeResponse}),
    {next_state, init_lock, Data, [{next_event, internal, recreate_lock}]}.

create_lock(#{connection:= Connection, key := Key, lease_id := LeaseId, lease_duration_s := TTL} = Data) ->
    LeaseGrantResult = etcdrpc_client:'LeaseGrant'(Connection, #{'ID' => LeaseId, 'TTL' => TTL}, []),
    case LeaseGrantResult of
        {ok, #{grpc_status := 0, http_status := 200, result := #{'ID' := LeaseId, 'TTL' := ActualTTL}}} ->
            M=#{key => Key, value => <<"locked">>, lease => LeaseId},
            PutResult = etcdrpc_client:'Put'(Connection, M, []),
            case PutResult of
                {ok, #{grpc_status := 0, http_status := 200}} ->
                    NewData = update_has_lock(Data, ActualTTL),
                    debug_trace(Data, lock_status, {lock_acquired, ActualTTL}),
                    debug_notify(NewData, {lock_acquired, self()}),
                    {next_state, lock_acquired, NewData, [{next_event, internal, init_watcher}]};

                {error, PutError} ->
                    debug_trace(Data, lock_status, {error, {lock_failed, PutError}}),
                    {next_state, unexpected_error, Data, [{next_event, internal, put_failed}]}
            end;
        {error, LeaseError} ->
            NewData = update_has_lock(Data),
            debug_trace(Data, lock_status, {lock_failed, LeaseError}),
            debug_notify(NewData, {lock_failed, self()}),
            {next_state, lock_failed, NewData, [{next_event, internal, init_watcher}]};

        Unknown ->
            {next_state, unexpected_error, Data, [{next_event, internal, {unknown_event, create_lock, Unknown}}]}
    end.

update_has_lock(Data, ActualTTL) ->
    maps:merge(Data, #{lease_duration_s => ActualTTL, ?HAS_LOCK => true}).

update_has_lock(Data) ->
    maps:merge(Data,#{?HAS_LOCK => false}).

init_watcher(Connection, #{key:=Key} = Data) ->
    {ok, WatchStream} = grpc_client:new_stream(Connection, 'Watch', 'Watch', etcdrpc),
    Request = watcher_request(Key),
    ok = grpc_client:send(WatchStream, #{request_union => {create_request, Request}}),
    maps:merge(Data, #{watcher => #{stream => WatchStream, status => initiated}}).

watcher_request(Key)->
    #{key => Key, progress_notify => true}.

refresh_lease(#{connection := Connection, lease_renewal_freq_s := LeaseRenewalFreq} = Data) ->
    case maps:get(lease, Data, undefined) of
        undefined ->
            {ok, RefreshLeaseStream} = grpc_client:new_stream(Connection, 'Lease', 'LeaseKeepAlive', etcdrpc),
            NewData = maps:merge(Data, #{lease => #{stream => RefreshLeaseStream}}),
            refresh_lease_helper(RefreshLeaseStream, NewData);

        #{stream := RefreshLeaseStream, timestamp := LastRefresh} ->
            Now = erlang:system_time(second),
            case (Now > (LastRefresh + LeaseRenewalFreq)) of
                true -> debug_trace(Data, lock_status, send_lease_refresh),
                        refresh_lease_helper(RefreshLeaseStream, Data);
                _ -> {keep_state_and_data, [{state_timeout, ?WATCH_INTERVAL_MS, check_status}]}
            end
    end.

refresh_lease_helper(RefreshLeaseStream, #{lease_id := LeaseId, connection:=Connection} =Data) ->
    ok = grpc_client:send(RefreshLeaseStream, #{'ID' => LeaseId}),
    Result = grpc_client:rcv(RefreshLeaseStream, ?LEASE_RENEW_TIMEOUT_MS),
    case Result of
        {error, timeout} ->
            debug_trace(Data, lock_status, {error, lease_renewal_failed_timeout, ?LEASE_RENEW_TIMEOUT_MS}),
            reset_lock(Connection, LeaseId, Data);

        {data,#{'ID' := LeaseId,'TTL' := LeaseRenewTTL}} ->
            Now = erlang:system_time(second),
            NewData1 = maps:merge(Data, #{lease => #{stream => RefreshLeaseStream, timestamp => Now}}),
            debug_trace(NewData1, lock_status, lease_renewed),
            debug_notify(NewData1, {lease_renewed, self()}),

            NewData2 = update_has_lock(NewData1, LeaseRenewTTL),
            {keep_state, NewData2, [{state_timeout, ?WATCH_INTERVAL_MS, check_status}]};

        {headers, #{<<":status">> := <<"200">>, <<"content-type">> := _}} ->
            refresh_lease_helper(RefreshLeaseStream, Data);

        Unknown ->
            {next_state, unexpected_error, Data, [{next_event, internal, {unknown_event, check_lease_renewal, Unknown}}]}
    end.


waiting(#{watcher:= #{stream := Stream, id := WatchId}, key:= Key} = Data) ->
    case grpc_client:get(Stream) of
        empty ->
             IsMaster = maps:get(?HAS_LOCK, Data),
             case IsMaster of
                 true ->  refresh_lease(Data);
                 false -> {keep_state_and_data, [{state_timeout, ?WATCH_INTERVAL_MS, check_status}]}
             end;

        {headers, #{<<":status">> := <<"200">>, <<"content-type">> := _ }} ->
            waiting(Data);

        {data, #{cancel_reason := [], canceled := false, created := false,
            events := [#{kv := #{key := Key, lease := 0}, type := 'DELETE'}]}} ->
            debug_trace(Data, lock_status, lock_released),
            debug_notify(Data, {lock_released, self()}),
            {next_state, init_lock, Data, [{next_event, internal, lock_released}]};

        {data,#{cancel_reason := [],canceled := false, created := false, watch_id := WatchId}} ->
            {keep_state_and_data, [{state_timeout, ?WATCH_INTERVAL_MS, check_status}]};

        Unknown ->
            {next_state, unexpected_error, Data, [{next_event, internal, {unknown_event, waiting, Unknown}}]}
    end.

handle_common(cast, {has_lock, {From, Ref}}, Data) when is_reference(Ref) andalso is_pid(From) ->
    From ! {has_lock, Ref, maps:get(?HAS_LOCK, Data)},
    keep_state_and_data;

handle_common(cast, stop, #{connection := Connection} = Data)->
    debug_trace(Data, lock_status, {close_connection, Connection}),
    grpc_client:stop_connection(Connection),
    stop;

%% This is used for testing/diagnostic purpose only
handle_common(cast, close_connection, #{connection := Connection} = Data)->
    debug_trace(Data, lock_status, {close_connection, Connection}),
    ok = grpc_client:stop_connection(Connection),
    stop;

handle_common({call, From}, {set_trace, Trace} , Data) when is_list(Trace) ->
    NewData = maps:merge(Data, #{trace => Trace}),
    {keep_state, NewData, [{reply, From, ok}]};

handle_common({call, From}, {set_debug_pid, DebugPid} , Data) when is_pid(DebugPid) ->
    NewData = maps:merge(Data, #{debug_pid => DebugPid}),
    {keep_state, NewData, [{reply, From, ok}]};

handle_common({call,From}, has_lock, Data) ->
    {keep_state_and_data, [{reply,From,maps:get(?HAS_LOCK, Data)}]};

handle_common({call,From}, get_state, Data) ->
    {keep_state_and_data, [{reply,From,Data}]};

handle_common(info, {'EXIT', _Pid, normal}, _Data) ->
    keep_state_and_data;

handle_common(info, {'EXIT', Pid, closed_by_peer}, #{connection := #{http_connection := ConnPid}} = _Data) when Pid =:= ConnPid->
    stop;

handle_common(EventType, EventContent, Data) ->
    error_logger:error_msg("Unhandled: event_type ~p , event_content  ~p data ~p ~n", [EventType, EventContent, Data]),
    {stop, {EventType, EventContent, Data}}.

lease_id(Name) ->
    erlang:phash2(Name).

debug_trace(#{trace:=Trace}, Channel, Arg) when is_list(Trace) ->
    case lists:member(Channel, Trace) of
        true -> error_logger:info_msg("~p ~p: ~p ~p ~n", [?MODULE, self(), Channel, Arg]);
        false -> ok
    end.

debug_notify(#{debug_pid:=undefined}, _Msg) ->
    ok;
debug_notify(#{debug_pid:=Pid}, Msg) ->
    Pid ! Msg,
    ok.
