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

const hasScalable = Toybox.Graphics has :getVectorFont;
const hasComplications = Toybox has :Complications;

class MildFaceView extends WatchUi.WatchFace {
private var logo as BitmapReference?;
    private var logoPM as Number?;
    private var iconFont;

    // Time based toggles
    private var isSundayService = false;

    // Power/Screen management
    (:ciq2plus) private var canBurnIn, inLowPower = false;

    // Layout
    private var height, width as Number?;
    (:ciq2plus) private var centerH, centerW as Number?;
    private var statusModifier as Float?;

    // Fonts
    (:ciq2plus) private var lgFontH as Number?;
    private var xtFontH as Number?;
    private var xtFont, lgFont;
    (:ciq2plus) private var xtR, lgR as Number?;

    // Complications
    (:ciq2plus) private var hrId, tempId, stepsId, calsId = null;
    (:ciq2plus) private var curHr, curTemp, curSteps, curCals = 0;

    // Icon Toggles
    private var showDeviceConnectedIcon = true;
    private var showAlarmIcon = true;
    private var showBatteryIcon = true;

    // Both base logo and white varient is neccessary for devices with limited memory
    private var textLogo as Array<Lang.ResourceId> = [
        Rez.Drawables.mildLogo,
        Rez.Drawables.mildLogoWhite,
        Rez.Drawables.mildLogoBlack,
        Rez.Drawables.mildLogoRed
    ];

    // Figure Logos
    private var figureLogos as Array<Lang.ResourceId> = [
        Rez.Drawables.mildFigure,
        Rez.Drawables.mildFigureWhite,
        Rez.Drawables.mildFigureBlack,
        Rez.Drawables.mildFigureRed
    ];

    // Event Logos
    // N.B. Green colour will not work on 8-bit colour devices
    private var eventLogos as Array<Lang.ResourceId> = [
        Rez.Drawables.eventLogo,
        Rez.Drawables.eventLogoWhite,
        Rez.Drawables.eventLogoBlack,
        Rez.Drawables.eventLogoGreen
    ];

    // Outline Logos for canBurnIn devices
    (:ciq2plus)
    private var outlineLogos as Array<Lang.ResourceId> = [
        Rez.Drawables.mildLogoOutline,
        Rez.Drawables.mildFigureOutline
    ];

    private var timedLogos as Array<Lang.ResourceId> = [
        Rez.Drawables.sundayLogo,
        Rez.Drawables.sundayLogoWhite,
        Rez.Drawables.sundayLogoBlack,
        Rez.Drawables.sundayLogoRed
    ];

    // Implementation for devices on CIQ v2 and greater. 
    // Most noteably includes Properties.getValue() and Application.loadResource() API's. 
    (:ciq2plus)
    function initialize() {
        WatchFace.initialize();

        //check if AMOLED
        var settings=System.getDeviceSettings();
        if(settings has :requiresBurnInProtection) {       
            canBurnIn = settings.requiresBurnInProtection;        	
        }

        // Font for status icons
        iconFont = loadResource(Rez.Fonts.icon_font);

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
        onSettingsChanged();
    }

    // Implementation for devices on CIQ v1. 
    // Cannot use Properties.getValue() and Application.loadResource() API's. 
    // Instead uses Application.getApp().getProperty() and WatchUi.loadResource() respectively.
    (:ciq1)
    function initialize() {
        WatchFace.initialize();
        iconFont = WatchUi.loadResource(Rez.Fonts.icon_font);
        onSettingsChanged();
    }

