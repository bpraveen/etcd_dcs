-module(etcdrpc_client).

%% this file was generated by grpc

-export(['Range'/3,
         'Put'/3,
         'DeleteRange'/3,
         'Txn'/3,
         'Compact'/3,
         'LeaseGrant'/3,
         'LeaseRevoke'/3,
         'LeaseTimeToLive'/3,
         'LeaseLeases'/3,
         'MemberAdd'/3,
         'MemberRemove'/3,
         'MemberUpdate'/3,
         'MemberList'/3,
         'Alarm'/3,
         'Status'/3,
         'Defragment'/3,
         'Hash'/3,
         'HashKV'/3,
         'MoveLeader'/3,
         'AuthEnable'/3,
         'AuthDisable'/3,
         'Authenticate'/3,
         'UserAdd'/3,
         'UserGet'/3,
         'UserList'/3,
         'UserDelete'/3,
         'UserChangePassword'/3,
         'UserGrantRole'/3,
         'UserRevokeRole'/3,
         'RoleAdd'/3,
         'RoleGet'/3,
         'RoleList'/3,
         'RoleDelete'/3,
         'RoleGrantPermission'/3,
         'RoleRevokePermission'/3]).

-type 'RangeRequest.SortOrder'() ::
    'NONE' |
    'ASCEND' |
    'DESCEND'.

-type 'RangeRequest.SortTarget'() ::
    'KEY' |
    'VERSION' |
    'CREATE' |
    'MOD' |
    'VALUE'.

-type 'Compare.CompareResult'() ::
    'EQUAL' |
    'GREATER' |
    'LESS' |
    'NOT_EQUAL'.

-type 'Compare.CompareTarget'() ::
    'VERSION' |
    'CREATE' |
    'MOD' |
    'VALUE' |
    'LEASE'.

-type 'WatchCreateRequest.FilterType'() ::
    'NOPUT' |
    'NODELETE'.

-type 'AlarmType'() ::
    'NONE' |
    'NOSPACE' |
    'CORRUPT'.

-type 'AlarmRequest.AlarmAction'() ::
    'GET' |
    'ACTIVATE' |
    'DEACTIVATE'.

-type 'Event.EventType'() ::
    'PUT' |
    'DELETE'.

-type 'Permission.Type'() ::
    'READ' |
    'WRITE' |
    'READWRITE'.

-type 'ResponseHeader'() ::
    #{cluster_id => integer(),
      member_id => integer(),
      revision => integer(),
      raft_term => integer()}.

-type 'RangeRequest'() ::
    #{key => binary(),
      range_end => binary(),
      limit => integer(),
      revision => integer(),
      sort_order => 'RangeRequest.SortOrder'() | integer(),
      sort_target => 'RangeRequest.SortTarget'() | integer(),
      serializable => boolean(),
      keys_only => boolean(),
      count_only => boolean(),
      min_mod_revision => integer(),
      max_mod_revision => integer(),
      min_create_revision => integer(),
      max_create_revision => integer()}.

-type 'RangeResponse'() ::
    #{header => 'ResponseHeader'(),
      kvs => ['KeyValue'()],
      more => boolean(),
      count => integer()}.

-type 'PutRequest'() ::
    #{key => binary(),
      value => binary(),
      lease => integer(),
      prev_kv => boolean(),
      ignore_value => boolean(),
      ignore_lease => boolean()}.

-type 'PutResponse'() ::
    #{header => 'ResponseHeader'(),
      prev_kv => 'KeyValue'()}.

-type 'DeleteRangeRequest'() ::
    #{key => binary(),
      range_end => binary(),
      prev_kv => boolean()}.

-type 'DeleteRangeResponse'() ::
    #{header => 'ResponseHeader'(),
      deleted => integer(),
      prev_kvs => ['KeyValue'()]}.

-type 'RequestOp'() ::
    #{request =>
          {request_range, 'RangeRequest'()} |
          {request_put, 'PutRequest'()} |
          {request_delete_range, 'DeleteRangeRequest'()} |
          {request_txn, 'TxnRequest'()}}.

-type 'ResponseOp'() ::
    #{response =>
          {response_range, 'RangeResponse'()} |
          {response_put, 'PutResponse'()} |
          {response_delete_range, 'DeleteRangeResponse'()} |
          {response_txn, 'TxnResponse'()}}.

