<div class="control-group survey-truefalse">
    <label class="control-label">{{ blk.prompt }}</label>
    <div class="controls">
        <label class="radio inline">
            <input type="radio" id="{{ #yes }}" name="{{ blk.name}}" {% if answers[blk.name] %}checked="checked"{% endif %}/> {{ blk.yes|default:_"True" }}
        </label>
        <label class="radio inline">
            <input type="radio" id="{{ #no }}" name="{{ blk.name}}" {% if answers and not answers[blk.name] %}checked="checked"{% endif %}/> {{ blk.yes|default:_"False" }}
        </label>
    </div>
</div>
{% if blk.is_required %}
    {% validate id=#yes name=blk.name type={presence} %}
{% endif %}
