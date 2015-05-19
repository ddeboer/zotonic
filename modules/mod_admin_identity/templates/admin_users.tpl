{% extends "admin_base.tpl" %}

{% block title %}{_ Users _}{% endblock %}

{% block search_target %}{% url admin_user %}{% endblock %}

{% block search_placeholder %}{_ Search users _}{% endblock %}

{% block content %}
    {% with m.acl.is_admin as is_users_editable %}

        
        <div class="admin-header">

            <h2>
                {_ Users _}{% if q.qs %},
                    {_ matching _} “{{ q.qs|escape }}”
                    {% button text=_"show all" class="btn btn-small btn-default" icon="glyphicon glyphicon-remove" action={redirect dispatch="admin_user"} %}
                {% else %} {_ overview _}{% endif %}
            </h2>

            <p>
                {_ Every page/person can be made into a user on the edit page.
                The difference between a user and a normal page is only
                that the former has logon credentials attached to its page record. _}
            </p>
            
            {% if is_users_editable %}
                <div class="well">
                    {% button class="btn btn-primary" text=_"Make a new user" action={dialog_user_add on_success={reload}} %}
            </div>
        {% else %}
            <div class="alert alert-info">{_ You need to be an administrator to add users. _}</div>
        {% endif %}
    </div>

    <div>
        {% with m.acl.user as me %}

            <form method="GET" action="{% url admin_users %}">
                <label style="font-weight: normal; margin: 0">
                    <input type="hidden" name="qs" value="{{ q.qs }}" />
                    <input type="checkbox" name="users_only" value="1" {% if q.users_only %}checked="checked"{% endif %}
                        onchange="this.form.submit()" />
                    {_ Show only users _}
                </label>
            </form>
            
            {% with m.search.paged[{users text=q.qs page=q.page users_only=q.users_only}] as result %}

                <table class="table table-striped do_adminLinkedTable">
                    <thead>
                        <tr>
                            <th width="20%">{_ Name _}</th>
                            <th width="15%">{_ Username _}</th>
                            <th width="10%">{_ Modified on _}</th>
                            <th width="40%">{_ Created on _}</th>
                        </tr>
                    </thead>

                    <tbody>
                        {% for id in result %}
                            <tr id="{{ #tr.id }}" data-href="javascript:;" {% if not id.is_published %}class="unpublished"{% endif %}>
                                <td>{{ m.rsc[id].title|striptags }}</td>
                                <td>
                                    {% if not m.identity[id].username %}
                                        &mdash;
                                    {% else %}
                                        {{ m.identity[id].username|escape }}{% if id == me %}  <strong>{_ (that's you) _}</strong>{% endif %}</td>
                                {% endif %}
                                <td>{{ m.rsc[id].modified|date:_"d M, H:i" }}</td>
                                <td>
                                    <div class="pull-right buttons">
                                        {% if is_users_editable %}
                                            {% button class="btn btn-default btn-xs" action={dialog_set_username_password id=id} text=_"set username / password" on_delete={slide_fade_out target=#tr.id} %}
                                        {% endif %}
                                        {% button class="btn btn-default btn-xs" text=_"edit" action={redirect dispatch="admin_edit_rsc" id=id} %}
                                    </div>
                                    {{ m.rsc[id].created|date:_"d M, H:i" }}
                                </td>
                            </tr>
                            {% wire id=" #"|append:#tr.id|append:" td" action={dialog_edit_basics id=id target=undefined} %}
                        {% empty %}
                            <tr>
                                <td colspan="4">
                                    {_ No users found. _}
                                </td>
                            </tr>
                        {% endfor %}
                    </tbody>
                </table>

                {% pager result=result dispatch="admin_user" qargs hide_single_page %}

            {% endwith %}
        {% endwith %}
    </div>

{% endwith %}
{% endblock %}
