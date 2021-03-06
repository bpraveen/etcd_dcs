-module(lock_mgr).
-behaviour(gen_server).

%% API
-export([start_link/0, apply_for_lock/1, is_registered/1, has_lock_async/1, stop/0, cl/1, debug_has_lock/1]).

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

is_registered({Name, From}) ->
    gen_server:call(lock_mgr, {is_registered, {Name, From}}).

apply_for_lock(LockRequest)->
    gen_server:call(lock_mgr, {lock_request, LockRequest}).

debug_has_lock({Name, From}) when is_atom(Name) ->
    State = gen_server:call(lock_mgr, debug_state),
    LockRegistry = maps:get(lock_registry, State),
    case maps:get({Name, From}, LockRegistry, undefined) of
        {_, LockSrvPid} -> gen_server:call(LockSrvPid, has_lock);
        undefined -> {error, {lock_not_requested, {Name, From}}}
    end.

has_lock_async({LockName, From, Ref} = Sub) when is_atom(LockName)
                                                andalso is_pid(From)
                                                andalso is_reference(Ref) ->
    gen_server:cast(lock_mgr, {has_lock, Sub}).


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
    State = lock_mgr:cl(debug_state),
    LockRegistry = maps:get(lock_registry, State),

    RegistryEntries = maps:to_list(LockRegistry),
    [gen_server:cast(LockSrvPid, stop) || {_N, {_LockRequest ,LockSrvPid}} <- RegistryEntries],
    utils:server_exit(?MODULE, 5000),
    ok.

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
    {ok, #{lock_registry => #{}, debug_pid => undefined}}.

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

handle_call(reset_lock_registry,_From, #{lock_registry := _LockRegistry} = State) ->
    {reply, ok, maps:merge(State, #{lock_registry => #{}})};

handle_call({lock_request, #{name:=Name, from:= From} = LockRequest}, _From, #{lock_registry := LockRegistry} =State) when is_atom(Name) and is_pid(From) ->
    IsRegistered = maps:is_key({Name, From}, LockRegistry),
    case IsRegistered of
        false ->
            {ok, LockSrvPid}= supervisor:start_child(lock_sup, [LockRequest]),
            monitor_subscriber_and_its_lock_srv(From, LockSrvPid),
            %% gen_server:call(LockSrvPid, {set_trace, [lock_status]}),
            NewSubscriber = #{{Name, From} => {LockRequest, LockSrvPid}},
            UpdatedLockRegistry = maps:merge(LockRegistry, NewSubscriber),
            NewState = maps:merge(State, #{lock_registry => UpdatedLockRegistry}),
            debug_notify(State, {registered_lock, LockRequest}),
            {reply, ok, NewState};

        true ->
            {reply, {error, {lock_request_exists, LockRequest}}, State}
    end;

handle_call({is_registered, {Name, From}}, _From, #{lock_registry := LockRegistry} = State) when is_atom(Name) ->
    {reply, maps:is_key({Name, From}, LockRegistry), State};

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

handle_cast({has_lock, {LockName, From, Ref}}, #{lock_registry:=LockRegistry}=State) ->
    case maps:get({LockName, From}, LockRegistry, undefined) of
        {_, LockSrvPid} -> gen_server:cast(LockSrvPid, {has_lock, {From, Ref}});
        undefined -> From ! {has_lock, Ref, {error, {lock_not_requested, LockName, From}}}
    end,
    {noreply, State};

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

handle_info({'DOWN', _Ref, process, Pid, Reason}, State = #{lock_registry:= LockRegistry}) ->
    error_logger:info_msg("DOWN from ~p , ~p, State ~p ~n", [Pid, Reason, State]),
    %% When the subscriber process dies we should terminate its lock srv pid as well.
    LockRegistryEntries = maps:to_list(LockRegistry),
    SubscriberExists = [{{_N,SubscriberPid}, _E} || {{_N,SubscriberPid}, _E} <- LockRegistryEntries, SubscriberPid =:= Pid],
    case SubscriberExists of
        [{{_N,S}, {_LR, LockSrvPid}}] ->
            %% it is important to terminate a single child with supervisor:terminate_child function
            error_logger:info_msg("Subscriber process ~p died due to ~p, the lock srv pid ~p will terminate soon, State ~p ~n", [S, Reason, LockSrvPid, State]),
            supervisor:terminate_child(lock_sup, LockSrvPid),
            {noreply, State};
        [] ->
            %% Let us check if the lock srv process died, then we remove the registration
            EntryExists = [K || {K, {_LR, LPid}} <- LockRegistryEntries, LPid =:= Pid],
            case EntryExists of
                 [] ->
                        {noreply, State};

                 [{Name, Sub}] ->
                        UpdatedLockRegistry = maps:remove({Name, Sub}, LockRegistry),
                        Sub ! {error, {deregistered_lock, {Name, Sub}}},
                        debug_notify(State, {deregistered_lock, {Name, Sub}}),
                        {noreply, maps:merge(State, #{lock_registry => UpdatedLockRegistry})}

            end
    end;

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
debug_notify(#{debug_pid:=undefined}, _Msg) ->
    ok;
debug_notify(#{debug_pid:=Pid}, Msg) ->
    Pid ! Msg,
    ok.

monitor_subscriber_and_its_lock_srv(From, LockSrvPid) ->
    erlang:monitor(process, LockSrvPid),
    erlang:monitor(process, From).