    //! Load layout
    //! @param dc Draw context
    (:ciq2plus)
    function onLayout(dc as Dc) as Void { 
        // Screen resolution calculations
        height = dc.getHeight();
        width = dc.getWidth();
        centerH = height / 2;
        centerW = width / 2;

        statusModifier = (height > 240) ? 2.5 : 2;

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

    //! Load layout
    //! @param dc Draw context
    (:ciq1)
    function onLayout(dc as Dc) as Void { 
        // Screen resolution calculations
        height = dc.getHeight();
        width = dc.getWidth();

        statusModifier = (height > 240) ? 2.5 : 2;

        // Font size calculations
        xtFontH = dc.getFontHeight(Graphics.FONT_XTINY);

        xtFont = Graphics.FONT_XTINY;
        lgFont = Graphics.FONT_LARGE;
    }

    //! Called when this View is brought to the foreground. Restore
    //! the state of this View and prepare it to be shown. This includes
    //! loading resources into memory.
    function onShow() as Void {
    }

    //! Update the view
    //! @param dc Draw context
    (:ciq2plus)
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

        checkSundayService();

        // Get the current date and format it
        var date = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateString = Lang.format("$1$ $2$", [date.day_of_week.toUpper(), date.day]);

        // Set background Colour (always black in low power mode)
        if (canBurnIn && inLowPower) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        } else {
            dc.setColor(getProperty("BackgroundColor"), getProperty("BackgroundColor"));
        }
        dc.clear();

        // Colour Settings depending on Always-On
        var logoColor;
        if (canBurnIn && inLowPower) {
            dc.setColor(getProperty("AlwaysOnColor"), Graphics.COLOR_TRANSPARENT);
            logoColor = getProperty("AlwaysOnColor") as Graphics.ColorValue;;
        } else {
            dc.setColor(getProperty("TextColor"), Graphics.COLOR_TRANSPARENT);
            logoColor = getProperty("LogoColor") as Graphics.ColorValue;;
        }
        
