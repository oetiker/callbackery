/* ************************************************************************
   Copyright: 2013 OETIKER+PARTNER AG
   License:   GPLv3 or later
   Authors:   Tobi Oetiker <tobi@oetiker.ch>
   Utf8Check: äöü
************************************************************************ */

/**
 * Abstract Visualization widget.
 */
qx.Class.define("callbackery.ui.plugin.Table", {
    extend : callbackery.ui.plugin.Form,
    /**
     * create a page for the View Tab with the given title
     *
     * @param vizWidget {Widget} visualization widget to embedd
     */
    properties: {
        selection: {
            init: {}
        }
    },
    members: {
        _populate: function(){
            this.setLayout(new qx.ui.layout.VBox(0));
            this._addToolbar();
            this._addTable();
        },
        _addToolbar: function(){
            var that = this;
            var cfg = this._cfg;
            var toolbar = new qx.ui.toolbar.ToolBar();
            this.add(toolbar);
            var action = this._action = new callbackery.ui.plugin.Action(
                cfg,qx.ui.toolbar.Button,
                new qx.ui.layout.HBox(0),
                function(){
                    if (that._form.validate()){
                        var rpcData = that._form.getData();
                        rpcData['selection'] = that.getSelection();
                        return rpcData;
                    }
                    else {
                        return false;
                    }
                }
            );
            action.set({
                paddingLeft: -10
            });
            toolbar.add(action);
            toolbar.addSpacer();
            var form = this._form = new callbackery.ui.form.Auto(cfg.form,null,callbackery.ui.form.renderer.HBox);
            toolbar.add(form);

        },
        _addTable: function(){
            var cfg = this._cfg;
            var model = this._model = new callbackery.data.RemoteTableModel(cfg,this._getParentFormData);
            var table = this._table = new qx.ui.table.Table(model,{
                tableColumnModel : function(obj) {
                    return new qx.ui.table.columnmodel.Resize(obj);
                }
            }).set({
                showCellFocusIndicator: false
            });
            var resizeBehavior = table.getTableColumnModel().getBehavior();
            cfg.table.forEach(function(row,i){
                if (row.width != null){
                    resizeBehavior.setWidth(i, String(row.width));
                }
            });
            var selectionModel = table.getSelectionModel();
            selectionModel.setSelectionMode(qx.ui.table.selection.Model.SINGLE_SELECTION);
            selectionModel.addListener('changeSelection',function(){
                selectionModel.iterateSelection(function(index) {
                    this.setSelection(model.getRowData(index));
                },this);
            },this);
            this._form.addListener('changeData',function(e){
                selectionModel.resetSelection();
                model.setFormData(e.getData());
                model.reloadData();
            });
            this._action.addListener('popupClosed',function(e){
                model.reloadData();
            });
            this.addListener('appear',function(e){
                model.reloadData();
            });
            this._action.addListener('actionResponse',function(e){
                var data = e.getData();
                switch (data.action){
                    case 'reload':
                        model.reloadData();
                        break;
                }
            });
            this.add(table,{flex: 1});

        },
        _loadData: function(){
            // this.setEnabled(false);
            var that = this;
            var rpc = callbackery.data.Server.getInstance();
            if (this._loading){
                return;
            }
            var form = this._form;
            var model = this._model;
            this._loading = true;
            var parentFormData = {};
            if (this._getParentFormData){
                parentFormData = this._getParentFormData();
            }
            rpc.callAsyncSmart(function(data){
                form.setData(data,true);
                model.setFormData(form.getData());
                // model.clearCache();
                model.reloadData();
                that._loading = false;
                // that.setEnabled(true);
            },'getPluginData',this._cfg.name,'allFields',parentFormData);
        }
    }

});
