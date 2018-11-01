-module(lock_mgr).
-behaviour(gen_statem).

%% API
-export([start_link/1, callback_mode/0, stop/0, init_lock/3, lock_acquired/3, lock_failed/3, lock_released/3, lease_renewed/3, lock_acquired_watch/3, unexpected_error/3, lock_failed_watch/3, get_state/0, is_master/0]).
%% gen_statem callbacks
-export([
    init/1,
    terminate/3,
    code_change/4
]).

-define(WATCHER_CREATION_TIMEOUT_MS, 10000).
-define(IS_MASTER, is_master).
-define(LEASE_RENEW_TIMEOUT_MS, 1000).
-define(LEASE_REFRESH_INTERVAL_S, 3).
-define(WATCH_INTERVAL_MS, 2000).
-define(WATCH_CREATED_MS, 1000).
-define(VALUE, binary:list_to_bin("val1")).
-define(KEY, binary:list_to_bin("key1")).
-define(SERVER, ?MODULE).
-define(LEASE_ID, 1).
-define(TTL, 180).

start_link(Args) ->
    gen_statem:start_link({local,?MODULE},?MODULE, Args, []).

stop() -> gen_statem:stop(?SERVER).

init(Args) ->
    error_logger:info_msg("Args ~p ~n", [Args]),
    {ok, init_lock,
        #{connection_config => Args},
        [{next_event, internal, create_lock}]}.

callback_mode() ->
    [state_functions].

get_state() ->
    gen_statem:call(?SERVER, get_state).

is_master() ->
    maps:get(?IS_MASTER, gen_statem:call(?SERVER, get_state)).

