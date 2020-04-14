/**
 * An upload button to use in a toolbar. Like a normal {@link uploadwidget.UploadButton}
 * but with a style matching the toolbar and without keyboard support.
 *
 * Stolen from the uploadwidget extension.
 *
 * After qx.ui.form.Button <> qx.ui.toolbar.Button
 */
qx.Class.define("callbackery.ui.form.UploadToolbarButton", {
  extend : uploadwidget.UploadButton,

  // --------------------------------------------------------------------------
  // [Constructor]
  // --------------------------------------------------------------------------

  /**
   * @param fieldName {String} upload field name
   * @param label {String} button label
   * @param icon {String} icon path
   * @param command {Command} command instance to connect with
   */

  construct: function(fieldName, label, icon, command)
  {
    this.base(arguments, fieldName, label, icon, command);

    // Toolbar buttons should not support the keyboard events
    this.removeListener("keydown", this._onKeyDown);
    this.removeListener("keyup", this._onKeyUp);
  },

  // --------------------------------------------------------------------------
  // [Properties]
  // --------------------------------------------------------------------------

   properties:
   {
    appearance :
    {
      refine : true,
      init : "toolbar-button"
    },

    show :
    {
      refine : true,
      init : "inherit"
    },

    focusable :
    {
      refine : true,
      init : false
    }
   },

  // --------------------------------------------------------------------------
  // [Members]
  // --------------------------------------------------------------------------

  members :
  {
    // overridden
    _applyVisibility : function(value, old) {
      this.base(arguments, value, old);
      // trigger a appearance recalculation of the parent
      var parent = this.getLayoutParent();
      if (parent && parent instanceof qx.ui.toolbar.PartContainer) {
        qx.ui.core.queue.Appearance.add(parent);
      }
    }
  }

});
