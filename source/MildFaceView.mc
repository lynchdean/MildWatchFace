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
import Toybox.Weather;
import Toybox.Time.Gregorian;
import Toybox.Application;

// import Complicated;

//! Main watch face view
class MildFaceView extends WatchUi.WatchFace {
    private var mildLogo as BitmapReference?;
    private var logoPaddingModifier as Number?;
    private var iconFont;

    // Power/Screen management
    private var canBurnIn, inLowPower = false;

    // Layout
    private var height, width, centerHeight, centerWidth as Number?;

    // Fonts
    private var xtFontHeight, lgFontHeight as Number?;
    private var hasScalable = false;
    private var xtFont;
    private var lgFont;
    private var xtRcw, xtRccw as Number?;
    private var lgR as Number?;

    // Complications
    private var hasComplications = false;
    private var hrId = null;
    private var curHr = 0;
    private var tempId = null;
    private var curTemp = 0;
    private var stepsId = null;
    private var curSteps = 0;
    private var calsId = null;
    private var curCals = 0;


    //! Constructor
    function initialize() {
        WatchFace.initialize();

        //check if AMOLED
        var settings=System.getDeviceSettings();
        if(settings has :requiresBurnInProtection) {       
        	canBurnIn = settings.requiresBurnInProtection;        	
        }
        
        setLogo();

        // Font for status icons
        iconFont = Application.loadResource(Rez.Fonts.icon_font);

        // Check for scalable fonts
        hasScalable = Toybox.Graphics has :getVectorFont;

        // Check for complications
        hasComplications = Toybox has :Complications;
        if(hasComplications) {
            hrId = new Complications.Id(Complications.COMPLICATION_TYPE_HEART_RATE);
            tempId = new Complications.Id(Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE);
            stepsId = new Complications.Id(Complications.COMPLICATION_TYPE_STEPS);
            calsId = new Complications.Id(Complications.COMPLICATION_TYPE_CALORIES);

            Complications.registerComplicationChangeCallback(self.method(:onComplicationUpdated));
            Complications.subscribeToUpdates(hrId);
            Complications.subscribeToUpdates(tempId);
            Complications.subscribeToUpdates(stepsId);
            Complications.subscribeToUpdates(calsId);
        }
    }

    //! Load layout
    //! @param dc Draw context
    function onLayout(dc as Dc) as Void { 
        // Screen resolution calculations
        height = dc.getHeight();
        width = dc.getWidth();
        centerHeight = height / 2;
        centerWidth = width / 2;

        // Font size calculations
        xtFontHeight = dc.getFontHeight(Graphics.FONT_XTINY);
        lgFontHeight = dc.getFontHeight(Graphics.FONT_LARGE);

        System.print(xtFontHeight);

        if (hasScalable) {
            xtFont = Graphics.getVectorFont({:face=>["RobotoCondensedBold","RobotoRegular"], :size=>xtFontHeight});
            lgFont = Graphics.getVectorFont({:face=>["RobotoCondensedBold","RobotoRegular"], :size=>lgFontHeight});
            xtRcw = centerHeight - Graphics.getFontAscent(xtFont) - 6;
            xtRccw = centerHeight - 12;
            lgR = centerHeight - Graphics.getFontAscent(lgFont);
        } else {
            xtFont = Graphics.FONT_XTINY;
            lgFont = Graphics.FONT_LARGE;
        }
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

        // Get the current date and format it
        var date = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateString = Lang.format("$1$ $2$", [date.day_of_week.toUpper(), date.day]);

        // Set background Colour (always black in low power mode)
        if (canBurnIn && inLowPower) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        } else {
            dc.setColor(Properties.getValue("BackgroundColor"), Properties.getValue("BackgroundColor"));
        }
        dc.clear();

        // Large Complications (always grey in always on mode)
        if (canBurnIn && inLowPower) {
            dc.setColor(Properties.getValue("AlwaysOnColor"), Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Properties.getValue("TextColor"), Graphics.COLOR_TRANSPARENT);
        }

