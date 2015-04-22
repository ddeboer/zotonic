%% @copyright 2015 Arjan Scherpenisse
%% @doc Adds content groups to enable access-control rules on resources.

%% Copyright 2015 Arjan Scherpenisse
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(mod_acl_user_groups).
-author("Arjan Scherpenisse <arjan@miraclethings.nl>").

-mod_title("ACL User Groups").
-mod_description("Organize users into hierarchical groups").
-mod_prio(400).
-mod_schema(4).
-mod_depends([menu, mod_content_groups]).
-mod_provides([acl]).

-behaviour(gen_server).

-include_lib("zotonic.hrl").
-include_lib("modules/mod_admin/include/admin_menu.hrl").

% API
-export([
    status/1,
    table/1,
    table/2,
    await_table/1,
    await_table/2,
    await_table/3,
    lookup/2,
    await_lookup/2,
    rebuild/2,
    observe_admin_menu/3,
    observe_rsc_update_done/2,
    name/1,
    manage_schema/2
]).

% Access control hooks
-export([
    observe_acl_is_allowed/2,
    observe_acl_logon/2,
    observe_acl_logoff/2,
    observe_acl_rsc_update_check/3,
    observe_acl_add_sql_check/2,

    observe_hierarchy_updated/2
]).

%% gen_server exports
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export([start_link/1]).

%% gen_server state record
-record(state, {
            site, 
            is_rebuild_publish=true, 
            is_rebuild_edit=true,
            rebuilder_pid,
            rebuilder_mref,
            rebuilding,
            table_edit = [],
            table_publish = []
        }).

observe_acl_is_allowed(AclIsAllowed, Context) ->
    acl_user_groups_checks:acl_is_allowed(AclIsAllowed, Context).

observe_acl_logon(AclLogon, Context) ->
    acl_user_groups_checks:acl_logon(AclLogon, Context).

observe_acl_logoff(AclLogoff, Context) ->
    acl_user_groups_checks:acl_logoff(AclLogoff, Context).

observe_acl_rsc_update_check(AclRscUpdateCheck, Props, Context) ->
    acl_user_groups_checks:acl_rsc_update_check(AclRscUpdateCheck, Props, Context).

observe_acl_add_sql_check(AclAddSQLCheck, Context) ->
    acl_user_groups_checks:acl_add_sql_check(AclAddSQLCheck, Context).