        // Draw large complications and/or time and date
        if (hasScalable) {
            dc.drawRadialText(centerW, centerH, lgFont, timeString, Graphics.TEXT_JUSTIFY_CENTER, 90, lgR, Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE);
            dc.drawRadialText(centerW, centerH, xtFont, dateString, Graphics.TEXT_JUSTIFY_CENTER, 270, xtR, Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
            if (!inLowPower) {
                dc.drawRadialText(centerW, centerH, xtFont, getCompStr(getProperty("Comp1")), Graphics.TEXT_JUSTIFY_CENTER, 210, xtR, Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);
                dc.drawRadialText(centerW, centerH, xtFont, getCompStr(getProperty("Comp2")), Graphics.TEXT_JUSTIFY_CENTER, 330, xtR, Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE);                
            }
        } else {
            dc.drawText(width / 2, 0, lgFont, timeString, Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(width / 2, height - xtFontH, xtFont, dateString, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Draw icon status bar
        dc.drawText(width / 2, height - statusModifier * xtFontH, iconFont, getStatusString(), Graphics.TEXT_JUSTIFY_CENTER);

        // Draw Mild logo
        if (dc has :drawBitmap2) {
            dc.drawBitmap2(width / logoPM, height / logoPM, logo, {:tintColor=>logoColor});
        } else {
            dc.drawBitmap(width / logoPM, height / logoPM, logo);
        }
    }

    // Implementation for devices on CIQ v1. 
    // Cannot use Properties.getValue() and Application.loadResource() API's. 
    // Instead uses Application.getApp().getProperty() and WatchUi.loadResource() respectively.
    //! Update the view
    //! @param dc Draw context
    (:ciq1)
    function onUpdate(dc as Dc) as Void {
        // Get the current time and date and format it correctly
        var clockTime = System.getClockTime();
        var hours = clockTime.hour;
        if (!System.getDeviceSettings().is24Hour) {
            if (hours > 12) {
                hours = hours - 12;
            }
        } 
        var timeString = Lang.format("$1$:$2$", [hours, clockTime.min.format("%02d")]);
        var date = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateString = Lang.format("$1$ $2$", [date.day_of_week.toUpper(), date.day]);

        checkSundayService();

        // Set background Colour
        dc.setColor(getProperty("BackgroundColor"), getProperty("BackgroundColor"));
        dc.clear();
    
        // Small Complications
        dc.setColor(getProperty("TextColor"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, 0, lgFont, timeString, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(width / 2, height - xtFontH, xtFont, dateString, Graphics.TEXT_JUSTIFY_CENTER);

        // Icon status bar
        dc.drawText(width / 2, height - statusModifier * xtFontH, iconFont, getStatusString(), Graphics.TEXT_JUSTIFY_CENTER);

        // Draw Logo 
        dc.drawBitmap(width / logoPM, height / logoPM, logo);
    }

    //! Called when this View is removed from the screen. Save the
    //! state of this View here. This includes freeing resources from
    //! memory.
    function onHide() {
    }

    //! The user has just looked at their watch. Timers and animations may be started here.
    (:ciq2plus)
    function onExitSleep() {
        inLowPower=false;
        setLogo();
        WatchUi.requestUpdate();
    }

    //! Terminate any active timers and prepare for slow updates.
    (:ciq2plus)
    function onEnterSleep() {
        inLowPower=true;
        setLogo();
        WatchUi.requestUpdate();
    }

    function onSettingsChanged() {
        setLogo();
        showDeviceConnectedIcon = getProperty("DeviceConnectedIndicator");
        showAlarmIcon = getProperty("AlarmIndicator");
        showBatteryIcon = getProperty("BatteryIndicator");
    }

    (:ciq2plus)
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

    (:ciq2plus)
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


    (:hasBitmap2)
    function setLogo() as Void {
        // For devices with Bitmap2, LogoColor's value is a hex value
        var logoType = getProperty("Logo");
        // Automatic Sunday Service Logo
        if (isSundayService) {
            logoPM = 10;            
            logo = loadResource(timedLogos[0]);
        } else {
            if (logoType == 0) {
                // Text Logo
                logoPM = 10;
                if (canBurnIn && inLowPower) {
                    logo = loadResource(outlineLogos[0]);
                } else {
                    logo = loadResource(textLogo[0]);
                }
            } else if (logoType == 1) {
                // Figure Logo
                logoPM = 20;
                if (canBurnIn && inLowPower) {
                    logo = loadResource(outlineLogos[1]);
                } else {
                    logo = loadResource(figureLogos[0]);
                }
            } else {
                // Emporium Event Logo
                logoPM = 10;
                logo = loadResource(eventLogos[0]);
            }
        }
    }

    (:noBitmap2)
    function setLogo() as Void {
        // For devices without Bitmap2, LogoColor's value is an array index instead of a hex value
        var logoIndex = getProperty("LogoColor");
        if (isSundayService) {
            logoPM = 10;            
            logo = loadResource(timedLogos[logoIndex]);
        } else {
            var logoType = getProperty("Logo");
            if (logoType == 0) {
                logoPM = 10;
                logo = loadResource(textLogo[logoIndex]);
            } else if (logoType == 1) { 
                logoPM = 20;
                logo = loadResource(figureLogos[logoIndex]);
            } else {
                logoPM = 10;
                logo = loadResource(eventLogos[logoIndex]);
            }
        }
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

    function checkSundayService() as Void {
        // Check if automatic logos are disabled
        if (getProperty("disableAutomaticLogos")) {
            if (isSundayService) {
                isSundayService = false;
                setLogo();
            }
            return;
        }
        var now = Time.now();
        var dateShort = Time.Gregorian.info(now, Time.FORMAT_SHORT);
        System.print(dateShort.day_of_week);
        if (dateShort.day_of_week == 1 && dateShort.hour > 6 && dateShort.hour < 12) {
            if (!isSundayService){
                isSundayService = true;
                setLogo();
            } 
        } else {
            if(isSundayService){
                isSundayService = false;
                setLogo();
            }
        }
    }

    (:ciq2plus)
    function getProperty(key as String) as Application.PropertyValueType {
        return Properties.getValue(key);
    }

    (:ciq1)
    function getProperty(key as String) as Application.PropertyValueType {
        return Application.getApp().getProperty(key);
    }

    (:ciq2plus)
    function loadResource(id as Lang.ResourceId) {
        return Application.loadResource(id);
    }

    (:ciq1)
    function loadResource(id as Lang.ResourceId) {
        return WatchUi.loadResource(id);
    }
}