init_lock(internal, create_lock, #{connection_config := [{host, Host}, {port, Port}]}=Data) ->
    {ok, Connection} = grpc_client:connect(tcp, Host, Port),
    NewData = maps:merge(Data, #{connection => Connection}),
    create_lock(NewData);


init_lock(internal, recreate_lock, #{connection_config := [{host, Host}, {port, Port}] = Config, connection := Connection}) ->
    error_logger:info_msg("Stopping connection ~p, restarting init lock ~n",[Connection]),
    ok = grpc_client:stop_connection(Connection),
    {ok, NewConnection} = grpc_client:connect(tcp, Host, Port),
    NewData = #{connection => NewConnection, connection_config => Config},
    create_lock(NewData);

init_lock(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).


lock_acquired(internal, init_watcher, #{connection := Connection}= Data) ->
    NewData = init_watcher(Connection, Data),
    {next_state, lock_acquired_watch, NewData, [{next_event, internal, check_watcher_ack}]};

lock_acquired(state_timeout, check_status, Data) ->
    waiting(Data);

lock_acquired(info, Event, Data) ->
    handle_event(info, Event, Data);
lock_acquired(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

lock_acquired_watch(internal, check_watcher_ack, #{watcher:= Watcher} = Data) ->
    is_watcher_created(lock_acquired, Watcher, Data);

lock_acquired_watch(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

unexpected_error(internal, put_failed, Data) ->
    error_logger:error_msg("Unexpected error due to put_failure, data: ~p ~n", Data),
    reset_lock_mgr(Data);

unexpected_error(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

lock_failed_watch(internal, check_watcher_ack, #{watcher:=  Watcher} = Data) ->
    is_watcher_created(lock_failed, Watcher, Data);

lock_failed_watch(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

lock_failed(internal, lease_failed, #{connection := Connection} = Data) ->
    NewData = init_watcher(Connection, Data),
    {next_state, lock_failed_watch, NewData, [{next_event, internal, check_watcher_ack}]};

lock_failed(state_timeout, check_status, Data) ->
    waiting(Data);

lock_failed(info, Event, Data) ->
    handle_event(info, Event, Data);

lock_failed(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

lock_released(internal, retry_lock, Data)->
    create_lock(Data);

lock_released(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

lease_renewed(internal, check_lease_renewal, #{lease := #{stream := RefreshLeaseStream}} = Data) ->
    lease_renewed_helper(Data, RefreshLeaseStream);
lease_renewed(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).


terminate(Reason, StateName, Data) ->
    error_logger:info_msg("Terminated Reason ~p StateName ~p Data ~p ~n", [Reason, StateName, Data]),
    ok.

code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================


is_watcher_created(State, #{stream := Stream, id := WatchId}=Watcher, Data) ->
    GrpcSuccessHeaders = grpc_success_headers(),

    case grpc_client:rcv(Stream, ?WATCHER_CREATION_TIMEOUT_MS) of
        {error, timeout} ->
            error_logger:error_msg("~p_watcher creation FAILED, timeout ~p ~n", [State, ?WATCHER_CREATION_TIMEOUT_MS]),
            reset_lock_mgr(Data);
        {data, #{cancel_reason := [], canceled := false, created := true, watch_id := WatchId}} ->
            error_logger:info_msg("~p_watcher created ~p ~n", [State,WatchId]),
            {next_state, State, Data, [{state_timeout, ?WATCH_INTERVAL_MS, check_status}]};

        GrpcSuccessHeaders ->
            is_watcher_created(State, Watcher, Data)

    end.

reset_lock_mgr(#{connection := Connection} = Data) ->
    error_logger:info_msg("resetting lock state ~p ~n", [Data]),
    LeaseRevokeResponse = etcdrpc_client:'LeaseRevoke'(Connection, #{'ID' => ?LEASE_ID}, []),
    error_logger:info_msg("Lease revoked ~p ~n", LeaseRevokeResponse),
    {next_state, init_lock, Data, [next_event, internal, recreate_lock]}.

lease_renewed_helper(Data, RefreshLeaseStream) ->
    Result = grpc_client:rcv(RefreshLeaseStream, ?LEASE_RENEW_TIMEOUT_MS),
    GrpcSuccessHeaders = grpc_success_headers(),

    case Result of
        {error, timeout} ->
            error_logger:error_msg("lease renewal failed due to timeout in ~p ms ~n", [?WATCHER_CREATION_TIMEOUT_MS]),
            reset_lock_mgr(Data);

        {data,#{'ID' := ?LEASE_ID,'TTL' := LeaseRenewTTL}} ->
            NewData = update_master(Data, LeaseRenewTTL),
            error_logger:info_msg("lease_renewed: for ~p ~n", [LeaseRenewTTL]),
            {next_state, lock_acquired, NewData, [{state_timeout, ?WATCH_INTERVAL_MS, check_status}]};

        GrpcSuccessHeaders ->
            lease_renewed_helper(Data, RefreshLeaseStream)
    end.


create_lock(#{connection:= Connection} = Data) ->
    LeaseGrantResult = etcdrpc_client:'LeaseGrant'(Connection, #{'ID' => ?LEASE_ID, 'TTL' => ?TTL}, []),
    error_logger:info_msg("Lease Grant ~p ~n",[LeaseGrantResult]),
    case LeaseGrantResult of
        {ok, #{grpc_status := 0, http_status := 200, result := #{'ID' := ?LEASE_ID, 'TTL' := ActualTTL}}} ->
            M=#{key => ?KEY, value => ?VALUE, lease => ?LEASE_ID},
            PutResult = etcdrpc_client:'Put'(Connection, M, []),
            case PutResult of
                {ok, #{grpc_status := 0, http_status := 200}} ->
                    NewData = update_master(Data, ActualTTL),
                    error_logger:info_msg("Locking ACQUIRED for ~p ~n",[ActualTTL]),
                    {next_state, lock_acquired, NewData, [{next_event, internal, init_watcher}]};

                {error, PutError} ->
                    error_logger:error_msg("Locking FAILED due to ~p ~n",[PutError]),
                    {next_state, unexpected_error, Data, [{next_event, internal, put_failed}]}

            end;
        {error, LeaseError} ->
            error_logger:info_msg("Locking failed due to ~p ~n",[LeaseError]),
            NewData = update_master(Data),
            {next_state, lock_failed, NewData, [{next_event, internal, lease_failed}]}
    end.

update_master(Data, ActualTTL) ->
    maps:merge(Data, #{lock_duration => ActualTTL, ?IS_MASTER => true}).

update_master(Data) ->
    maps:merge(Data,#{?IS_MASTER => false}).

init_watcher(Connection, Data) ->
    {ok, WatchStream} = grpc_client:new_stream(Connection, 'Watch', 'Watch', etcdrpc),
    WatchId = rand:uniform(10000),
    Request = watcher_request(WatchId),
    ok = grpc_client:send(WatchStream, #{request_union => {create_request, Request}}),
    maps:merge(Data, #{watcher => #{stream => WatchStream, id => WatchId, status => initiated}}).

watcher_request(WatchId)->
    #{key => ?KEY, progress_notify => true, watch_id => WatchId}.

refresh_lease(#{connection := Connection} = Data) ->
    case maps:get(lease, Data, undefined) of
        undefined ->
            {ok, RefreshLeaseStream} = grpc_client:new_stream(Connection, 'Lease', 'LeaseKeepAlive', etcdrpc),
            refresh_lease_helper(RefreshLeaseStream, Data);

        #{stream := RefreshLeaseStream, timestamp := LastRefresh} ->
            Now = erlang:system_time(second),
            case (Now > (LastRefresh + ?LEASE_REFRESH_INTERVAL_S)) of
                true -> error_logger:info_msg("attempting lease renewal ~p ~n",[Now]),
                        refresh_lease_helper(RefreshLeaseStream, Data);
                _ -> error_logger:info_msg("no lease renewal ~p ~n",[Now]), {keep_state_and_data, [{state_timeout, ?WATCH_INTERVAL_MS, check_status}]}
            end
    end.

refresh_lease_helper(RefreshLeaseStream, Data) ->
    ok = grpc_client:send(RefreshLeaseStream, #{'ID' => ?LEASE_ID}),
    Now = erlang:system_time(second),
    NewData = maps:merge(Data, #{lease => #{stream => RefreshLeaseStream, timestamp => Now}}),
    {next_state, lease_renewed, NewData, [{next_event, internal, check_lease_renewal}]}.

waiting(#{watcher:= #{stream := Stream, watch_id := WatchId}} = Data) ->
    Get = grpc_client:get(Stream),
    GrpcSuccessHeaders = grpc_success_headers(),
    case Get of
        empty ->
             IsMaster = maps:get(?IS_MASTER, Data),
             case IsMaster of
                 true ->  refresh_lease(Data);
                 false -> {keep_state_and_data, [{state_timeout, ?WATCH_INTERVAL_MS, check_status}]}
             end;

        GrpcSuccessHeaders ->
            {keep_state_and_data, [{state_timeout, ?WATCH_INTERVAL_MS, check_status}]};

        {data,#{cancel_reason => [],canceled => false, created => false,events => [], watch_id => WatchId}} ->
            {keep_state_and_data, [{state_timeout, ?WATCH_INTERVAL_MS, check_status}]};

        {data, #{cancel_reason := [], canceled := false, created := false,
            events := [#{kv := #{key := DeletedKey, lease := 0}, type := 'DELETE'}]}} =DeleteEvent ->
            error_logger:info_msg("Lease expired ~p ~n", [Get]),

            case DeletedKey =:= ?KEY of
                true -> error_logger:info_msg("locker released ~p ~n", [Get]),
                        {next_state, lock_released, Data, [{next_event, internal, retry_lock}]};
                false -> error_logger:info_msg("DeleteEvent ~p ~n", [DeleteEvent]),
                        {keep_state_and_data, [{state_timeout, ?WATCH_INTERVAL_MS, check_status}]}
            end;

        Event ->
            error_logger:error_msg("Unexpected event ~p ~n", [Event]),
            {keep_state_and_data, [{state_timeout, ?WATCH_INTERVAL_MS, check_status}]}
    end.

grpc_success_headers() ->
    {headers,
        #{<<":status">> => <<"200">>,
          <<"content-type">> => <<"application/grpc">>}
    }.


handle_event(info, {'EXIT', Pid,normal} , Data) ->
    error_logger:info_msg("info received ~p , ~p Data ~p ~n", [erlang:process_info(Pid), Pid, Data]),
    {keep_state_and_data, [{state_timeout, ?WATCH_INTERVAL_MS, check_status}]}.

handle_common({call,From}, get_state, Data) ->
    {keep_state_and_data, [{reply,From,Data}]}.
