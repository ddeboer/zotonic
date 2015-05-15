
<div class="well">

    {% button text=_"Publish"
        class="btn btn-primary pull-right"
        action={confirm
            text=_"Are you sure you want to make all rules permanent?"
            action={dialog_close}
            delegate=`admin_acl_rules`
            postback={publish kind=kind}
        }
    %}

    {% button text=_"Try rules..."
        class="btn"
        action={dialog_open
            title=_"Try ACL rules"
            template="_dialog_acl_rules_try.tpl"
        }
    %}

    {% button text=_"Revert back to published"
        class="btn"
        action={confirm
            text=_"Are you sure you want to restore all ACL rules to their currently published version?"
            action={dialog_close}
            delegate=`admin_acl_rules`
            postback={revert kind=kind}
        }
    %}
    
</div>
