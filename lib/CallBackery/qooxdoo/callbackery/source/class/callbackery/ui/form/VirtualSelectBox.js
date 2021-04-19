/* ************************************************************************

   qooxdoo - the new era of web development

   http://qooxdoo.org

   Copyright:
     2011 1&1 Internet AG, Germany, http://www.1und1.de

   License:
     MIT: https://opensource.org/licenses/MIT
     See the LICENSE file in the project's top-level directory for details.

   Authors:
     * Christian Hagendorn (chris_schmidt)

************************************************************************ */

/**
 * This is a temporary CallBackery version of the Qooxdoo VirtualSelectbox
 * to be integrated into Qooxdoo as soon as it is battle tested.
 *
 */
qx.Class.define("callbackery.ui.form.VirtualSelectBox",
{
  extend : qx.ui.form.VirtualSelectBox,

  members :
  {
    _configureItemRich : function(item) {
      item.setRich(true);
      item.getChildControl('label').setWrap(false);
    },

    /**
     * Called when selection changes.
     *
     * @param event {qx.event.type.Data} {@link qx.data.Array} change event.
     */
    _updateSelectionValue : function(event) {
      if (!this.__filterUpdateRunning) {
        var d = event.getData();
        var old = (d.removed.length ? d.removed[0] : null);
        this.fireDataEvent("changeValue", d.added[0], old);
      }
    },

});
