{% extends "admin_base.tpl" %}

{% block title %} Development {% endblock %}

{% block content %}
<div class="edit-header">
    <h2>{_ Site Development _}</h2>
    
    <p>{_ Tools and settings that are useful for site development. _}</p>

    <h3>{_ Settings _}</h3>
    <div class="well">

        <div>
            {% wire id="tpldbg" 
                action={config_toggle module="mod_development" key="debug_includes"}
                action={admin_tasks task='flush'} 
            %}
            <label class="checkbox inline">
                <input type="checkbox" id="tpldbg" value="1" {% if m.config.mod_development.debug_includes.value %}checked="checked"{% endif %} />
                {_ Show paths to included template files in generated templates _}
            </label>
        </div>

        <div>
            {% wire id="blkdbg" 
                action={config_toggle module="mod_development" key="debug_blocks"}
                action={admin_tasks task='flush'} 
            %}
            <label class="checkbox inline">
                <input type="checkbox" id="blkdbg" value="1" {% if m.config.mod_development.debug_blocks.value %}checked="checked"{% endif %} />
                {_ Show defined blocks in generated templates _}
            </label>
        </div>
        
        <div>
            {% wire id="libsep" 
                action={config_toggle module="mod_development" key="libsep"}
                action={admin_tasks task='flush'} 
            %}
            <label class="checkbox inline">
                <input type="checkbox" id="libsep" value="1" {% if m.config.mod_development.libsep.value %}checked="checked"{% endif %} />
                {_ Download css and javascript files as separate files (ie. don’t combine them in one url). _}
            </label>
        </div>

        <div>
            {% wire id="devapi" 
                action={config_toggle module="mod_development" key="enable_api"}
            %}
            <label class="checkbox inline">
                <input type="checkbox" id="devapi" value="1" {% if m.config.mod_development.enable_api.value %}checked="checked"{% endif %} />
                {_ Enable API to recompile &amp; build Zotonic _}
            </label>
        </div>
    </div>

    <h3>{_ Template debugging _}</h2>
    <div class="well">
        <p><a href="{% url admin_development_templates %}">Show which files are included in a template compilation</a></p>
        <p class="help-block">At times it can be confusing which templates are actually used during a template compilation.  Here you can see which files are included whilst compiling a template.</p>
    </div>

    
    <h3>{_ Dispatch rule debugging _}</h3>
    <div class="well">

        <p>{_ Match a request url, display matched dispatch rule. _}</p>

        {% wire id="explain-dispatch" type="submit"
                postback=`explain_dispatch`
                delegate=`z_development_dispatch`
        %}
        <form id="explain-dispatch" class="form-inline" action="postback">
            <select id="explain_protocol" name="explain_protocol" class="input-small">
                <option>http</option>
                <option>https</option>
            </select>
            <input type="text" id="explain_req" name="explain_req" placeholder="/foo/bar" value="" />
            <button class="btn" type="submit">{_ Explain _}</button>
        </form>

        <div id="explain-dispatch-output" style="display:none"></div>
    </div>
</div>
{% endblock %}
