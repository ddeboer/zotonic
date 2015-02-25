{% if in_sorter == 'category' %}
	{# Category - items can only appear once, strict handling #}
    {% wire name="admin-menu-select" 
            action={
                dialog_open 
                template="_action_dialog_connect.tpl" 
                title=_"Add category"
                callback="window.zMenuEditDone"
                cat=cat_id
                in_sorter=in_sorter
                tabs_enabled=["new"]
            }
    %}
{% elseif is_hierarchy %}
	{# Hierarchy - items can only appear once #}
    {% wire name="admin-menu-select" 
            action={
                dialog_open 
                template="_action_dialog_connect.tpl" 
                title=_"Add item"
                callback="window.zMenuEditDone"
                cat=cat_id
                in_sorter=in_sorter
            }
    %}
{% else %}
	{# Menu - items can appear multiple times #}
    {% wire name="admin-menu-select" 
            action={
                dialog_open 
                template="_action_dialog_connect.tpl" 
                title=_"Add menu item"
                callback="window.zMenuEditDone"
                cat=cat_id
                in_sorter=in_sorter
            }
    %}
{% endif %}

{% if admin_menu_edit_action /= `none` %}
	{% wire
	    name="admin-menu-edit" 
        action=admin_menu_edit_action|default:{
            dialog_edit_basics
            callback="window.zMenuEditDone"
        } 
	%}
{% endif %}

{% javascript %}

$('#{{ menu_id }}').on('click', '.menu-edit', function(e) {
	var id = $(this).closest('div').data('page-id');
	window.zMenuEditDone = function(id, title) {
		$(".title-"+id).html(title);
	};
	z_event("admin-menu-edit", { id: id, tree_id: {{ tree_id|default:"undefined" }} });
	e.preventDefault();
});

$('#{{ menu_id }}').on('click', '.dropdown-menu a', function(e) {
	var $a = $(e.currentTarget);
	var where = $a.data('where');
	var $menu_item = $a.closest('li.menu-item');
	var $sorter = $('#{{ in_sorter }}');
	var $menuedit = $a.closest(".do_menuedit");

	if ($menuedit.length === 0) {
		$menuedit = $(".do_menuedit", $a.closest("div"));
	}
	if ($menuedit.length === 0) {
		$menuedit = $(".do_menuedit", $a.closest(".widget"));
	}

	if (where == 'remove') {
		z_notify("menu-item-delete", {
				id: $menu_item.children('div').data('page-id')
			});
		$(this).closest('li.menu-item').fadeOut(500, function() { 
			$(this).remove();
			$sorter.trigger('sortupdate')
		});
	} else if (where == 'copy') {
		z_notify("menu-item-copy", {
				id: $menu_item.children('div').data('page-id'),
				item_template: $menuedit.menuedit('option').item_template
			});
	} else {
		window.zMenuEditDone = function(v) {
			window.zMenuNewItem = function(rsc_id, html) {
				if (where == 'top') {
					$sorter.prepend(html);
				} else if (where == 'bottom') {
					$sorter.append(html);
				} else if (where == 'before') {
					$(html).insertBefore($menu_item);
				} else if (where == 'below') {
					$submenu = $("ul.menu-submenu", $menu_item);
					if ($submenu.length > 0) {
						$submenu.append(html);
					} else {
						$menu_item.append("<ul class='.menu-submenu'>"+html+"</ul>");
					}
				} else if (where == 'after') {
					$(html).insertAfter($menu_item);
				}
				$sorter.trigger('sortupdate');
				if (typeof pubzub !== "undefined") {
					pubzub.publish("~pagesession/menu/insert", {id: rsc_id});
				}
			};

			{% if is_hierarchy %}
				var $duplicate = $sorter.find('[data-page-id='+v.object_id+']');
				if ($duplicate.length > 0) {
					z_dialog_alert({text: "{_ This item is already in the hierarcgy. Every item can only occur once. _}"});
					$duplicate.fadeTo(500, 0.5, function() { $duplicate.fadeTo(500, 1); });
					return;
				}
			{% endif %}

			z_notify("menu-item-render", {
					id: v.object_id, 
					callback: "window.zMenuNewItem", 
					z_delegate:"mod_menu",
					item_template: $menuedit.menuedit('option').item_template
				});
		};
		z_event("admin-menu-select", {tab: "{{ connect_tab|default:"find" }}"});
	}
	e.preventDefault();
});

window.zMenuInsertAfter = function(after_id, html) {
	var $menu_item = $('#{{ menu_id }} div[data-page-id='+after_id+']').closest('li.menu-item');
	$html = $(html);
	$html.insertAfter($menu_item);
	$('#{{ in_sorter }}').trigger('sortupdate');
	if (typeof pubzub !== "undefined") {
		pubzub.publish("~pagesession/menu/insert", {menu_id: '{{ menu_id }}', id: $html.children('div').data('page-id')});
	}
}

{% endjavascript %}
