%% @author Marc Worrell <marc@worrell.nl>
%% @copyright 2009 Marc Worrell
%% @date 2009-07-07
%% @doc Open a dialog that asks confirmation to delete a member from a group

%% Copyright 2009 Marc Worrell
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

-module(action_admin_group_dialog_group_member_delete).
-author("Marc Worrell <marc@worrell.nl").

%% interface functions
-export([
    render_action/4,
    event/2
]).

-include("zotonic.hrl").

render_action(TriggerId, TargetId, Args, Context) ->
    Id = z_convert:to_integer(proplists:get_value(id, Args)),
    MemberId = z_convert:to_integer(proplists:get_value(member_id, Args)),
    OnSuccess = proplists:get_all_values(on_success, Args),
    Postback = {group_member_delete_dialog, Id, MemberId, OnSuccess},
	{PostbackMsgJS, _PickledPostback} = z_render:make_postback(Postback, click, TriggerId, TargetId, ?MODULE, Context),
	{PostbackMsgJS, Context}.


%% @doc Fill the dialog with the delete confirmation template. The next step will ask to delete the member from the group.
%% @spec event(Event, Context1) -> Context2
event({postback, {group_member_delete_dialog, Id, MemberId, OnSuccess}, _TriggerId, _TargetId}, Context) ->
    case z_acl:has_group_role(leader, Id, Context) of
        true ->
            Vars = [
                {on_success, OnSuccess},
                {id, Id},
                {member_id, MemberId}
            ],
            z_render:dialog("Confirm removal of member", "_action_dialog_group_member_delete.tpl", Vars, Context);
        false ->
            z_render:growl_error("Only administrators or group leaders can remove members from groups.", Context)
    end.
