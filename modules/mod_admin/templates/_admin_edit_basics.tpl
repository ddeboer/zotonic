{% extends "admin_edit_widget_i18n.tpl" %}

{% block widget_title %}{_ Basic _}{% endblock %}
{% block widget_i18n_tab_class %}item{% endblock %}

{% block widget_content %}
{% with m.rsc[id] as r %}
<fieldset class="admin-form">
	<div class="form-item clearfix">
		<label for="field-title{{ lang_code_with_dollar }}">{_ Title _} {{ lang_code_with_brackets }}</label>
		<input type="text" id="field-title{{ lang_code_with_dollar }}" name="title{{ lang_code_with_dollar }}" 
			value="{{ is_i18n|if : r.translation[lang_code].title : r.title }}"
			{% if not is_editable %}disabled="disabled"{% endif %}/>
	</div>

	<div class="form-item clearfix">
		<label for="field-summary{{ lang_code_with_dollar }}">{_ Summary _} {{ lang_code_with_brackets }}</label>
		<textarea rows="2" cols="10" id="field-summary{{ lang_code_with_dollar }}" 
			name="summary{{ lang_code_with_dollar }}" class="intro"
			{% if not is_editable %}disabled="disabled"{% endif %}
			>{{ is_i18n|if : r.translation[lang_code].summary : r.summary }}</textarea>
	</div>

	<div class="form-item clearfix">
		<label for="field-short-title{{ lang_code_with_dollar }}">{_ Short title _} {{ lang_code_with_brackets }}</label>
		<input type="text" id="field-short-title{{ lang_code_with_dollar }}" name="short_title{{ lang_code_with_dollar }}" 
			value="{{ is_i18n|if : r.translation[lang_code].short_title : r.short_title }}"
			{% if not is_editable %}disabled="disabled"{% endif %} />
	</div>
</fieldset>
{% endwith %}
{% endblock %}