-type 'Compare'() ::
    #{result => 'Compare.CompareResult'() | integer(),
      target => 'Compare.CompareTarget'() | integer(),
      key => binary(),
      target_union =>
          {version, integer()} |
          {create_revision, integer()} |
          {mod_revision, integer()} |
          {value, binary()} |
          {lease, integer()},
      range_end => binary()}.

-type 'TxnRequest'() ::
    #{compare => ['Compare'()],
      success => ['RequestOp'()],
      failure => ['RequestOp'()]}.

-type 'TxnResponse'() ::
    #{header => 'ResponseHeader'(),
      succeeded => boolean(),
      responses => ['ResponseOp'()]}.

-type 'CompactionRequest'() ::
    #{revision => integer(),
      physical => boolean()}.

-type 'CompactionResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'HashRequest'() ::
    #{}.

-type 'HashKVRequest'() ::
    #{revision => integer()}.

-type 'HashKVResponse'() ::
    #{header => 'ResponseHeader'(),
      hash => integer(),
      compact_revision => integer()}.

-type 'HashResponse'() ::
    #{header => 'ResponseHeader'(),
      hash => integer()}.

-type 'SnapshotRequest'() ::
    #{}.

-type 'SnapshotResponse'() ::
    #{header => 'ResponseHeader'(),
      remaining_bytes => integer(),
      blob => binary()}.

-type 'WatchRequest'() ::
    #{request_union =>
          {create_request, 'WatchCreateRequest'()} |
          {cancel_request, 'WatchCancelRequest'()} |
          {progress_request, 'WatchProgressRequest'()}}.

-type 'WatchCreateRequest'() ::
    #{key => binary(),
      range_end => binary(),
      start_revision => integer(),
      progress_notify => boolean(),
      filters => ['WatchCreateRequest.FilterType'() | integer()],
      prev_kv => boolean(),
      watch_id => integer(),
      fragment => boolean()}.

-type 'WatchCancelRequest'() ::
    #{watch_id => integer()}.

-type 'WatchProgressRequest'() ::
    #{}.

-type 'WatchResponse'() ::
    #{header => 'ResponseHeader'(),
      watch_id => integer(),
      created => boolean(),
      canceled => boolean(),
      compact_revision => integer(),
      cancel_reason => string(),
      fragment => boolean(),
      events => ['Event'()]}.

-type 'LeaseGrantRequest'() ::
    #{'TTL' => integer(),
      'ID' => integer()}.

-type 'LeaseGrantResponse'() ::
    #{header => 'ResponseHeader'(),
      'ID' => integer(),
      'TTL' => integer(),
      error => string()}.

-type 'LeaseRevokeRequest'() ::
    #{'ID' => integer()}.

-type 'LeaseRevokeResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'LeaseCheckpoint'() ::
    #{'ID' => integer(),
      remaining_TTL => integer()}.

-type 'LeaseCheckpointRequest'() ::
    #{checkpoints => ['LeaseCheckpoint'()]}.

-type 'LeaseCheckpointResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'LeaseKeepAliveRequest'() ::
    #{'ID' => integer()}.

-type 'LeaseKeepAliveResponse'() ::
    #{header => 'ResponseHeader'(),
      'ID' => integer(),
      'TTL' => integer()}.

-type 'LeaseTimeToLiveRequest'() ::
    #{'ID' => integer(),
      keys => boolean()}.

-type 'LeaseTimeToLiveResponse'() ::
    #{header => 'ResponseHeader'(),
      'ID' => integer(),
      'TTL' => integer(),
      grantedTTL => integer(),
      keys => [binary()]}.

-type 'LeaseLeasesRequest'() ::
    #{}.

-type 'LeaseStatus'() ::
    #{'ID' => integer()}.

-type 'LeaseLeasesResponse'() ::
    #{header => 'ResponseHeader'(),
      leases => ['LeaseStatus'()]}.

-type 'Member'() ::
    #{'ID' => integer(),
      name => string(),
      peerURLs => [string()],
      clientURLs => [string()]}.

-type 'MemberAddRequest'() ::
    #{peerURLs => [string()]}.

-type 'MemberAddResponse'() ::
    #{header => 'ResponseHeader'(),
      member => 'Member'(),
      members => ['Member'()]}.

-type 'MemberRemoveRequest'() ::
    #{'ID' => integer()}.

-type 'MemberRemoveResponse'() ::
    #{header => 'ResponseHeader'(),
      members => ['Member'()]}.

-type 'MemberUpdateRequest'() ::
    #{'ID' => integer(),
      peerURLs => [string()]}.

