<form class="form">
    <h3>{{ id.title }}</h3>
    <textarea style="width:100%;" rows="20">{% for row in all %}{% if row.name_first or row.name_surname_prefix or row.name_surname%}{% if row.name_first %}{{ row.name_first }} {% endif %}{% if row.name_surname_prefix %}{{ row.name_surname_prefix }} {% endif %}{% if row.name_surname %}{{ row.name_surname }} {% endif %}<{{ row.email }}>{% else %}{{ row.email }}{% endif %}{% if not forloop.last %}, {% endif %}{% endfor %}</textarea>
</form>

<div class="modal-footer">
    {% button text=_"Close" action={dialog_close} %}
</div>
