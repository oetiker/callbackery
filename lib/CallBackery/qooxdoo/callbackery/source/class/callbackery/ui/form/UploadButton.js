/**
 * An upload button using the FormData API.
 *
 * Adapted from the uploadwidget extension.
 */
qx.Class.define("callbackery.ui.form.UploadButton", {
  extend : qx.ui.form.Button,

  construct: function(label, icon, command) {
    this.base(arguments, label, icon, command);


    this.addListenerOnce('appear',function(){
        this.getContentElement().addAt(this.__inputEl,0);
    },this);

  },

  events: {
    changeFileName: 'qx.event.type.Data'
  },

  properties: {
  },

  members: {
   __inputEl: null,
    _createInput: function() {
      var control;
        // styling the input[type=file]
        // element is a bit tricky. Some browsers just ignore the normal
        // css style input. Firefox is especially tricky in this regard.
        // since we are providing our one look via the underlying qooxdoo
        // button anyway, all we have todo is position the ff upload
        // button over the button element. This is tricky in itself
        // as the ff upload button consists of a text and a button element
        // which are not css accessible themselfes. So the best we can do,
        // is align to the top right corner of the upload widget and set its
        // font so large that it will cover even realy large underlying buttons.
        var css = {
            position  : "absolute",
            cursor    : "pointer",
            hideFocus : "true",
            zIndex: this.getZIndex() + 11,
            opacity: 0,
            // align to the top right hand corner
            top: '0px',
            right: '0px',
            // ff ignores the width setting
            // pick a realy large font size to get
            // a huge button that covers
            // the area of the upload button
            fontSize: '400px'
        };
        if ( qx.core.Environment.get('browser.name') == 'ie' ) {
            css.height = '100%';
            css.width = '200%';
        }

        control =  this.__inputEl = new qx.html.Element('input',css, {
            type : 'file',
        });
        control.addListener("change", function(e){
            this.fireDataEvent('changeFileName', control.getDomElement().files[0]);
        },this);

       return control;
    },

    // Clear the input so we can upload the same file multiple times in a row.
    // Call this after the remote request is completed.
    clear: function() {
        let input = this.__inputEl.getDomElement();
        if (input) {
            input.value="";
        }
    }
  },
});