-type 'MemberUpdateResponse'() ::
    #{header => 'ResponseHeader'(),
      members => ['Member'()]}.

-type 'MemberListRequest'() ::
    #{}.

-type 'MemberListResponse'() ::
    #{header => 'ResponseHeader'(),
      members => ['Member'()]}.

-type 'DefragmentRequest'() ::
    #{}.

-type 'DefragmentResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'MoveLeaderRequest'() ::
    #{targetID => integer()}.

-type 'MoveLeaderResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'AlarmRequest'() ::
    #{action => 'AlarmRequest.AlarmAction'() | integer(),
      memberID => integer(),
      alarm => 'AlarmType'() | integer()}.

-type 'AlarmMember'() ::
    #{memberID => integer(),
      alarm => 'AlarmType'() | integer()}.

-type 'AlarmResponse'() ::
    #{header => 'ResponseHeader'(),
      alarms => ['AlarmMember'()]}.

-type 'StatusRequest'() ::
    #{}.

-type 'StatusResponse'() ::
    #{header => 'ResponseHeader'(),
      version => string(),
      dbSize => integer(),
      leader => integer(),
      raftIndex => integer(),
      raftTerm => integer(),
      raftAppliedIndex => integer(),
      errors => [string()],
      dbSizeInUse => integer()}.

-type 'AuthEnableRequest'() ::
    #{}.

-type 'AuthDisableRequest'() ::
    #{}.

-type 'AuthenticateRequest'() ::
    #{name => string(),
      password => string()}.

-type 'AuthUserAddRequest'() ::
    #{name => string(),
      password => string()}.

-type 'AuthUserGetRequest'() ::
    #{name => string()}.

-type 'AuthUserDeleteRequest'() ::
    #{name => string()}.

-type 'AuthUserChangePasswordRequest'() ::
    #{name => string(),
      password => string()}.

-type 'AuthUserGrantRoleRequest'() ::
    #{user => string(),
      role => string()}.

-type 'AuthUserRevokeRoleRequest'() ::
    #{name => string(),
      role => string()}.

-type 'AuthRoleAddRequest'() ::
    #{name => string()}.

-type 'AuthRoleGetRequest'() ::
    #{role => string()}.

-type 'AuthUserListRequest'() ::
    #{}.

-type 'AuthRoleListRequest'() ::
    #{}.

-type 'AuthRoleDeleteRequest'() ::
    #{role => string()}.

-type 'AuthRoleGrantPermissionRequest'() ::
    #{name => string(),
      perm => 'Permission'()}.

-type 'AuthRoleRevokePermissionRequest'() ::
    #{role => string(),
      key => binary(),
      range_end => binary()}.

-type 'AuthEnableResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'AuthDisableResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'AuthenticateResponse'() ::
    #{header => 'ResponseHeader'(),
      token => string()}.

-type 'AuthUserAddResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'AuthUserGetResponse'() ::
    #{header => 'ResponseHeader'(),
      roles => [string()]}.

-type 'AuthUserDeleteResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'AuthUserChangePasswordResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'AuthUserGrantRoleResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'AuthUserRevokeRoleResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'AuthRoleAddResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'AuthRoleGetResponse'() ::
    #{header => 'ResponseHeader'(),
      perm => ['Permission'()]}.

-type 'AuthRoleListResponse'() ::
    #{header => 'ResponseHeader'(),
      roles => [string()]}.

-type 'AuthUserListResponse'() ::
    #{header => 'ResponseHeader'(),
      users => [string()]}.

-type 'AuthRoleDeleteResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'AuthRoleGrantPermissionResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'AuthRoleRevokePermissionResponse'() ::
    #{header => 'ResponseHeader'()}.

-type 'KeyValue'() ::
    #{key => binary(),
      create_revision => integer(),
      mod_revision => integer(),
      version => integer(),
      value => binary(),
      lease => integer()}.

-type 'Event'() ::
    #{type => 'Event.EventType'() | integer(),
      kv => 'KeyValue'(),
      prev_kv => 'KeyValue'()}.

-type 'User'() ::
    #{name => binary(),
      password => binary(),
      roles => [string()]}.

-type 'Permission'() ::
    #{permType => 'Permission.Type'() | integer(),
      key => binary(),
      range_end => binary()}.

-type 'Role'() ::
    #{name => binary(),
      keyPermission => ['Permission'()]}.

