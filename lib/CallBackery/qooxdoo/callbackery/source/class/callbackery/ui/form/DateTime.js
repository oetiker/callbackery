/* ************************************************************************

   After Qooxdoo DateField widget
   Copyright:
     2015 Oetiker+Partner AG

   License:
     LGPL: http://www.gnu.org/licenses/lgpl.html
     EPL: http://www.eclipse.org/org/documents/epl-v10.php
     See the LICENSE file in the project's top-level directory for details.

   Authors:
     * Martin Wittemann (martinwittemann)
     * Fritz Zaucker

************************************************************************ */

// FIX ME: should be derived from Qooxdoo DateField.

/**
 * A *date field* is like a combo box with the date as popup. As button to
 * open the calendar a calendar icon is shown at the right to the datefield.
 *
 * In addition a time textfield.
 *
 * To be conform with all form widgets, the {@link qx.ui.form.IForm} interface
 * is implemented.
 *
 * The following example creates a date field and sets the current
 * date as selected.
 *
 * <pre class='javascript'>
 * var dateTimeField = new callbackery.ui.form.DateTime();
 * this.getRoot().add(dateTimeField, {top: 20, left: 20});
 * dateField.setValue(new Date());
 * </pre>
 *
 * @childControl list {qx.ui.control.DateChooser} date chooser component
 * @childControl popup {qx.ui.popup.Popup} popup which shows the list control
 * @childControl datefield {qx.ui.form.TextField} text field for manual date entry
 * @childControl timefield {qx.ui.form.TextField} text field for manual date entry
 * @childControl button {qx.ui.form.Button} button that opens the list control
 */
