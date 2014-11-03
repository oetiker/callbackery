/* ************************************************************************
   Copyright: 2011 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */
/**
 * Build the desktop. This is a singleton. So that the desktop
 * object and with it the treeView and the searchView are universaly accessible
 */
qx.Class.define("callbackery.ui.Footer", {
    extend : qx.ui.container.Composite,
    type : 'singleton',

    construct : function() {
        this.base(arguments,new qx.ui.layout.HBox().set({
            alignX: 'right'
        }));
        var cfg = callbackery.data.Config.getInstance().getBaseConfig();
        var label;
        if (cfg.hide_op != 'yes'){
            label = new qx.ui.basic.Atom(this.tr('Created by OETIKER+PARTNER AG, %1, %2','#VERSION#','#DATE#')).set({
                textColor: '#bbb',
                cursor        : 'pointer',
                paddingRight  : 5,
                paddingBottom : 3,
                rich          : true,
                font          : 'small'
            });
            label.addListener('pointerover',function(){ label.set({textColor: '#000'}) });
            label.addListener('pointerout',function(){ label.set({textColor: '#bbb'}) });
            label.addListener('tap',function(){ 
                qx.bom.Window.open('http://www.oetiker.ch', '_blank');
            });
        }
        else {
            label = new qx.ui.basic.Atom('Release #VERSION#, #DATE#').set({
                textColor: '#bbb',
                paddingRight  : 5,
                paddingBottom : 3,
                rich          : true,
                font          : 'small'
            });
        }
        this.add(label);
    }
});
