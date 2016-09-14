%% @author Arjan Scherpenisse <arjan@scherpenisse.net>
%% @copyright 2011-2013 Arjan Scherpenisse <arjan@scherpenisse.net>
%% @doc Enables embedding media from their URL.

%% Copyright 2011-2013 Arjan Scherpenisse <arjan@scherpenisse.net>
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

-module(mod_oembed).
-author("Arjan Scherpenisse <arjan@scherpenisse.net>").

-mod_title("OEmbed support").
-mod_description("Add external media in your site by their URL.").
-mod_prio(600).

%% interface functions
-export([
    observe_rsc_update/3,
    observe_media_viewer/2,
    observe_media_stillimage/2,
    observe_media_import/2,
    event/2,

    preview_create/2
]).

-include_lib("zotonic.hrl").
-include_lib("include/oembed.hrl").

%% Fantasy mime type to distinguish embeddable html fragments.
-define(OEMBED_MIME, <<"text/html-oembed">>).

%% @doc Check if the update contains video embed information.  If so
%% then try to get the oembed information from the provider and update
%% the attached medium item.
-spec observe_rsc_update(#rsc_update{}, {boolean(), list()}, #context{}) -> {boolean(), list()}.
observe_rsc_update(#rsc_update{action=insert, id=Id}, {Changed, Props}, Context) ->
    case proplists:get_value(oembed_url, Props) of
        undefined -> 
            {Changed, Props};
        [] -> 
            {true, proplists:delete(oembed_url, Props)};
        <<>> -> 
            {true, proplists:delete(oembed_url, Props)};
        EmbedUrl ->
            case z_acl:is_allowed(insert, #acl_media{mime=?OEMBED_MIME}, Context) of
                true ->
                    MediaProps = [
                        {mime, ?OEMBED_MIME},
                        {oembed_url, EmbedUrl}
                    ],
                    case preview_create(Id, MediaProps, z_acl:sudo(Context)) of
                        undefined ->
                            {true, proplists:delete(oembed_url, Props)};
                        OEmbedTitle ->
                            Props1 = case z_utils:is_empty(z_trans:lookup_fallback(proplists:get_value(title, Props), Context)) of
                                        true ->  [{title, z_html:escape(OEmbedTitle)} | proplists:delete(title, Props)];
                                        false -> Props
                                     end,
                            {true, proplists:delete(oembed_url, Props1)}
                    end;
                false ->
                    {true, proplists:delete(oembed_url, Props)}
            end
    end;
observe_rsc_update(#rsc_update{action=update, id=Id, props=CurrProps}, {Changed, UpdateProps}, Context) ->
    case proplists:is_defined(oembed_url, UpdateProps) of
        true -> 
            OldMediaProps = m_media:get(Id, Context),
            {EmbedChanged, OEmbedTitle} = case proplists:get_value(oembed_url, UpdateProps) of
                Empty when Empty =:= undefined; Empty =:= <<>>; Empty =:= [] ->
                    % Delete the media record iff the media mime type is our mime type
                    case OldMediaProps of
                        undefined ->
                            {false, undefined};
                        _ ->
                            case proplists:get_value(mime, OldMediaProps) of
                                ?OEMBED_MIME -> 
                                    m_media:delete(Id, Context),
                                    {true, undefined};
                                _ -> 
                                    {false, undefined}
                            end
                    end;
                EmbedUrl ->
                    MediaProps = [
                        {mime, ?OEMBED_MIME},
                        {oembed_url, EmbedUrl}
                    ],
                    case OldMediaProps of
                        undefined ->
                            {true, preview_create(Id, MediaProps, Context)};
                        _ ->
                            case        z_utils:are_equal(proplists:get_value(mime, OldMediaProps), ?OEMBED_MIME)
                                andalso z_utils:are_equal(proplists:get_value(oembed_url, OldMediaProps), EmbedUrl)
                                andalso proplists:get_value(oembed, OldMediaProps) =/= undefined of
                                true ->
                                    %% Not changed
                                    {false, undefined};
                                false ->
                                    %% Changed, update the medium record
                                    {true, preview_create(Id, MediaProps, Context)}
                            end
                    end
            end,
            CurrTitle = proplists:get_value(title, UpdateProps, proplists:get_value(title, CurrProps)),
            UpdateProps1 = case EmbedChanged andalso z_utils:is_empty(z_trans:lookup_fallback(CurrTitle, Context)) of
                        true ->  [{title, z_html:escape_check(OEmbedTitle)} | proplists:delete(title, UpdateProps)];
                        false -> UpdateProps
                     end,
            {Changed or EmbedChanged, proplists:delete(oembed_url, UpdateProps1)};
        false ->
            {Changed, UpdateProps}
    end.


%% @doc Return the media viewer for the embedded video (that is, when
%% it is an embedded media). First tries the template called
%% <tt>_oembed_embeddable_(providername).tpl</tt>; if not found, falls back to
%% the HTML code that the oembed provider gave us; if none found,
%% falls back to the generic template <tt>_oembed_embeddable.tpl</tt>.
%% @spec observe_media_viewer(Notification, Context) -> undefined | {ok, Html}
observe_media_viewer(#media_viewer{id=Id, props=Props, filename=Filename, options=Options}, Context) ->
    case proplists:get_value(mime, Props) of
        ?OEMBED_MIME ->
            TplOpts = [
                {id, Id},
                {medium, Props},
                {options, Options},
                {filename, Filename},
                {is_ssl, is_ssl(Context)}
            ],
            Html = case proplists:lookup(oembed, Props) of
                       {oembed, OEmbed} ->
                           case proplists:lookup(provider_name, OEmbed) of
                               {provider_name, N} ->
                                   Tpl = iolist_to_binary(["_oembed_embeddable_",z_string:to_name(N),".tpl"]),
                                   case z_template:find_template(Tpl, Context) of
                                       {ok, _} ->
                                           z_template:render(Tpl, TplOpts, Context);
                                       {error, _} ->
                                           media_viewer_fallback(OEmbed, TplOpts, Context)
                                   end;
                               none ->
                                   media_viewer_fallback(OEmbed, TplOpts, Context)
                           end;
                       none ->
                           "<!-- No oembed code found -->"
                   end,
            {ok, Html};
        _ ->
            undefined
    end.

media_viewer_fallback(OEmbed, TplOpts, Context) ->
    case proplists:lookup(html, OEmbed) of
        {html, Html} ->
            case proplists:get_value(is_ssl, TplOpts) of
                true -> binary:replace(Html, <<"http://">>, <<"https://">>);
                false -> Html
            end;
        none ->
            z_template:render("_oembed_embeddable.tpl", TplOpts, Context)
    end.

%% @doc Map http:// urls to https:// if viewed on a secure connection
is_ssl(Context) ->
    case m_req:get(is_ssl, Context) of
        true -> true;
        false -> false;
        undefined -> z_convert:to_bool(z_context:get(is_ssl, Context)) 
    end.

% @doc Recognize youtube and vimeo URLs, generate the correct embed code
observe_media_import(#media_import{url=Url, metadata=MD}, Context) ->
    case oembed_request(Url, Context) of
        {ok, Json} ->
            Category = type_to_category(proplists:get_value(type, Json)),
            #media_import_props{
                prio = case Category of
                            website -> 11; % Prefer our own 'website' extraction
                            _ -> 5
                       end,
                category = Category,
                module = ?MODULE,
                description = ?__("Embedded Content", Context),
                rsc_props = [
                    {title, first([proplists:get_value(title, Json), z_url_metadata:p(title, MD)])},
                    {summary, first([proplists:get_value(description, Json), z_url_metadata:p(summary, MD)])},
                    {website, Url}
                ],
                medium_props = [
                    {mime, ?OEMBED_MIME},
                    {width, proplists:get_value(width, Json)},
                    {height, proplists:get_value(height, Json)},
                    {oembed_service, proplists:get_value(provider_name, Json)},
                    {oembed_url, Url},
                    {oembed, Json}
                ],
                preview_url = proplists:get_value(thumbnail_url, Json)
            };
        {error, _} ->
            undefined
    end.

first([]) -> undefined;
first([undefined|Xs]) -> first(Xs);
first([""|Xs]) -> first(Xs);
first([<<>>|Xs]) -> first(Xs);
first([X|_]) -> X.


%% @doc Return the filename of a still image to be used for image tags.
%% @spec observe_media_stillimage(Notification, _Context) -> undefined | {ok, Filename}
observe_media_stillimage(#media_stillimage{props=Props}, _Context) ->
    case proplists:get_value(mime, Props) of
        ?OEMBED_MIME ->
            case z_convert:to_list(proplists:get_value(preview_filename, Props)) of
                [] -> {ok, "lib/images/embed.jpg"};
                PreviewFile -> {ok, PreviewFile}
            end;
        _ ->
            undefined
    end.


%% @doc Handle the form submit from the "new media" dialog.  The form is defined in templates/_media_upload_panel.tpl.
%% @spec event(Event, Context1) -> Context2
event(#submit{message={add_video_embed, EventProps}}, Context) ->
    Actions = proplists:get_value(actions, EventProps, []),
    Id = proplists:get_value(id, EventProps),
    Callback = proplists:get_value(callback, EventProps),
    Stay = z_convert:to_bool(proplists:get_value(stay, EventProps, false)),
    EmbedUrl = z_context:get_q_validated("oembed_url", Context),

    case Id of
        %% Create a new page
        undefined ->
            SubjectId = proplists:get_value(subject_id, EventProps),
            Predicate = proplists:get_value(predicate, EventProps, depiction),
            Title   = z_context:get_q_validated("title", Context),
            Summary = z_context:get_q("summary", Context),
            Props = [
                {title, Title},
                {summary, Summary},
                {is_published, true},
                {category, media},
                {mime, ?OEMBED_MIME},
                {oembed_url, EmbedUrl}
            ],

            case m_rsc:insert(Props, Context) of
                {ok, MediaId} ->
                    spawn(fun() -> preview_create(MediaId, Props, Context) end),
                    
                    {_, ContextLink} = mod_admin:do_link(z_convert:to_integer(SubjectId), Predicate, 
                                                         MediaId, Callback, Context),

                    ContextRedirect = case SubjectId of
                        undefined ->
                            case Stay of
                                false -> z_render:wire({redirect, [{dispatch, "admin_edit_rsc"}, {id, MediaId}]}, ContextLink);
                                true -> ContextLink
                            end;
                        _ -> ContextLink
                    end,
                    z_render:wire([
                                {dialog_close, []}, 
                                {growl, [{text, ?__("Made the media page.", ContextRedirect)}]} 
                                | Actions], ContextRedirect);
                {error, _} = Error ->
                    lager:eror("[mod_oembed] Error in add_video_embed: ~p on ~p", [Error, Props]),
                    z_render:growl_error(?__("Could not create the media page.", Context), Context)
            end;

        %% Update the current page
        N when is_integer(N) ->
            Props = [
                {oembed_url, EmbedUrl}
            ],
            case m_rsc:update(Id, Props, Context) of
                {ok, _} ->
                    z_render:wire([{dialog_close, []} | Actions], Context);
                {error, _} ->
                    z_render:growl_error(?__("Could not update the page with the new embed code.", Context), Context)
            end
    end;

%% @doc When entering the embed URL for a new media item, we trigger the detecting early to guess title/description.
event(#postback_notify{message="do_oembed"}, Context) ->
    case z_string:trim(z_context:get_q("url", Context)) of
        "" -> 
            z_context:add_script_page([
                    "$('#oembed-title').val('""').attr('disabled',true);",
                    "$('#oembed-summary').val('""').attr('disabled',true);",
                    "$('#oembed-save').addClass('disabled');",
                    "$('#oembed-image').closest('.control-group').hide();"
                    ], Context),
            Context;
        Url ->
            case oembed_request(Url, Context) of
                {error, _} ->
                    z_context:add_script_page([
                            "$('#oembed-title').val('""').attr('disabled',true);",
                            "$('#oembed-summary').val('""').attr('disabled',true);",
                            "$('#oembed-save').addClass('disabled');",
                            "$('#oembed-image').closest('.control-group').hide();"
                            ], Context),
                    z_render:growl_error(?__("Invalid or unsupported media URL. The item might have been deleted or is not public.", Context), Context);
                {ok, Json} ->
                    Title = z_html:unescape(proplists:get_value(title, Json, [])),
                    Descr = z_html:unescape(proplists:get_value(description, Json, [])),
                    z_context:add_script_page([
                        "$('#oembed-title').val('", z_utils:js_escape(Title), "').removeAttr('disabled');",
                        "$('#oembed-summary').val('", z_utils:js_escape(Descr), "').removeAttr('disabled');",
                        "$('#oembed-save').removeAttr('disabled').removeClass('disabled');"
                        ], Context),
                    case preview_url_from_json(proplists:get_value(type, Json), Json) of
                        undefined -> 
                            z_context:add_script_page(["$('#oembed-image').closest('.control-group').hide();"], Context);
                        PreviewUrl -> 
                            z_context:add_script_page(["$('#oembed-image').attr('src', '", z_utils:js_escape(PreviewUrl), "').closest('.control-group').show();"], Context)
                    end,
                    z_render:growl(?__("Detected media item", Context), Context)
            end
    end;

event(#postback{message=fix_missing}, Context) ->
    case oembed_admin:count_missing(Context) of
        0 ->
            z_render:growl(?__("No embedded videos found which need fixing.", Context), Context);
        N ->
            spawn(fun() -> oembed_admin:count_missing(Context) end),
            Msg = ?__("Attempting to fix ~p videos.", Context),
            z_render:growl(lists:flatten(io_lib:format(Msg, [N])), Context)
    end.


%% @doc (Re)create a preview from the stored oembed information
preview_create(Id, Context) ->
    case z_acl:rsc_editable(Id, Context) of
        true ->
            case m_media:get(Id, Context) of
                Ms when is_list(Ms) ->
                    case proplists:get_value(oembed, Ms) of
                        Json when is_list(Json) ->
                            preview_create_from_json(Id, Json, Context);
                        undefined ->
                            {error, notoembed}
                    end;
                undefined ->
                    {error, notfound}
            end;
        false ->
            {error, eacces}
    end.

%%====================================================================
%% support functions
%%====================================================================

%% Fetch or create a preview for the movie. Returns the media title
%% that need to be set on the rsc if the rsc has no title.
preview_create(MediaId, MediaProps, Context) ->
    case z_convert:to_list(proplists:get_value(oembed_url, MediaProps)) of
        [] -> 
            undefined;
        Url -> 
            case oembed_request(Url, Context) of
                {ok, Json} ->
                    case proplists:get_value(type, Json) of
                        <<"link">> -> 
                            undefined;
                        _Type ->
                            %% store found properties in the media part of the rsc
                            ok = m_media:replace(MediaId, [{oembed, Json} | MediaProps], Context),
                            _ = preview_create_from_json(MediaId, Json, Context),
                            proplists:get_value(title, Json)
                    end;
                {error, {http, Code, Body}} ->
                    Err = [{error, http_error}, {code, Code}, {body, Body}],
                    ok = m_media:replace(MediaId, [{oembed, Err} | MediaProps], Context),
                    undefined;
                {error, _} ->
                    undefined
            end
    end.


preview_create_from_json(MediaId, Json, Context) ->
    Type = proplists:get_value(type, Json),
    case preview_url_from_json(Type, Json) of
        undefined -> 
            nop;
        ThumbUrl ->
            case thumbnail_request(ThumbUrl, Context) of
                {ok, {CT, ImageData}} ->
                    {ok, _} = m_media:save_preview(MediaId, ImageData, CT, Context),
                    %% move to correct category if rsc is a 'media'
                    case m_rsc:is_a(MediaId, media, Context) of
                        true -> m_rsc:update(MediaId, [{category, type_to_category(Type)}], Context);
                        false -> m_rsc:touch(MediaId, Context)
                    end;
                {error, _} ->
                    nop
            end
    end.

%% @doc Perform OEmbed discovery on a given URL.
%% @spec oembed_request(string(), #context{}) -> [{Key, Value}]
oembed_request(Url, Context) ->
    F = fun() ->
            oembed_client:discover(Url, Context)
        end,
    case z_depcache:memo(F, {oembed, Url}, 3600, Context) of
        {ok, Json} ->
            sanitize_json(Json, Context);
        {error, _} = Error ->
            Error
    end.


sanitize_json(Json, Context) ->
    sanitize_json(Json, [], Context).

sanitize_json([], Acc, _Context) ->
    {ok, lists:reverse(Acc)};
sanitize_json([{html,<<>>}|Rest], Acc, Context) ->
    sanitize_json(Rest, Acc, Context);
sanitize_json([{html,Html}|Rest], Acc, Context) when Html =/= <<>> ->
    case z_sanitize:html(Html,Context) of
        <<>> -> {error, illegal_html};
        Html1 -> sanitize_json(Rest, [{html,Html1}|Acc], Context)
    end;
sanitize_json([{body,Body}|Rest], Acc, Context) ->
    Body1 = z_sanitize:html(Body,Context),
    sanitize_json(Rest, [{body,Body1}|Acc], Context);
sanitize_json([{UrlTag,Url}|Rest], Acc, Context) when UrlTag =:= url; UrlTag =:= provider_url; UrlTag =:= author_url ->
    Url1 = z_sanitize:uri(Url),
    sanitize_json(Rest, [{UrlTag,Url1}|Acc], Context);
sanitize_json([{Tag,B}|Rest], Acc, Context) when is_binary(B) ->
    B1 = z_html:escape_check(B),
    sanitize_json(Rest, [{Tag,B1}|Acc], Context);
sanitize_json([{Tag,N}|Rest], Acc, Context) when is_integer(N) ->
    sanitize_json(Rest, [{Tag,N}|Acc], Context);
sanitize_json([_|Rest], Acc, Context) ->
    sanitize_json(Rest, Acc, Context).


%% @doc Given a thumbnail URL, download it and return the content type plus image data pair.
thumbnail_request(ThumbUrl, _Context) ->
    case httpc:request(get, {z_convert:to_list(ThumbUrl), []}, [], []) of
        {ok, {{_, 200, _}, Headers, ImageData}} ->
            CT = case proplists:lookup("content-type", Headers) of
                     {"content-type", C} -> C;
                     _ -> "image/jpeg"
                 end,
            {ok, {CT, ImageData}};
        {ok, {{_, 404, _}, _Headers, _ImageData}} ->
            lager:info("mod_oembed: 404 on thumbnail url ~p", [ThumbUrl]),
            {error, notfound};
        Other ->
            lager:warning("mod_oembed: unexpected result for ~p: ~p", [ThumbUrl, Other]),
            {error, httpc}
    end.


%% @doc Get the preview URL from JSON structure. Either the thumbnail
%% URL for non-photo elements, or the full URL for photo elements.
preview_url_from_json(<<"photo">>, Json) ->
    case proplists:get_value(url, Json) of
        None when None =:= undefined; None =:= null ->
            case proplists:get_value(thumbnail_url, Json) of
                null -> undefined;
                Url -> Url
            end;
        Url ->
            Url
    end;
preview_url_from_json(_Type, Json) ->
    case proplists:get_value(thumbnail_url, Json) of
        null -> undefined;
        Url -> Url
    end.


type_to_category(<<"photo">>) -> image;
type_to_category(<<"video">>) -> video;
type_to_category(<<"link">>) -> website;
type_to_category(_rich) -> document.
