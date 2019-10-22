-module(lock_info_db_SUITE).
-include_lib("common_test/include/ct.hrl").
-include_lib("eqc/include/eqc.hrl").
-define(PORT, 23666).

%% API
-export([all/0, basic/1, store_retrieve/1, retrieve_not_existing/1, delete/1, delete_not_existing/1]).
-export([init_per_testcase/2, end_per_testcase/2]).

all() ->
    [basic, store_retrieve, retrieve_not_existing, delete, delete_not_existing].

init_per_testcase(_Testcase, Config) ->
    lock_info_db:start_link(),
    Config.

end_per_testcase(_Testcase, _Config) ->
    lock_info_db:stop().

basic(_Config) ->
    gen_server_common:registered_gen_server(lock_info_db),
    gen_server_common:stop(lock_info_db).

store_retrieve(_Config) ->
    store_retrieve_helper(asset).

retrieve_not_existing(_Config) ->
    {error, not_found} = lock_info_db:retrieve(#{host => "localhost", port => ?PORT, key => not_existing_key}).

delete(_Config) ->
    Key = some_key,
    store_retrieve_helper(Key),
    ok = lock_info_db:delete(#{host => "localhost", port => ?PORT, key => Key}),
    {error, not_found} = lock_info_db:delete(#{host => "localhost", port => ?PORT, key => Key}).

delete_not_existing(_Config) ->
    Key = unknown,
    {error, not_found} = lock_info_db:delete(#{host => "localhost", port => ?PORT, key => Key}).

store_retrieve_helper(Key) ->
    Value = #{a => 1, b => 2},
    Entry = #{host => "localhost", port => ?PORT, key => Key, value => Value},
    ok = lock_info_db:store(Entry),
    {ok, Value} = lock_info_db:retrieve(#{host => "localhost", port => ?PORT, key => Key}).