-export_type(['RangeRequest.SortOrder'/0,
              'RangeRequest.SortTarget'/0,
              'Compare.CompareResult'/0,
              'Compare.CompareTarget'/0,
              'WatchCreateRequest.FilterType'/0,
              'AlarmType'/0,
              'AlarmRequest.AlarmAction'/0,
              'Event.EventType'/0,
              'Permission.Type'/0,
              'ResponseHeader'/0,
              'RangeRequest'/0,
              'RangeResponse'/0,
              'PutRequest'/0,
              'PutResponse'/0,
              'DeleteRangeRequest'/0,
              'DeleteRangeResponse'/0,
              'RequestOp'/0,
              'ResponseOp'/0,
              'Compare'/0,
              'TxnRequest'/0,
              'TxnResponse'/0,
              'CompactionRequest'/0,
              'CompactionResponse'/0,
              'HashRequest'/0,
              'HashKVRequest'/0,
              'HashKVResponse'/0,
              'HashResponse'/0,
              'SnapshotRequest'/0,
              'SnapshotResponse'/0,
              'WatchRequest'/0,
              'WatchCreateRequest'/0,
              'WatchCancelRequest'/0,
              'WatchProgressRequest'/0,
              'WatchResponse'/0,
              'LeaseGrantRequest'/0,
              'LeaseGrantResponse'/0,
              'LeaseRevokeRequest'/0,
              'LeaseRevokeResponse'/0,
              'LeaseCheckpoint'/0,
              'LeaseCheckpointRequest'/0,
              'LeaseCheckpointResponse'/0,
              'LeaseKeepAliveRequest'/0,
              'LeaseKeepAliveResponse'/0,
              'LeaseTimeToLiveRequest'/0,
              'LeaseTimeToLiveResponse'/0,
              'LeaseLeasesRequest'/0,
              'LeaseStatus'/0,
              'LeaseLeasesResponse'/0,
              'Member'/0,
              'MemberAddRequest'/0,
              'MemberAddResponse'/0,
              'MemberRemoveRequest'/0,
              'MemberRemoveResponse'/0,
              'MemberUpdateRequest'/0,
              'MemberUpdateResponse'/0,
              'MemberListRequest'/0,
              'MemberListResponse'/0,
              'DefragmentRequest'/0,
              'DefragmentResponse'/0,
              'MoveLeaderRequest'/0,
              'MoveLeaderResponse'/0,
              'AlarmRequest'/0,
              'AlarmMember'/0,
              'AlarmResponse'/0,
              'StatusRequest'/0,
              'StatusResponse'/0,
              'AuthEnableRequest'/0,
              'AuthDisableRequest'/0,
              'AuthenticateRequest'/0,
              'AuthUserAddRequest'/0,
              'AuthUserGetRequest'/0,
              'AuthUserDeleteRequest'/0,
              'AuthUserChangePasswordRequest'/0,
              'AuthUserGrantRoleRequest'/0,
              'AuthUserRevokeRoleRequest'/0,
              'AuthRoleAddRequest'/0,
              'AuthRoleGetRequest'/0,
              'AuthUserListRequest'/0,
              'AuthRoleListRequest'/0,
              'AuthRoleDeleteRequest'/0,
              'AuthRoleGrantPermissionRequest'/0,
              'AuthRoleRevokePermissionRequest'/0,
              'AuthEnableResponse'/0,
              'AuthDisableResponse'/0,
              'AuthenticateResponse'/0,
              'AuthUserAddResponse'/0,
              'AuthUserGetResponse'/0,
              'AuthUserDeleteResponse'/0,
              'AuthUserChangePasswordResponse'/0,
              'AuthUserGrantRoleResponse'/0,
              'AuthUserRevokeRoleResponse'/0,
              'AuthRoleAddResponse'/0,
              'AuthRoleGetResponse'/0,
              'AuthRoleListResponse'/0,
              'AuthUserListResponse'/0,
              'AuthRoleDeleteResponse'/0,
              'AuthRoleGrantPermissionResponse'/0,
              'AuthRoleRevokePermissionResponse'/0,
              'KeyValue'/0,
              'Event'/0,
              'User'/0,
              'Permission'/0,
              'Role'/0]).

-spec decoder() -> module().
%% The module (generated by gpb) used to encode and decode protobuf
%% messages.
decoder() -> etcdrpc.

%% RPCs for service 'KV'

-spec 'Range'(
        Connection::grpc_client:connection(),
        Message::'RangeRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('RangeResponse'()).
%% This is a unary RPC
'Range'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'KV', 'Range',
                       decoder(), Options).

