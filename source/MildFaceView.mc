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
    private var logoPM as Number?;
    private var iconFont;
    
    // Power/Screen management
    private var canBurnIn, inLowPower = false;
    private var hasBitmap2 = false;


    // Layout
    private var height, width, centerH, centerW as Number?;
    private var statusModifier as Float?;

    // Fonts
    private var xtFontH, lgFontH as Number?;
    private var hasScalable = false;
    private var xtFont;
    private var lgFont;
    private var xtR as Number?;
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

    // Icon Toggles
    private var showDeviceConnectedIcon = true;
    private var showAlarmIcon = true;
    private var showBatteryIcon = true;

    private var resources as Array<Lang.ResourceId> = [
        Rez.Drawables.mildLogo,
        Rez.Drawables.mildFigure,
        Rez.Drawables.mildLogoOutline,
        Rez.Drawables.mildFigureOutline,
        Rez.Drawables.mildLogoWhite,
        Rez.Drawables.mildLogoBlack,
        Rez.Drawables.mildLogoRed,
        Rez.Drawables.mildFigureWhite,
        Rez.Drawables.mildFigureBlack,
        Rez.Drawables.mildFigureRed
    ];

    //! Constructor
    function initialize() {
        WatchFace.initialize();

        //check if AMOLED
        var settings=System.getDeviceSettings();
        if(settings has :requiresBurnInProtection) {       
        	canBurnIn = settings.requiresBurnInProtection;        	
        }

        showDeviceConnectedIcon = Properties.getValue("DeviceConnecitedIndicator");
        showAlarmIcon = Properties.getValue("AlarmIndicator");
        showBatteryIcon = Properties.getValue("BatteryIndicator");
        
        // Font for status icons
        iconFont = Application.loadResource(Rez.Fonts.icon_font);
        
        // Check for bitmap tinting
        hasBitmap2 = Toybox.Graphics.Dc has :drawBitmap2;

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

        setLogo();
    }

    //! Load layout
    //! @param dc Draw context
    function onLayout(dc as Dc) as Void { 
        // Screen resolution calculations
        height = dc.getHeight();
        width = dc.getWidth();
        centerH = height / 2;
        centerW = width / 2;

        statusModifier = (height > 218) ? 2.5 : 2;

        // Font size calculations
        xtFontH = dc.getFontHeight(Graphics.FONT_XTINY);
        lgFontH = dc.getFontHeight(Graphics.FONT_LARGE);

        if (hasScalable) {
            xtFont = Graphics.getVectorFont({:face=>["RobotoCondensedBold","RobotoRegular"], :size=>xtFontH});
            lgFont = Graphics.getVectorFont({:face=>["RobotoCondensedBold","RobotoRegular"], :size=>lgFontH});
            xtR = centerH - Graphics.getFontDescent(xtFont);
            lgR = centerH - Graphics.getFontAscent(lgFont);
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

        // Colour Settings for Always-On
        var logoColor;
        if (canBurnIn && inLowPower) {
            dc.setColor(Properties.getValue("AlwaysOnColor"), Graphics.COLOR_TRANSPARENT);
            logoColor = Properties.getValue("AlwaysOnColor") as Graphics.ColorValue;;
        } else {
            dc.setColor(Properties.getValue("TextColor"), Graphics.COLOR_TRANSPARENT);
            logoColor = Properties.getValue("LogoColor") as Graphics.ColorValue;;
        }
        
        // Large Complications
        if (hasScalable) {
            dc.drawRadialText(centerW, centerH, lgFont, timeString, Graphics.TEXT_JUSTIFY_CENTER, 90, lgR, Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE);
            dc.drawRadialText(centerW, centerH, xtFont, dateString, Graphics.TEXT_JUSTIFY_CENTER, 270, xtR, Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
            if (!inLowPower) {
                dc.drawRadialText(centerW, centerH, xtFont, getCompStr(Properties.getValue("Comp1")), Graphics.TEXT_JUSTIFY_CENTER, 210, xtR, Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
                dc.drawRadialText(centerW, centerH, xtFont, getCompStr(Properties.getValue("Comp2")), Graphics.TEXT_JUSTIFY_CENTER, 330, xtR, Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);                
            }
        } else {
            dc.drawText(width / 2, 0, Graphics.FONT_LARGE, timeString, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(width / 2, height - xtFontH, Graphics.FONT_XTINY, dateString, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Icon status bar
        dc.drawText(width / 2, height - statusModifier * xtFontH, iconFont, getStatusString(), Graphics.TEXT_JUSTIFY_CENTER);

        // Draw Mild logo
        if (dc has :drawBitmap2) {
            dc.drawBitmap2(width / logoPM, height / logoPM, mildLogo, {:tintColor=>logoColor});
        } else {
            dc.drawBitmap(width / logoPM, height / logoPM, mildLogo);
        }
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
        showDeviceConnectedIcon = Properties.getValue("DeviceConnecitedIndicator");
        showAlarmIcon = Properties.getValue("AlarmIndicator");
        showBatteryIcon = Properties.getValue("BatteryIndicator");
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
        logoPM = (isFigure) ? 20 : 10;
        var logoId;
        System.print(hasBitmap2);
        if (hasBitmap2) {
            if (canBurnIn && inLowPower) {
                logoId = (isFigure) ? 3 : 2;
            } else {
                logoId = (isFigure) ? 1 : 0;
            }
        } else {
            // For devices without Bitmap2, LogoColor's value is an array index instead of a hex colour
            logoId = Properties.getValue("LogoColor");
            if (isFigure) {
                logoId = logoId + 3;
            }
        }
        mildLogo = Application.loadResource(resources[logoId]);
    }

    function getCompStr(n as Number) as String {
        if (n == 1) { 
            // Battery %
            return Lang.format("BAT: $1$%", [System.getSystemStats().battery.format("%d")]);
        } else if (n == 2) {
            // Heart Rate
            var hr = (hasComplications and curHr != null) ? curHr : Activity.getActivityInfo().currentHeartRate;
            return Lang.format("HR: $1$", [(hr==null) ? "--" : hr.toString()]);
        } else if (n == 3) {
            // Temperature
            if (hasComplications and curTemp != null) {
                return Lang.format("TEMP: $1$°C", [curTemp.format("%d")]);
            } else {
                // Double check for null is important here
                var currentConditions = Weather.getCurrentConditions();
                if (currentConditions != null) {
                    if (currentConditions.temperature != null) {
                        return Lang.format("TEMP: $1$°C", [currentConditions.temperature.format("%d")]);
                    }
                }
                return "TEMP: --°C";
            }
        } else if (n == 4) {
            // Steps
            var steps = (hasComplications and curSteps != null) ? curSteps : ActivityMonitor.getInfo().steps;
            return Lang.format("STEPS: $1$", [(steps==null) ? "--" : steps.format("%d")]);
        } else if (n == 5) {
            var cals = (hasComplications and curCals != null) ? curCals : ActivityMonitor.getInfo().calories;
            return Lang.format("KCAL: $1$", [(cals==null) ? "--" : cals.format("%d")]);
        } else if (n == 6) {
            return "SUN:";
        }
        return "";
    }

    function getStatusString() as String {
        var status = "";
        if (showDeviceConnectedIcon) {
            if (System.getDeviceSettings().phoneConnected) {
                status = status + "4";
            }
        }
        if (showAlarmIcon) {
            if (System.getDeviceSettings().alarmCount) {
                status = status + "0";
            }
        }
        if (showBatteryIcon) {
            var bat = System.getSystemStats().battery;
            if (bat > 66) {
                status = status + "1";
            } else if (bat > 15) {
                status = status + "2";
            } else {
                status = status + "3";
            }
        }
        return status;
    }
}