observe_hierarchy_updated(#hierarchy_updated{root_id= <<"$category">>, predicate=undefined}, Context) ->
    rebuild(Context);
observe_hierarchy_updated(#hierarchy_updated{root_id= <<"content_group">>, predicate=undefined}, Context) ->
    rebuild(Context);
observe_hierarchy_updated(#hierarchy_updated{root_id= <<"acl_user_group">>, predicate=undefined}, Context) ->
    rebuild(Context);
observe_hierarchy_updated(#hierarchy_updated{}, _Context) ->
    ok.

observe_rsc_update_done(#rsc_update_done{pre_is_a=PreIsA, post_is_a=PostIsA}, Context) ->
    case  lists:member('acl_user_group', PreIsA) 
        orelse lists:member('acl_user_group', PostIsA)
    of
        true -> m_hierarchy:ensure('acl_user_group', Context);
        false -> ok
    end.

status(Context) ->
    gen_server:call(name(Context), status).

rebuild(Context) ->
    rebuild(publish, Context),
    rebuild(edit, Context).

rebuild(edit, Context) ->
    gen_server:cast(name(Context), rebuild_edit);
rebuild(publish, Context) ->
    gen_server:cast(name(Context), rebuild_publish).

-spec table(#context{}) -> ets:tab() | undefined.
table(Context) ->
    table(acl_user_groups_checks:state(Context), Context).

-spec await_table(#context{}) -> ets:tab() | undefined.
await_table(Context) ->
    await_table(acl_user_groups_checks:state(Context), Context).


-spec table(edit|publish, #context{}) -> ets:tab() | undefined.
table(State, Context) when State =:= edit; State =:= publish ->
    try
        gproc:get_value_shared({p,l,{z_context:site(Context), ?MODULE, State}})
    catch
        error:badarg ->
            undefined
    end.

-spec await_table(edit|publish, #context{}) -> ets:tab() | undefined.
await_table(State, Context) ->
    await_table(State, infinity, Context).

-spec await_table(edit|publish, integer()|infinity, #context{}) -> ets:tab() | undefined.
await_table(State, infinity, Context) ->
    case table(State, Context) of
        undefined ->
            timer:sleep(100),
            await_table(State, infinity, Context);
        TId ->
            TId
    end;
await_table(State, Timeout, Context) when Timeout > 0 ->
    case table(State, Context) of
        undefined ->
            timer:sleep(10),
            await_table(State, Timeout-10, Context);
        TId ->
            TId
    end.

lookup(Key, Context) ->
    lookup1(table(Context), Key).

await_lookup(Key, Context) ->
    lookup1(await_table(Context), Key).

lookup1(undefined, _Key) ->
    undefined;
lookup1(TId, Key) ->
    case ets:lookup(TId, Key) of
        [] -> undefined;
        [{_,V}|_] -> V
    end.


observe_admin_menu(admin_menu, Acc, Context) ->
    [
     #menu_item{id=admin_acl_user_groups,
                parent=admin_auth,
                label=?__("User groups", Context),
                url={admin_menu_hierarchy, [{name, "acl_user_group"}]},
                visiblecheck={acl, use, mod_acl_user_groups}},
     #menu_item{id=admin_content_groups,
                parent=admin_auth,
                label=?__("Access control rules", Context),
                url={admin_acl_rules_rsc, []},
                visiblecheck={acl, use, mod_acl_user_groups}}
     |Acc].


name(Context) ->
    z_utils:name_for_host(?MODULE, Context).    

%%====================================================================
%% API
%%====================================================================
%% @spec start_link(Args) -> {ok,Pid} | ignore | {error,Error}
%% @doc Starts the server
start_link(Args) when is_list(Args) ->
    {context, Context} = proplists:lookup(context, Args),
    gen_server:start_link({local, name(Context)}, ?MODULE, Args, []).

%%====================================================================
%% gen_server callbacks
%%====================================================================

%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore               |
%%                     {stop, Reason}
%% @doc Initiates the server.
init(Args) ->
    process_flag(trap_exit, true),
    {context, Context} = proplists:lookup(context, Args),
    Site = z_context:site(Context),
    lager:md([
        {site, Site},
        {module, ?MODULE}
      ]),
    timer:send_after(10, rebuild),
    {ok, #state{ site=Site, is_rebuild_publish=true, is_rebuild_edit=true}}.

handle_call(status, _From, State) ->
    Reply = {ok, [
        {is_rebuilding, is_pid(State#state.rebuilder_pid)},
        {rebuilding, State#state.rebuilding},
        {is_rebuild_publish, State#state.is_rebuild_publish},
        {is_rebuild_edit, State#state.is_rebuild_edit}
    ]},
    {reply, Reply, State};
handle_call(Message, _From, State) ->
    {stop, {unknown_call, Message}, State}.

handle_cast(rebuild_publish, State) ->
    timer:send_after(100, rebuild),
    {noreply, State#state{is_rebuild_publish=true}};
handle_cast(rebuild_edit, State) ->
    timer:send_after(750, rebuild),
    {noreply, State#state{is_rebuild_edit=true}};
handle_cast(rebuild, State) ->
    handle_info(rebuild, State);
handle_cast(Message, State) ->
    {stop, {unknown_cast, Message}, State}.

handle_info(rebuild, #state{rebuilder_pid=undefined} = State) ->
    State1 = maybe_rebuild(State),
    {noreply, State1};
handle_info(rebuild, #state{rebuilder_pid=Pid} = State) when is_pid(Pid) ->
    {noreply, State};

handle_info({'DOWN', MRef, process, _Pid, normal}, #state{rebuilder_mref=MRef} = State) ->
    lager:debug("[mod_acl_user_groups] rebuilder for ~p finished.", 
                [State#state.rebuilding]),
    State1 = State#state{
                    rebuilding=undefined, 
                    rebuilder_pid=undefined, 
                    rebuilder_mref=undefined
                },
    State2 = maybe_rebuild(State1),
    {noreply, State2};

handle_info({'DOWN', MRef, process, _Pid, Reason}, #state{rebuilder_mref=MRef} = State) ->
    lager:error("[mod_acl_user_groups] rebuilder for ~p down with reason ~p", 
                [State#state.rebuilding, Reason]),
    State1 = case State#state.rebuilding of
                publish -> State#state{is_rebuild_publish=true};
                edit -> State#state{is_rebuild_edit=true}
             end,
    timer:send_after(500, rebuild),
    {noreply, State1#state{
                    rebuilding=undefined, 
                    rebuilder_pid=undefined, 
                    rebuilder_mref=undefined
                }};

handle_info({'ETS-TRANSFER', TId, _FromPid, publish}, State) ->
    lager:debug("[mod_acl_user_groups] 'ETS-TRANSFER' for 'publish' (~p)", [TId]),
    gproc_new_ets(TId, publish, State#state.site),
    State1 = store_new_ets(TId, publish, State),
    {noreply, State1};
handle_info({'ETS-TRANSFER', TId, _FromPid, edit}, State) ->
    lager:debug("[mod_acl_user_groups] 'ETS-TRANSFER' for 'edit' (~p)", [TId]),
    gproc_new_ets(TId, edit, State#state.site),
    State1 = store_new_ets(TId, edit, State),
    {noreply, State1};

handle_info({'EXIT', _Pid, normal}, State) ->
    {noreply, State};

handle_info(Info, State) ->
    lager:warning("[mod_acl_user_groups] unknown info message ~p", [Info]),
    {noreply, State}.

%% @spec terminate(Reason, State) -> void()
%% @doc This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
terminate(_Reason, _State) ->
    ok.

%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @doc Convert process state when code is changed
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%%====================================================================
%% Internal functions
%%====================================================================

%% @doc Check if we need to start a rebuild process
maybe_rebuild(#state{is_rebuild_publish=true} = State) ->
    {Pid, MRef} = start_rebuilder(publish, State#state.site),
    State#state{
        is_rebuild_publish=false,
        rebuilder_pid=Pid,
        rebuilding=publish,
        rebuilder_mref=MRef
    };
maybe_rebuild(#state{is_rebuild_edit=true} = State) ->
    {Pid, MRef} = start_rebuilder(edit, State#state.site),
    State#state{
        is_rebuild_edit=false,
        rebuilder_pid=Pid, 
        rebuilding=edit, 
        rebuilder_mref=MRef
    };
maybe_rebuild(#state{} = State) ->
    State.


start_rebuilder(EditState, Site) ->
    Self = self(),
    Pid = erlang:spawn_link(fun() ->
                                Context = z_acl:sudo(z_context:new(Site)),
                                acl_user_group_rebuilder:rebuild(Self, EditState, Context)
                            end),
    MRef = erlang:monitor(process, Pid),
    {Pid, MRef}.

gproc_new_ets(TId, EditState, Site) ->
    Key = {Site, ?MODULE, EditState},
    try
        gproc:unreg_shared({p,l,Key})
    catch
        error:badarg -> ok
    end,
    true = gproc:reg_shared({p,l,Key}, TId).

store_new_ets(TId, publish, #state{table_publish=Ts} = State) ->
    Ts1 = drop_old_ets(Ts),
    State#state{table_publish=[TId|Ts1]};
store_new_ets(TId, edit, #state{table_edit=Ts} = State) ->
    Ts1 = drop_old_ets(Ts),
    State#state{table_edit=[TId|Ts1]}.

drop_old_ets([A|Rest]) ->
    lists:foreach(fun(TId) ->
                    ets:delete(TId)
                  end,
                  Rest),
    [A];
drop_old_ets([]) ->
    [].

%%====================================================================
%% Manage Schema
%%====================================================================

manage_schema(Version, Context) ->
    m_acl_rule:manage_schema(Version, Context),
    case m_rsc:is_a(acl_user_group_managers, acl_user_group, Context) of
        true ->
            % Basic groups are known, assume hierarchy is ok.
            manage_datamodel(Context),
            m_hierarchy:ensure(acl_user_group, Context),
            ok;
        false ->
            % Initial install - create a simple user group hierarchy to start with
            manage_datamodel(Context),

            % TODO: remove the above ACL groups from the Tree
            R = fun(N) -> m_rsc:rid(N, Context) end,
            Tree = m_hierarchy:menu(acl_user_group, Context),
            NewTree = [ {R(acl_user_group_anonymous),
                         [ {R(acl_user_group_members),
                            [ {R(acl_user_group_editors),
                               [ {R(acl_user_group_managers),
                                  []
                                 } ]
                              } ]
                           } ]
                        } | Tree ],
            m_hierarchy:save(acl_user_group, NewTree, Context)
    end,
    ok.

manage_datamodel(Context) ->
    z_datamodel:manage(
        ?MODULE,
        #datamodel{
            categories=
                [
                    {acl_user_group, meta,
                        [
                            {title, {trans, [{en, "User Group"}, {nl, "Gebruikersgroep"}]}}
                        ]}
                ],

            resources=
                [
                    {acl_user_group_anonymous,
                        acl_user_group,
                        [{title, {trans, [{en, "Anonymous"}, {nl, "Anoniem"}]}}]},
                    {acl_user_group_members,
                        acl_user_group,
                        [{title, {trans, [{en, "Members"}, {nl, "Gebruikers"}]}}]},
                    {acl_user_group_editors,
                        acl_user_group,
                        [{title, {trans, [{en, "Editors"}, {nl, "Redactie"}]}}]},
                    {acl_user_group_managers,
                        acl_user_group,
                        [{title, {trans, [{en, "Managers"}, {nl, "Beheerders"}]}}]}
                ],

            predicates=
                [
                    {hasusergroup, 
                        [{title, {trans, [{en, <<"In User Group">>},{nl, <<"In gebruikersgroep">>}]}}],
                        [{person, acl_user_group}]
                    }
                ]
        },
        Context).
