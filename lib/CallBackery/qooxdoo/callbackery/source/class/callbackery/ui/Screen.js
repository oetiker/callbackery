/* ************************************************************************
   Copyright: 2013 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */

/**
 * Abstract Visualization widget.
 */
qx.Class.define("callbackery.ui.Screen", {
    extend : qx.ui.container.Composite,
    /**
     * create a page for the View Tab with the given title
     *
     * @param vizWidget {Widget} visualization widget to embedd
     */
    construct : function(cfg,getParentFormData,extraAction) {
        /* using syntax trick to not get a warning for translating
           a variable */
        this.base(arguments,new qx.ui.layout.Grow());
        var that = this;
        var rpc = callbackery.data.Server.getInstance();
        this.addListenerOnce('appear',function(){
            rpc.callAsyncSmart(function(pluginConfig){
                var content;
                if (extraAction && pluginConfig.action){
                    pluginConfig.action.push(extraAction);
                }
                pluginConfig['name'] = cfg.name;
                switch (pluginConfig.type){
                    case 'form':
                        content = new callbackery.ui.plugin.Form(pluginConfig,getParentFormData);
                        break;
                    case 'table':
                        content = new callbackery.ui.plugin.Table(pluginConfig,getParentFormData);
                        break;
                    case 'html':
                        content = new callbackery.ui.plugin.Html(pluginConfig,getParentFormData);
                        break;
                    default:
                        that.debug('Invalid plugin type:"' + pluginConfig.type + '"');
                }
                content.addListener('actionResponse',function(e){
                    that.fireDataEvent('actionResponse',e.getData());
                });
                that.add(content);
            },'getPluginConfig',cfg.name);
        });
    },
    events: {
        actionResponse: 'qx.event.type.Data'
    }
});