        if (hasScalable) {
            dc.drawRadialText(centerWidth, centerHeight, lgFont, timeString, Graphics.TEXT_JUSTIFY_CENTER, 90, lgR, Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE);
            dc.drawRadialText(centerWidth, centerHeight, xtFont, dateString, Graphics.TEXT_JUSTIFY_CENTER, 270, xtRccw, Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);

            dc.drawRadialText(centerWidth, centerHeight, xtFont, getComplicationString(Properties.getValue("TopLeft")), Graphics.TEXT_JUSTIFY_CENTER, 145, xtRcw, Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE);
            dc.drawRadialText(centerWidth, centerHeight, xtFont, getComplicationString(Properties.getValue("TopRight")), Graphics.TEXT_JUSTIFY_CENTER, 35, xtRcw, Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE);
            dc.drawRadialText(centerWidth, centerHeight, xtFont, getComplicationString(Properties.getValue("BottomLeft")), Graphics.TEXT_JUSTIFY_CENTER, 220, xtRccw, Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
            dc.drawRadialText(centerWidth, centerHeight, xtFont, getComplicationString(Properties.getValue("BottomRight")), Graphics.TEXT_JUSTIFY_CENTER, 320, xtRccw, Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
        } else {
            // dc.drawText(width / 2, 0, Graphics.FONT_MEDIUM, timeString, Graphics.TEXT_JUSTIFY_CENTER);
            // dc.drawText(width / 2, height - xtFontHeight, Graphics.FONT_XTINY, "batteryString", Graphics.TEXT_JUSTIFY_CENTER);
            // dc.drawText(width / 2, height - xtFontHeight - 15, Graphics.FONT_XTINY, dateString, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Small Complications
        var sL = Properties.getValue("SmallLeft");
        var sR = Properties.getValue("SmallRight");
        dc.drawText(12, centerHeight, (sL == 1) ? xtFont : iconFont, getSmallComplicationString(sL), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER); 
        dc.drawText(width - 12, centerHeight, (sR == 1) ? xtFont : iconFont, getSmallComplicationString(sR), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER); 


        // Draw Mild logo
        var logoColor;
        if (canBurnIn && inLowPower) {
            logoColor = Properties.getValue("AlwaysOnColor") as Graphics.ColorValue;;
        } else {
            logoColor = Properties.getValue("LogoColor") as Graphics.ColorValue;;
        }
        if (dc has :drawBitmap2) {
            dc.drawBitmap2(width / logoPaddingModifier, height / logoPaddingModifier, mildLogo, {:tintColor=>logoColor});
        } else {
            dc.drawBitmap(width / logoPaddingModifier, height / logoPaddingModifier, mildLogo);
        }

        // TEST - Used to check equal distance around the border
        // dc.drawCircle(centerWidth, centerHeight, centerHeight -12);
    }

    //! Called when this View is removed from the screen. Save the
    //! state of this View here. This includes freeing resources from
    //! memory.
    function onHide() {
    }

    //! The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
        inLowPower=false;
        setLogo();
        WatchUi.requestUpdate();
    }

    //! Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
        inLowPower=true;
        setLogo();
        WatchUi.requestUpdate();
    }

    function onSettingsChanged() {
        setLogo();
    }
    
    function onComplicationUpdated(complicationId as Complications.Id) as Void {
        if (complicationId.equals(hrId)) {
            curHr = Complications.getComplication(complicationId).value;
        } else if (complicationId.equals(tempId)) {
            curTemp = Complications.getComplication(complicationId).value;
        } else if (complicationId.equals(stepsId)) {
            curSteps = Complications.getComplication(complicationId).value;
        } else if (complicationId.equals(calsId)) {
            curCals = Complications.getComplication(complicationId).value;
        }
    }

    function setLogo() as Void {
        var isFigure = Properties.getValue("LogoIsFigure");
        logoPaddingModifier = (isFigure) ? 20 : 10;
        if (canBurnIn && inLowPower) {
            mildLogo = (isFigure) ? Application.loadResource(Rez.Drawables.mildLogoFigureOutline) : Application.loadResource(Rez.Drawables.mildLogoOutline);
        } else {
            mildLogo = (isFigure) ? Application.loadResource(Rez.Drawables.mildLogoFigure) : Application.loadResource(Rez.Drawables.mildLogo);
        }
    }

    function getComplicationString(n as Number) as String {
        // hasComplications = false;
        if (n == 1) { 
            // Battery %
            return Lang.format("BAT: $1$%", [System.getSystemStats().battery.format("%d")]);
        } else if (n == 2) {
            // Heart Rate
            var hr = (hasComplications and curHr != null) ? curHr : Activity.getActivityInfo().currentHeartRate;
            return Lang.format("HR: $1$", [(hr==null) ? "--" : hr.toString()]);
        } else if (n == 3) {
            // Temperature
            var temp;
            if (hasComplications and curTemp != null) {
                temp = curTemp;
            } else if (Weather.getCurrentConditions() != null) {
                temp = Weather.getCurrentConditions().temperature;
                if (temp == null) {
                    temp = "--"
                }
            }
            return Lang.format("TEMP: $1$°C", [(temp==null) ? "--" : temp.format("%d").toString()]);
        } else if (n == 4) {
            // Steps
            var steps = (hasComplications and curSteps != null) ? curSteps : ActivityMonitor.getInfo().steps;
            return Lang.format("STEPS: $1$", [(steps==null) ? "--" : steps.format("%d").toString()]);
        } else if (n == 5) {
            var cals = (hasComplications and curCals != null) ? curCals : ActivityMonitor.getInfo().calories;
            return Lang.format("KCAL: $1$", [(cals==null) ? "--" : cals.format("%d").toString()]);
        }
        return "";
    }

    function getSmallComplicationString(n as Number) as String {
        if (n == 1) {
            // Seconds
            return System.getClockTime().sec.format("%.2d");
        } else if (n == 2) {
            // Device Connected
            return System.getDeviceSettings().phoneConnected ? "4" : "";
        } else if (n == 3) {
            // Alarm Set
            return System.getDeviceSettings().alarmCount ? "0" : "";
        } else if (n == 4) {
            var bat = System.getSystemStats().battery;
            if (bat > 66) {
                return "1";
            } else if (bat > 15) {
                return "2";
            } else {
                return "3";
            }
        }
        return "";
    }
}