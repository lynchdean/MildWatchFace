//
// Copyright 2015-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
import Toybox.Complications;
import Toybox.Time.Gregorian;
import Toybox.Application;

// import Complicated;

//! Main watch face view
class MildFaceView extends WatchUi.WatchFace {
    private var mildLogo as BitmapReference?;

    private var showSeconds = true;

    // Layout
    private var _height, _width, _centerHeight, _centerWidth as Number?;

    // Fonts
    private var _xtFontHeight as Number?;
    private var _lgFontHeight as Number?;

    // Vector fonts
    private var _hasScalable= false;
    private var xtFont as Graphics.VectorFont?;
    private var lgFont as Graphics.VectorFont?;
    private var xtRcw as Number?;
    private var xtRccw as Number?;
    private var lgR as Number?;

    // Complications
    private var _hasComplications = false;
    private var hrId = null;
    private var curHr=0;
    private var tempId = null;
    private var curTemp=0;

    //! Constructor
    function initialize() {
        WatchFace.initialize();
        mildLogo = Application.loadResource(Rez.Drawables.mildWhite);

        // Check for scalable fonts
        _hasScalable = Toybox.Graphics has :getVectorFont;

        // Check for complications
        _hasComplications = Toybox has :Complications;
        if(_hasComplications) {
            hrId = new Complications.Id(Complications.COMPLICATION_TYPE_HEART_RATE);
            tempId = new Complications.Id(Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE);

            Complications.registerComplicationChangeCallback(self.method(:onComplicationUpdated));
            Complications.subscribeToUpdates(hrId);
            Complications.subscribeToUpdates(tempId);
        }
    }

    //! Load layout
    //! @param dc Draw context
    function onLayout(dc as Dc) as Void { 
        // Screen resolution calculations
        _height = dc.getHeight();
        _width = dc.getWidth();
        _centerHeight = _height / 2;
        _centerWidth = _width / 2;

        // Font size calculations
        _xtFontHeight = dc.getFontHeight(Graphics.FONT_XTINY);
        _lgFontHeight = dc.getFontHeight(Graphics.FONT_LARGE);

        if (_hasScalable) {
            xtFont = Graphics.getVectorFont({:face=>["RobotoCondensedBold","RobotoRegular"], :size=>_xtFontHeight});
            lgFont = Graphics.getVectorFont({:face=>["RobotoCondensedBold","RobotoRegular"], :size=>_lgFontHeight});
            xtRcw = _centerHeight - Graphics.getFontAscent(xtFont) - 8;
            xtRccw = _centerHeight - 12;
            lgR = _centerHeight - Graphics.getFontAscent(lgFont);
        }

        showSeconds = Properties.getValue("ShowSeconds");
    }

    //! Called when this View is brought to the foreground. Restore
    //! the state of this View and prepare it to be shown. This includes
    //! loading resources into memory.
    function onShow() as Void {
    }

    //! Update the view
    //! @param dc Draw context
    function onUpdate(dc as Dc) as Void {
        // Get the current time and format it correctly
        var clockTime = System.getClockTime();
        var hours = clockTime.hour;
        if (!System.getDeviceSettings().is24Hour) {
            if (hours > 12) {
                hours = hours - 12;
            }
        } 
        var timeString = Lang.format("$1$:$2$", [hours, clockTime.min.format("%02d")]);
        var secString = clockTime.sec.format("%.2d");

        // Get the current date and format it
        var date = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateString = Lang.format("$1$ $2$", [date.day_of_week.toUpper(), date.day]);

        // Get the current battery and format it. 
        var stats = System.getSystemStats();
        var batteryString = Lang.format("$1$%", [stats.battery.format("%d")]);

        // Get HR and format it 
        var hr = (_hasComplications and curHr != null) ? curHr : Activity.getActivityInfo().currentHeartRate;
        var hrString = Lang.format("HR: $1$", [(hr==null) ? "--" : hr.toString()]);

        // Get Temp and format it 
        var temp = (_hasComplications and curTemp != null) ? curTemp : "";
        var tempString = Lang.format("$1$°C", [(temp==null) ? "--" : temp.format("%d").toString()]);

        // Set background Colour
        dc.setColor(Properties.getValue("BackgroundColor"), Properties.getValue("BackgroundColor"));
        dc.clear();

        dc.setColor(Properties.getValue("TextColor"), Graphics.COLOR_TRANSPARENT);
        if (_hasScalable) {
            dc.drawRadialText(_centerHeight, _centerWidth, xtFont, batteryString, Graphics.TEXT_JUSTIFY_CENTER, 135, xtRcw, Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE);
            dc.drawRadialText(_centerHeight, _centerWidth, lgFont, timeString, Graphics.TEXT_JUSTIFY_CENTER, 90, lgR, Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE);
            if (showSeconds) {
                dc.drawRadialText(_centerHeight, _centerWidth, xtFont, secString, Graphics.TEXT_JUSTIFY_CENTER, 60, xtRcw, Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE); 
            }

            dc.drawRadialText(_centerHeight, _centerWidth, xtFont, tempString, Graphics.TEXT_JUSTIFY_CENTER, 225, xtRccw, Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
            dc.drawRadialText(_centerHeight, _centerWidth, xtFont, dateString, Graphics.TEXT_JUSTIFY_CENTER, 270, xtRccw, Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
            dc.drawRadialText(_centerHeight, _centerWidth, xtFont, hrString, Graphics.TEXT_JUSTIFY_CENTER, 315, xtRccw, Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
        } else {
            dc.drawText(_width / 2, 0, Graphics.FONT_MEDIUM, timeString, Graphics.TEXT_JUSTIFY_CENTER);
            if (showSeconds) {
            dc.drawText(_width / 2 + 48, 0 + 10, Graphics.FONT_XTINY, secString, Graphics.TEXT_JUSTIFY_CENTER);
            }
            dc.drawText(_width / 2, _height - _xtFontHeight, Graphics.FONT_XTINY, batteryString, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(_width / 2, _height - _xtFontHeight - 15, Graphics.FONT_XTINY, dateString, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Draw Mild logo
        var mildcolor = Properties.getValue("MildColor") as Graphics.ColorValue;
        System.print(Properties.getValue("MildColor"));
        dc.drawBitmap2(_width / 20, _height / 20, mildLogo, {:tintColor=>mildcolor});
    }

    //! Called when this View is removed from the screen. Save the
    //! state of this View here. This includes freeing resources from
    //! memory.
    function onHide() {
    }

    //! The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
    }

    //! Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
    }

    function onSettingsChanged() {
        showSeconds = Properties.getValue("ShowSeconds");
    }
    
    function onComplicationUpdated(complicationId as Complications.Id) as Void {
        if (complicationId.equals(hrId)) {
            curHr = Complications.getComplication(complicationId).value;
        } else if (complicationId.equals(tempId)) {
            curTemp = Complications.getComplication(complicationId).value;
        }
    }
}
