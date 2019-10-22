-module(lock_info_db).
-behaviour(gen_server).

%% API
-export([start_link/0, cl/1, stop/0, store/1, retrieve/1, delete/1]).

%% gen_server callbacks
-export([init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API
%%%===================================================================

cl(Request) ->
    gen_server:call(?MODULE, Request).


delete(#{host:=Host, port:=Port, key:=Key}=Info) when is_atom(Key) ->
    KeyBin = erlang:list_to_binary(erlang:atom_to_list(Key)),
    DeleteRangeReq = #{key => KeyBin},
    Response = etcdrpc(Host, Port,  fun etcdrpc_client:'DeleteRange'/3, DeleteRangeReq),

    case Response of
        {ok, #{grpc_status := 0, http_status := 200, result:= #{deleted := 1}}} ->
            ok;

        {ok, #{grpc_status := 0, http_status := 200, result:= #{deleted := 0}}} ->
            {error, not_found};

        {error, Error} ->
            error_logger:error_msg("cannot delete ~p due to ~p ~n", [Info, Error]),
            {error, Error}
    end.


store(#{host:=Host, port:=Port, key:= Key, value := Value}= Info) when is_map(Info)
                                                                   and is_atom(Key) ->
    KeyBin = erlang:list_to_binary(erlang:atom_to_list(Key)),
    PutReq=#{key => KeyBin, value => erlang:term_to_binary(Value)},
    Response = etcdrpc(Host, Port, fun etcdrpc_client:'Put'/3, PutReq),
    case Response of
        {ok, #{grpc_status := 0, http_status := 200}} -> ok;
        {error, Error} ->
            error_logger:error_msg("cannot store ~p due to ~p ~n", [Info, Error]),
            {error, Error}
    end.


retrieve(#{host:=Host, port:=Port, key:=Key}=Info) when is_atom(Key) ->
    KeyBin = erlang:list_to_binary(erlang:atom_to_list(Key)),
    RangeReq = #{key => KeyBin, limit => 1},
    Response = etcdrpc(Host, Port,  fun etcdrpc_client:'Range'/3, RangeReq),

    case Response of
        {ok, #{grpc_status := 0, http_status := 200, result:= #{kvs := [#{key :=KeyBin, value := ValueBin}]}}} ->
            {ok, erlang:binary_to_term(ValueBin)};

        {ok, #{grpc_status := 0, http_status := 200, result:= #{kvs := []}}} ->
            {error, not_found};

        {error, Error} ->
            error_logger:error_msg("cannot retrieve ~p due to ~p ~n", [Info, Error]),
            {error, Error}
    end.

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
    {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

stop() ->
    ok = gen_server:call(?SERVER, stop_connections),
    utils:server_exit(?MODULE, 5000).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------

-spec(init(Args :: term()) ->
    {ok, State :: map()} | {ok, State :: map(), timeout() | hibernate} |
    {stop, Reason :: term()} | ignore).
init(Args) ->
    process_flag(trap_exit, true),
    {ok,Opts} = opts:make(Args, [], []),
    put(init_opts, Opts), % for observer
    {ok, #{connection_registry => #{}, debug_pid => undefined}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_call(Request :: term(), From :: {pid(), Tag :: term()},
    State :: #{}) ->
    {reply, Reply :: term(), NewState :: #{}} |
    {reply, Reply :: term(), NewState :: #{}, timeout() | hibernate} |
    {noreply, NewState :: #{}} |
    {noreply, NewState :: #{}, timeout() | hibernate} |
    {stop, Reason :: term(), Reply :: term(), NewState :: #{}} |
    {stop, Reason :: term(), NewState :: #{}}).



handle_call({get_connection, {Host,Port}}, _From, #{connection_registry:=ConnectionRegistry}=State) ->
    %%TODO: transform ip-address/dns-name to one of them as part of key for connection registry
    case maps:get({Host, Port}, ConnectionRegistry, undefined) of
        undefined ->
            {ok, Connection} = grpc_client:connect(tcp, Host, Port),
            Updated = maps:merge(ConnectionRegistry, #{{Host, Port} => Connection}),
            {reply, Connection, maps:merge(State, #{connection_registry => Updated})};

        ExistingConnection ->
            {reply,ExistingConnection, State}
    end;


handle_call(stop_connections, _From, #{connection_registry:=ConnectionRegistry}=State) ->
    Results = maps:fold(fun(_K, Connection, Acc) ->
                            [grpc_client:stop_connection(Connection)] ++ Acc
                        end,
                        [],
                        ConnectionRegistry),
    {reply, utils:check_all_ok(Results), State};


handle_call({set_debug_pid, Pid}, _From, State) ->
    NewState = maps:merge(State, #{debug_pid => Pid}),
    {reply, ok, NewState};

handle_call({set_trace,Trace}, _From, State) when is_list(Trace) ->
    {reply,ok, maps:put(trace, Trace, State)};

handle_call(debug_state, _From, State) ->
    {reply, State, State};

handle_call({debug_sleep,Ms}, _From, State) ->
    timer:sleep(Ms),
    {reply,ok,State};

handle_call(Request, _From, State) ->
    {reply,{error,request,[{request,Request}]},State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
-spec(handle_cast(Request :: term(), State :: #{}) ->
    {noreply, NewState :: #{}} |
    {noreply, NewState :: #{}, timeout() | hibernate} |
    {stop, Reason :: term(), NewState :: #{}}).


handle_cast(_Request, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
-spec(handle_info(Info :: timeout() | term(), State :: #{}) ->
    {noreply, NewState :: #{}} |
    {noreply, NewState :: #{}, timeout() | hibernate} |
    {stop, Reason :: term(), NewState :: #{}}).

handle_info(_Msg, State) ->
    {noreply,State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
-spec(terminate(Reason :: (normal | shutdown | {shutdown, term()} | term()),
    State :: #{}) -> term()).
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
-spec(code_change(OldVsn :: term() | {down, term()}, State :: #{},
    Extra :: term()) ->
    {ok, NewState :: #{}} | {error, Reason :: term()}).
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

etcdrpc(Host, Port, Fun, Req) when is_list(Host) and is_integer(Port)->
    try
        Connection = gen_server:call(?SERVER, {get_connection, {Host, Port}}, 10*1000),
        erlang:apply(Fun, [Connection, Req,[]])
    catch C:E ->
        error_logger:error_msg("~p:~p:~p stacktrace ~p ~n", [?MODULE,C,E,erlang:get_stacktrace()]),
        %%TODO: if there is connection failure, we can try to restablish the connection and try the operation
        {error, {C,E}}
    end.
