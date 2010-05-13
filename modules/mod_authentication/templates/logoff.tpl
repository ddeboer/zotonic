{% extends "base.tpl" %}

{% block title %}Log off ...{% endblock %}

{% block html_head_extra %}
	<meta http-equiv="refresh" content="6;url=/" />
{% endblock %}

{% block content_area %}
	<h1>One moment please, logging off…</h1>
	
	<p>You will be redirected to the home page.</p>
	
	{% all include "_logoff_extra.tpl" %}
{% endblock %}