-spec 'Put'(
        Connection::grpc_client:connection(),
        Message::'PutRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('PutResponse'()).
%% This is a unary RPC
'Put'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'KV', 'Put',
                       decoder(), Options).

-spec 'DeleteRange'(
        Connection::grpc_client:connection(),
        Message::'DeleteRangeRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('DeleteRangeResponse'()).
%% This is a unary RPC
'DeleteRange'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'KV', 'DeleteRange',
                       decoder(), Options).

-spec 'Txn'(
        Connection::grpc_client:connection(),
        Message::'TxnRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('TxnResponse'()).
%% This is a unary RPC
'Txn'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'KV', 'Txn',
                       decoder(), Options).

-spec 'Compact'(
        Connection::grpc_client:connection(),
        Message::'CompactionRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('CompactionResponse'()).
%% This is a unary RPC
'Compact'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'KV', 'Compact',
                       decoder(), Options).

%% RPCs for service 'Watch'

%% RPCs for service 'Lease'

-spec 'LeaseGrant'(
        Connection::grpc_client:connection(),
        Message::'LeaseGrantRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('LeaseGrantResponse'()).
%% This is a unary RPC
'LeaseGrant'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Lease', 'LeaseGrant',
                       decoder(), Options).

-spec 'LeaseRevoke'(
        Connection::grpc_client:connection(),
        Message::'LeaseRevokeRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('LeaseRevokeResponse'()).
%% This is a unary RPC
'LeaseRevoke'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Lease', 'LeaseRevoke',
                       decoder(), Options).

-spec 'LeaseTimeToLive'(
        Connection::grpc_client:connection(),
        Message::'LeaseTimeToLiveRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('LeaseTimeToLiveResponse'()).
%% This is a unary RPC
'LeaseTimeToLive'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Lease', 'LeaseTimeToLive',
                       decoder(), Options).

-spec 'LeaseLeases'(
        Connection::grpc_client:connection(),
        Message::'LeaseLeasesRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('LeaseLeasesResponse'()).
%% This is a unary RPC
'LeaseLeases'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Lease', 'LeaseLeases',
                       decoder(), Options).

%% RPCs for service 'Cluster'

-spec 'MemberAdd'(
        Connection::grpc_client:connection(),
        Message::'MemberAddRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('MemberAddResponse'()).
%% This is a unary RPC
'MemberAdd'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Cluster', 'MemberAdd',
                       decoder(), Options).

-spec 'MemberRemove'(
        Connection::grpc_client:connection(),
        Message::'MemberRemoveRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('MemberRemoveResponse'()).
%% This is a unary RPC
'MemberRemove'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Cluster', 'MemberRemove',
                       decoder(), Options).

-spec 'MemberUpdate'(
        Connection::grpc_client:connection(),
        Message::'MemberUpdateRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('MemberUpdateResponse'()).
%% This is a unary RPC
'MemberUpdate'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Cluster', 'MemberUpdate',
                       decoder(), Options).

-spec 'MemberList'(
        Connection::grpc_client:connection(),
        Message::'MemberListRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('MemberListResponse'()).
%% This is a unary RPC
'MemberList'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Cluster', 'MemberList',
                       decoder(), Options).

%% RPCs for service 'Maintenance'

-spec 'Alarm'(
        Connection::grpc_client:connection(),
        Message::'AlarmRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AlarmResponse'()).
%% This is a unary RPC
'Alarm'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Maintenance', 'Alarm',
                       decoder(), Options).

-spec 'Status'(
        Connection::grpc_client:connection(),
        Message::'StatusRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('StatusResponse'()).
%% This is a unary RPC
'Status'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Maintenance', 'Status',
                       decoder(), Options).

-spec 'Defragment'(
        Connection::grpc_client:connection(),
        Message::'DefragmentRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('DefragmentResponse'()).
%% This is a unary RPC
'Defragment'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Maintenance', 'Defragment',
                       decoder(), Options).

-spec 'Hash'(
        Connection::grpc_client:connection(),
        Message::'HashRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('HashResponse'()).
%% This is a unary RPC
'Hash'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Maintenance', 'Hash',
                       decoder(), Options).

-spec 'HashKV'(
        Connection::grpc_client:connection(),
        Message::'HashKVRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('HashKVResponse'()).
%% This is a unary RPC
'HashKV'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Maintenance', 'HashKV',
                       decoder(), Options).

