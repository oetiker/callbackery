/* ************************************************************************

   After Qooxdoo FileSelectorMenuButton
   Copyright:
     2023 Oetiker+Partner AG

   License:
     LGPL: http://www.gnu.org/licenses/lgpl.html
     See the LICENSE file in the project's top-level directory for details.

   Authors:
     * Tobias Oetiker
 
************************************************************************ */

qx.Class.define("callbackery.ui.form.FileSelectorMenuButton", {
    extend: qx.ui.menu.Button,
    
    properties: {
        accept: qx.ui.form.FileSelectorButton.$$properties.accept,
        capture: qx.ui.form.FileSelectorButton.$$properties.capture,
        multiple: qx.ui.form.FileSelectorButton.$$properties.multiple,
        directoriesOnly: qx.ui.form.FileSelectorButton.$$properties.directoriesOnly,
    },
    members: {
        __inputObjec: null,
        _applyAttributes: qx.ui.form.FileSelectorButton.prototype._applyAttributes,
        setEnabled: qx.ui.form.FileSelectorButton.prototype.setEnabled,
        _createContentElement: qx.ui.form.FileSelectorButton.prototype._createContentElement,
    }
});