qx.Class.define("callbackery.ui.form.DateTime",
{
  extend : qx.ui.core.Widget,
  include : [
    qx.ui.core.MRemoteChildrenHandling,
    qx.ui.form.MForm
  ],
  implement : [
    qx.ui.form.IForm,
    qx.ui.form.IDateForm
  ],


  /*
  *****************************************************************************
     CONSTRUCTOR
  *****************************************************************************
  */

  construct : function()
  {
    this.base(arguments);

    // set the layout
    var layout = new qx.ui.layout.HBox();
    this._setLayout(layout);
    layout.setAlignY("middle");
    this.setMaxWidth(220);
    // datefield and button
    var dateField = this._createChildControl("datefield");
    this._createChildControl("button");

    // timefield
    var timeField = this._createChildControl("timefield");

    // register listeners
    this.addListener("tap", this._onTap, this);
    this.addListener("blur", this._onBlur, this);

    // forward the focusin and focusout events to the textfield. The textfield
    // is not focusable so the events need to be forwarded manually.
    this.addListener("focusin", function(e) {
//      dateField.fireNonBubblingEvent("focusin", qx.event.type.Focus);
//      dateField.setTextSelection(0,0);
    }, this);

    this.addListener("focusout", function(e) {
      dateField.fireNonBubblingEvent("focusout", qx.event.type.Focus);
    }, this);

    // initializes the DateField with the default format
    this._setDefaultDateFormat();

    // adds a locale change listener
    this._addLocaleChangeListener();
  },




  /*
  *****************************************************************************
     EVENTS
  *****************************************************************************
  */

  events :
  {
    /** Whenever the value is changed this event is fired
     *
     *  Event data: The new text value of the field.
     */
    "changeValue" : "qx.event.type.Data"
  },




  /*
  *****************************************************************************
     PROPERTIES
  *****************************************************************************
  */

  properties :
  {

    /** The formatter, which converts the selected date to a string. **/
    dateFormat :
    {
      check : "qx.util.format.DateFormat",
      apply : "_applyDateFormat"
    },

    /**
     * String value which will be shown as a hint if the field is all of:
     * unset, unfocused and enabled. Set to null to not show a placeholder
     * text.
     */
    placeholder :
    {
      check : "String",
      nullable : true,
      apply : "_applyPlaceholder"
    },

    // overridden
    appearance :
    {
      refine : true,
      init : "datefield"
    },

    // overridden
    focusable :
    {
      refine : true,
      init : true
    },

    // overridden
    width :
    {
      refine : true,
      init : 120
    }
  },




  /*
  *****************************************************************************
     MEMBERS
  *****************************************************************************
  */

  statics :
  {
    __dateFormat : null,
    __formatter : null,

    /**
     * Get the shared default date formatter
     *
     * @return {qx.util.format.DateFormat} The shared date formatter
     */
    getDefaultDateFormatter : function()
    {
      var format = qx.locale.Date.getDateFormat("medium").toString();

      if (format == this.__dateFormat) {
        return this.__formatter;
      }

      if (this.__formatter) {
        this.__formatter.dispose();
      }

      this.__formatter = new qx.util.format.DateFormat(format, qx.locale.Manager.getInstance().getLocale());
      this.__dateFormat = format;

      return this.__formatter;
    }
  },




  /*
  *****************************************************************************
     MEMBERS
  *****************************************************************************
  */

  members :
  {
    __localeListenerId : null,


    /**
     * @lint ignoreReferenceField(_forwardStates)
     */
    _forwardStates : {
      focused : true,
      invalid : true
    },


    /*
    ---------------------------------------------------------------------------
      PROTECTED METHODS
    ---------------------------------------------------------------------------
    */
    /**
     * Sets the default date format which is returned by
     * {@link #getDefaultDateFormatter}. You can overrride this method to
     * define your own default format.
     */
    _setDefaultDateFormat : function() {
      this.setDateFormat(qx.ui.form.DateField.getDefaultDateFormatter());
    },


    /**
     * Checks for "qx.dynlocale" and adds a listener to the locale changes.
     * On every change, {@link #_setDefaultDateFormat} is called to reinitialize
     * the format. You can easily override that method to prevent that behavior.
     */
    _addLocaleChangeListener : function() {
      // listen for locale changes
      if (qx.core.Environment.get("qx.dynlocale"))
      {
        this.__localeListenerId =
          qx.locale.Manager.getInstance().addListener("changeLocale", function() {
            this._setDefaultDateFormat();
          }, this);
      }
    },


    /*
    ---------------------------------------------------------------------------
      PUBLIC METHODS
    ---------------------------------------------------------------------------
    */


    /**
    * This method sets the date, which will be formatted according to
    * #dateFormat to the date field. It will also select the date in the
    * calendar popup.
    *
    * @param value {Date} The date to set.
     */
    setValue : function(value)
    {
      // set the date to the textfield

      if (value != null) {      
          this.getChildControl("datefield").setValue(this.getDateFormat().format(value));

          var h = value.getHours();
          var m = value.getMinutes();
          while (m.length<2) {
              m = '0'+m;
          }
          while (h.length<2) {
              h = '0'+h;
          }
          this.getChildControl("timefield").setValue(h+':'+m);

          // set the date in the datechooser
          var dateChooser = this.getChildControl("list");
          dateChooser.setValue(value);
      }
    },


    /**
     * Returns the current set date, parsed from the input-field
     * corresponding to the {@link #dateFormat}.
     * If the given text could not be parsed, <code>null</code> will be returned.
     *
     * @return {Date} The currently set date.
     */
    getValue : function()
    {
      // get the value of the textfields
      var dc = this.getChildControl("datefield");
      var tc = this.getChildControl("timefield");
      var datefieldValue = dc.getValue();
      var timefieldValue = tc.getValue();
      var today = new Date();
      today.setHours(0);
      today.setMinutes(0);
      today.setMilliseconds(0);
      var value = today;
//      this.debug('getValue(): date=', datefieldValue, ', time=', timefieldValue);
      // return the parsed date
      try {
          if (datefieldValue != null) {
              try {
                  value = this.getDateFormat().parse(datefieldValue);
              }
              catch (ex) {
                  this.debug('getValue(): Invalid date format');
              }
          }
          var t  = value.getTime();
          var ta = ['00','00'];
          if (timefieldValue != null && timefieldValue != '') {
              ta = timefieldValue.split(':');
              if (ta[0] == null) {
                  ta[0] = '00';
              }
              if (ta[1] == null) {
                  ta[1] = '00';
              }
              if (parseInt(ta[1]) > 59) {
                  ta[1] = '59';
              }
              if (parseInt(ta[0]) > 23) {
                  ta[0] = '23';
                  ta[1] = '59';
              }
              while (ta[0].length <2) {
                  ta[0] = '0' + ta[0];
              }
              while (ta[1].length <2) {
                  ta[1] = '0' + ta[1];
              }
              var dt = parseInt(ta[0])*3600;
              dt += parseInt(ta[1])*60;
              var maxDt = 24*3600 - 1;
              if (dt > maxDt) {
                  this.debug('dt=', dt, '> maxdt=', maxDt);
                  dt = maxDt;
                  ta[0] = '23';
                  ta[1] = '59';
              }
              if (dt<0) {
                  dt = 0;
                  ta[0] = '00';
                  ta[1] = '00';
              }
              dt *= 1000; // time offset in msec
              value.setTime(t+dt);
          }
          tc.setValue(ta[0]+':'+ta[1]);
      } catch (ex) {
          this.debug('getValue(): unknown exception caught');
//          value = null;
      }
      return value;
    },


    /**
     * Resets the DateField. The textfield will be empty and the datechooser
     * will also have no selection.
     */
    resetValue: function()
    {
      // clear the date and time textfields
      var dateField = this.getChildControl("datefield");
      dateField.setValue("");
      var timeField = this.getChildControl("timefield");
      timeField.setValue("");

      // set the date in the datechooser
      var dateChooser = this.getChildControl("list");
      dateChooser.setValue(null);
    },


    /*
    ---------------------------------------------------------------------------
      LIST STUFF
    ---------------------------------------------------------------------------
    */

    /**
     * Shows the date chooser popup.
     */
    open : function()
    {
      var popup = this.getChildControl("popup");

      popup.placeToWidget(this, true);
      popup.show();
    },


    /**
     * Hides the date chooser popup.
     */
    close : function() {
      this.getChildControl("popup").hide();
    },


    /**
     * Toggles the date chooser popup visibility.
     */
    toggle : function()
    {
      var isListOpen = this.getChildControl("popup").isVisible();
      if (isListOpen) {
        this.close();
      } else {
        this.open();
      }
    },


    /*
    ---------------------------------------------------------------------------
      PROPERTY APPLY METHODS
    ---------------------------------------------------------------------------
    */

    // property apply routine
    _applyDateFormat : function(value, old)
    {
      // if old is undefined or null do nothing
      if (!old) {
        return;
      }

      // get the date with the old date format
      try
      {
        var datefield = this.getChildControl("datefield");
        var dateStr = datefield.getValue();
        var currentDate = old.parse(dateStr);
        datefield.setValue(value.format(currentDate));
      }
      catch (ex) {
        // do nothing if the former date could not be parsed
      }
    },


    // property apply routine
    _applyPlaceholder : function(value, old) {
        var p = value.split("@");
//        this.getChildControl("datefield").setPlaceholder(qx.locale.Manager.tr(p[0]));
        this.getChildControl("datefield").setPlaceholder(this.xtr(p[0]));
        if (p[1] != null) {
            this.getChildControl("timefield").setPlaceholder(p[1]);
        }
    },


    /*
    ---------------------------------------------------------------------------
      WIDGET API
    ---------------------------------------------------------------------------
    */

    // overridden
    _createChildControlImpl : function(id, hash)
    {
      var control;

      switch(id)
      {
        case "datefield":
          control = new qx.ui.form.TextField();
          control.setFocusable(false);
          control.addState("inner");
          control.setMaxWidth(100);
          control.setDecorator(null);
          control.addListener("changeValue", this._onDateFieldChangeValue, this);
          control.addListener("blur", this.close, this);
          this._add(control, {flex:1});
          break;

        case "timefield":
          control = new qx.ui.form.TextField();
          control.setFocusable(false);
          control.setDecorator(null);
          control.setMaxWidth(80);
          control.setMaxLength(5);
          control.setFilter(/[\d:]/);
          control.addState("inner");
          control.addListener("changeValue", this._onTimeFieldChangeValue, this);
          control.addListener("blur", this.close, this);
          this._add(new qx.ui.core.Spacer(25));
          this._add(control, {flex:1});

          break;

        case "button":
          control = new qx.ui.form.Button();
          control.setFocusable(false);
          control.setKeepActive(true);
          control.addState("inner");
          control.addListener("execute", this.toggle, this);
          this._add(control);
          break;

        case "list":
          control = new qx.ui.control.DateChooser();
          control.setFocusable(false);
          control.setKeepFocus(true);
          control.addListener("execute", this._onChangeDate, this);
          break;

        case "popup":
          control = new qx.ui.popup.Popup(new qx.ui.layout.VBox);
          control.setAutoHide(false);
          control.add(this.getChildControl("list"));
          control.addListener("pointerup", this._onChangeDate, this);
          control.addListener("changeVisibility", this._onPopupChangeVisibility, this);
          break;
      }

      return control || this.base(arguments, id);
    },




   /*
   ---------------------------------------------------------------------------
     EVENT LISTENERS
   ---------------------------------------------------------------------------
   */

   /**
    * Handler method which handles the tap on the calender popup.
    *
    * @param e {qx.event.type.Pointer} The pointer event.
    */
    _onChangeDate : function(e)
    {
        var dateField = this.getChildControl("datefield");

        var selectedDate = this.getChildControl("list").getValue();
        var timefield = this.getChildControl("timefield");
        var time        = timefield.getValue();
        var defaultTime = timefield.getPlaceholder();
        dateField.setValue(this.getDateFormat().format(selectedDate));
        if (time == null && defaultTime != null) {
            timefield.setValue(defaultTime);
        }
        this.close();
    },


    /**
     * Toggles the popup's visibility.
     *
     * @param e {qx.event.type.Pointer} Pointer tap event
     */
    _onTap : function(e) {
      this.close();
    },


    /**
     * Handler for the blur event of the current widget.
     *
     * @param e {qx.event.type.Focus} The blur event.
     */
    _onBlur : function(e) {
      this.close();
    },


    /**
     * Handler method which handles the key press. It forwards all key event
     * to the opened date chooser except the escape key event. Escape closes
     * the popup.
     * If the list is cloned, all key events will not be processed further.
     *
     * @param e {qx.event.type.KeySequence} Keypress event
     */
    _onKeyPress : function(e)
    {
      // get the key identifier
      var iden = e.getKeyIdentifier();
      if (iden == "Down" && e.isAltPressed())
      {
        this.toggle();
        e.stopPropagation();
        return;
      }

      // if the popup is closed, ignore all
      var popup = this.getChildControl("popup");
      if (popup.getVisibility() == "hidden") {
        return;
      }

      // hide the list always on escape
      if (iden == "Escape")
      {
        this.close();
        e.stopPropagation();
        return;
      }

      // Stop navigation keys when popup is open
      if (iden === "Left" || iden === "Right" || iden === "Down" || iden === "Up") {
        e.preventDefault();
      }

      // forward the rest of the events to the date chooser
      this.getChildControl("list").handleKeyPress(e);
    },


    /**
     * Redirects changeVisibility event from the list to this widget.
     *
     * @param e {qx.event.type.Data} Property change event
     */
    _onPopupChangeVisibility : function(e)
    {
      e.getData() == "visible" ? this.addState("popupOpen") : this.removeState("popupOpen");

      // Synchronize the chooser with the current value on every
      // opening of the popup. This is needed when the value has been
      // modified and not saved yet (e.g. no blur)
      var popup = this.getChildControl("popup");
      var chooser = this.getChildControl("list");
      if (popup.isVisible())
      {
          var date = this.getValue();
          if (date != null) {
              chooser.setValue(date);
          }
      }
    },


    /**
     * Reacts on value changes of the text field and syncs the
     * value to the combobox.
     *
     * @param e {qx.event.type.Data} Change event
     */
    _onDateFieldChangeValue : function(e)
    {
      // Apply to popup
      var date = e.getData();
      if (date != null && date != '')
      {

        var timefield = this.getChildControl("timefield");
        var time        = timefield.getValue();
        var defaultTime = timefield.getPlaceholder();
        var today = new Date();
          var dateValue;
        try {
            dateValue = this.getDateFormat().parse(date);
        }
        catch (ex) {
            this.debug('_onDateFieldChangeValue(): Invalid date format');
            dateValue = today;
        }
        this.setValue(dateValue);
        var list = this.getChildControl("list");
        list.setValue(dateValue);
        if (time != null) {
            timefield.setValue(time);
        }
        else if (defaultTime != null) {
            timefield.setValue(defaultTime);
        }

      }

      // Fire event
      this.fireDataEvent("changeValue", this.getValue());
    },


    /**
     * Reacts on value changes of the text field.
     *
     * @param e {qx.event.type.Data} Change event
     */
    _onTimeFieldChangeValue : function(e)
    {
      // Fire event
      this.fireDataEvent("changeValue", this.getValue());
    },


    /**
     * Checks if the textfield of the DateField is empty.
     *
     * @return {Boolean} True, if the textfield of the DateField is empty.
     */
    isEmpty: function()
    {
      var value = this.getChildControl("datefield").getValue();
      return value == null || value == "";
    }
  },


  destruct : function() {
    // listen for locale changes
    if (qx.core.Environment.get("qx.dynlocale"))
    {
      if (this.__localeListenerId) {
        qx.locale.Manager.getInstance().removeListenerById(this.__localeListenerId);
      }
    }
  }
});
