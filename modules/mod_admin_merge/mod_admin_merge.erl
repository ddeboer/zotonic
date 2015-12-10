%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2015 Marc Worrell
%% @doc UI for merging resources in the admin.

%% Copyright 2015 Marc Worrell
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

-module(mod_admin_merge).
-author("Marc Worrell <marc@worrell.nl>").

-mod_title("Admin Merge").
-mod_description("User interface to merge resources in the admin.").
-mod_prio(500).
-mod_depends([admin]).
-mod_provides([]).

-export([
    event/2
]).

-include_lib("zotonic.hrl").

event(#postback_notify{message="feedback", trigger="dialog-merge-find", target=TargetId}, Context) ->
    % Find pages matching the search criteria.
    Category = z_context:get_q(find_category, Context),
    Text = z_context:get_q(find_text, Context),
    Cats = case Category of
                "" -> [];
                <<>> -> [];
                CatId -> [{z_convert:to_integer(CatId)}]
           end,
    Vars = [
        {id, m_rsc:rid(z_context:get_q("id", Context), Context)},
        {cat, Cats},
        {text, Text}
    ],
    z_render:wire([
        {remove_class, [{target, TargetId}, {class, "loading"}]},
        {update, [{target, TargetId}, {template, "_merge_find_results.tpl"} | Vars]}
    ], Context);

event(#postback{message={merge_select, Args}}, Context) ->
    {id, Id} = proplists:lookup(id, Args),
    SelectId = m_rsc:rid(z_context:get_q(select_id, Context), Context),
    case z_acl:rsc_editable(Id, Context) andalso z_acl:rsc_editable(SelectId, Context) of
        true ->
            z_render:wire({redirect, [{dispatch, admin_merge_rsc_compare}, {id,Id}, {id2, SelectId}]}, Context);
        false ->
            z_render:growl(?__("Sorry, you have no permission to edit this page.", Context), Context)
    end;

event(#postback{message={merge, Args}}, Context) ->
    {winner_id, WinnerId} = proplists:lookup(winner_id, Args),
    {looser_id, LooserId} = proplists:lookup(looser_id, Args),
    case {m_rsc:p_no_acl(LooserId, is_protected, Context),
          z_acl:rsc_deletable(LooserId, Context),
          z_acl:rsc_editable(WinnerId, Context)}
    of
        {true, _, _} ->
            z_render:wire({alert, [{text,?__("The looser is protected, unprotect the looser before merging.", Context)}]}, Context);
        {_, false, _} ->
            z_render:wire({alert, [{text,?__("You do not have permission to delete the looser.", Context)}]}, Context);
        {_, _, false} ->
            z_render:wire({alert, [{text,?__("You do not have permission to edit the winner.", Context)}]}, Context);
        {false, true, true} ->
            ContextSpawn = z_context:prune_for_spawn(Context),
            erlang:spawn(
                fun() ->
                    ok = m_rsc:merge_delete(WinnerId, LooserId, ContextSpawn),
                    z_session_page:add_script(
                        z_render:wire({redirect, [{dispatch, admin_edit_rsc}, {id, WinnerId}]}, ContextSpawn))
                end),
            z_render:wire([
                    {growl, [{text, ?__("Merging the two pages ...", Context)}]},
                    {mask, [{target, "merge-diffs"}]}
                ], Context)
    end.