-spec 'MoveLeader'(
        Connection::grpc_client:connection(),
        Message::'MoveLeaderRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('MoveLeaderResponse'()).
%% This is a unary RPC
'MoveLeader'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Maintenance', 'MoveLeader',
                       decoder(), Options).

%% RPCs for service 'Auth'

-spec 'AuthEnable'(
        Connection::grpc_client:connection(),
        Message::'AuthEnableRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthEnableResponse'()).
%% This is a unary RPC
'AuthEnable'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'AuthEnable',
                       decoder(), Options).

-spec 'AuthDisable'(
        Connection::grpc_client:connection(),
        Message::'AuthDisableRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthDisableResponse'()).
%% This is a unary RPC
'AuthDisable'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'AuthDisable',
                       decoder(), Options).

-spec 'Authenticate'(
        Connection::grpc_client:connection(),
        Message::'AuthenticateRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthenticateResponse'()).
%% This is a unary RPC
'Authenticate'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'Authenticate',
                       decoder(), Options).

-spec 'UserAdd'(
        Connection::grpc_client:connection(),
        Message::'AuthUserAddRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthUserAddResponse'()).
%% This is a unary RPC
'UserAdd'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'UserAdd',
                       decoder(), Options).

-spec 'UserGet'(
        Connection::grpc_client:connection(),
        Message::'AuthUserGetRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthUserGetResponse'()).
%% This is a unary RPC
'UserGet'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'UserGet',
                       decoder(), Options).

-spec 'UserList'(
        Connection::grpc_client:connection(),
        Message::'AuthUserListRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthUserListResponse'()).
%% This is a unary RPC
'UserList'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'UserList',
                       decoder(), Options).

-spec 'UserDelete'(
        Connection::grpc_client:connection(),
        Message::'AuthUserDeleteRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthUserDeleteResponse'()).
%% This is a unary RPC
'UserDelete'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'UserDelete',
                       decoder(), Options).

-spec 'UserChangePassword'(
        Connection::grpc_client:connection(),
        Message::'AuthUserChangePasswordRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthUserChangePasswordResponse'()).
%% This is a unary RPC
'UserChangePassword'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'UserChangePassword',
                       decoder(), Options).

-spec 'UserGrantRole'(
        Connection::grpc_client:connection(),
        Message::'AuthUserGrantRoleRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthUserGrantRoleResponse'()).
%% This is a unary RPC
'UserGrantRole'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'UserGrantRole',
                       decoder(), Options).

-spec 'UserRevokeRole'(
        Connection::grpc_client:connection(),
        Message::'AuthUserRevokeRoleRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthUserRevokeRoleResponse'()).
%% This is a unary RPC
'UserRevokeRole'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'UserRevokeRole',
                       decoder(), Options).

-spec 'RoleAdd'(
        Connection::grpc_client:connection(),
        Message::'AuthRoleAddRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthRoleAddResponse'()).
%% This is a unary RPC
'RoleAdd'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'RoleAdd',
                       decoder(), Options).

-spec 'RoleGet'(
        Connection::grpc_client:connection(),
        Message::'AuthRoleGetRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthRoleGetResponse'()).
%% This is a unary RPC
'RoleGet'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'RoleGet',
                       decoder(), Options).

-spec 'RoleList'(
        Connection::grpc_client:connection(),
        Message::'AuthRoleListRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthRoleListResponse'()).
%% This is a unary RPC
'RoleList'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'RoleList',
                       decoder(), Options).

-spec 'RoleDelete'(
        Connection::grpc_client:connection(),
        Message::'AuthRoleDeleteRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthRoleDeleteResponse'()).
%% This is a unary RPC
'RoleDelete'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'RoleDelete',
                       decoder(), Options).

-spec 'RoleGrantPermission'(
        Connection::grpc_client:connection(),
        Message::'AuthRoleGrantPermissionRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthRoleGrantPermissionResponse'()).
%% This is a unary RPC
'RoleGrantPermission'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'RoleGrantPermission',
                       decoder(), Options).

-spec 'RoleRevokePermission'(
        Connection::grpc_client:connection(),
        Message::'AuthRoleRevokePermissionRequest'(),
        Options::[grpc_client:stream_option() |
                  {timeout, timeout()}]) ->
        grpc_client:unary_response('AuthRoleRevokePermissionResponse'()).
%% This is a unary RPC
'RoleRevokePermission'(Connection, Message, Options) ->
    grpc_client:unary(Connection, Message,
                      'Auth', 'RoleRevokePermission',
                       decoder(), Options).

