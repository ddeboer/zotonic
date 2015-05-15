{% if identities %}
	<table id="{{ #listemail }}" class="table">
	{% for idn in identities %}
	{% with idn.id as idn_id %}
		<tr>
			<td>
			<label class="radio">
				<input type="radio" name="{{ #verified}}" {% if id.email == idn.key %}checked{% endif %} class="radio nosubmit" value="{{ idn.key }}" />
				{{ idn.key }}
			</label>
			</td>
			<td>
				{% if idn.is_verified %}
					<span class="icon-ok" title="{_ Verified _}"></span> {_ Verfied _}
				{% else %}
					<a id="{{ #verify.idn_id }}"  href="#" class="btn btn-small" title="{_ Send verification e-mail _}">{_ Verify _}</a>		
					{% wire id=#verify.idn_id 
							postback={identity_verify_confirm id=id idn_id=idn_id list_element=#listemail}
							delegate=`mod_admin_identity`
					%}
				{% endif %}
			</td>
			<td>
				<a id="{{ #del.idn_id }}" href="#" class="btn btn-small" title="{_ Delete this e-mail address _}">{_ Delete _}</a>
				{% wire id=#del.idn_id 
						postback={identity_delete_confirm id=id idn_id=idn_id list_element=#listemail}
						delegate=`mod_admin_identity`
				%}
			</td>
			{% if m.modules.active.mod_email_status %}
			<td>
				<a id="{{ #status.idn_id }}" href="#" class="btn btn-small" title="{_ View email status _}">{_ Status _}</a>
				{% wire id=#status.idn_id action={dialog_open title=_"Email Status" template="_dialog_email_status.tpl" email=idn.key} %}
			</td>
			{% endif %}
		</tr>
	{% endwith %}
	{% endfor %}
	</table>
{% else %}
<p class="help-block">{_ No verified e-mail addresses. Please add one below. _}</p>
{% endif %}

{% wire name="verify-preferred-email"
		postback={identity_verify_preferred type='email' id=id} 
		delegate=`mod_admin_identity` 
%}
{% javascript %}
	$('#{{ #listemail }}').on('click', 'input.radio', function() {
		z_event('verify-preferred-email', {key: $(this).val()});
	});

	if (!$('#{{ #listemail }} input.radio:checked').length) {
		$('#{{ #listemail }} input.radio:first').click();
	}
{% endjavascript %}
