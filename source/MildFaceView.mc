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
import Toybox.Application.WatchFaceConfig;

const hasScalable = Toybox.Graphics has :getVectorFont;
const hasComplications = Toybox has :Complications;

class MildFaceView extends WatchUi.WatchFace {
private var logo as BitmapReference?;
    private var iconFont;
    
    // Cached position for logo drawing
    private var logoX as Number?;
    private var logoY as Number?;

    // Current logo ID for setLogo
    private var currentLogoId as Lang.ResourceId?;
    
    // Cached time and date strings
    private var cachedTimeString as String?;
    private var cachedDateString as String?;
    private var lastMinute as Number = -1; // Force initial update
    private var lastDay as Number = -1;    // Force initial update
    
    // Cached status string and update tracker
    private var cachedStatusString as String?;
    private var lastStatusUpdate as Number = 0; // Time of last status update
    
    // Cached complication strings
    (:ciq2plus) private var cachedComp1String as String?;
    (:ciq2plus) private var cachedComp2String as String?;
    (:ciq2plus) private var lastCompUpdate as Number = 0; // Time of last complication update
    
    // Cached color values
    private var cachedBackgroundColor as Graphics.ColorValue?;
    private var cachedTextColor as Graphics.ColorValue?;
    private var cachedLogoColor = Graphics.COLOR_WHITE; // Default value
    (:ciq2plus) private var cachedAlwaysOnColor as Graphics.ColorValue?;
    
    // Cached text positions
    private var timeTextX, timeTextY;
    private var dateTextX, dateTextY;
    private var statusTextX, statusTextY;

    // Time based toggles
    private var isSundayService = false;
    private var nextSundayCheckTime = 0; // Time (in seconds) when we next need to check Sunday service state

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

    // Trails Logos
    private var trailsLogos as Array<Lang.ResourceId> = [
        Rez.Drawables.trailsLogo,
        Rez.Drawables.trailsLogoWhite,
        Rez.Drawables.trailsLogoBlack,
        Rez.Drawables.trailsLogoRed
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

    function initialize() {
        WatchFace.initialize();
        
        // Set default fonts - these don't depend on screen dimensions
        xtFont = Graphics.FONT_XTINY;
        lgFont = Graphics.FONT_LARGE;
        
        // Load the icon font using the appropriate method
        iconFont = loadResource(Rez.Fonts.icon_font);
        
        // Initialize nextSundayCheckTime to force an immediate check
        nextSundayCheckTime = 0;
        
        // Check Sunday service state immediately during initialization
        checkSundayService();
        
        // Initialize all cached strings and values
        updateTimeAndDateStrings();
        updateCachedStatus();
        updateCachedColors();
        initCIQ2Features();
        
        // Apply settings (which also handles logo loading)
        onSettingsChanged();
    }
    
    // Helper function to update time and date strings efficiently
    function updateTimeAndDateStrings() {
        var clockTime = System.getClockTime();

        // Only update the time (and check the date) if the minute has changed.
        // The date can only change when the minute changes (at 00:00), so nesting
        // the Gregorian.info() lookup here avoids calling it every second during
        // onPartialUpdate (it was previously recalculated on every call).
        if (lastMinute != clockTime.min) {
            lastMinute = clockTime.min;

            // Format the time string
            var hours = clockTime.hour;
            if (!System.getDeviceSettings().is24Hour) {
                if (hours > 12) {
                    hours = hours - 12;
                } else if (hours == 0) {
                    hours = 12;
                }
            }
            cachedTimeString = Lang.format("$1$:$2$", [hours, clockTime.min.format("%02d")]);

            // Only update the date string if the day has changed
            var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            if (lastDay != today.day) {
                lastDay = today.day;
                cachedDateString = Lang.format("$1$ $2$", [today.day_of_week.toUpper(), today.day]);
            }
        }
    }
    
    // CIQ2+ specific initialization function
    (:ciq2plus)
    function initCIQ2Features() {
        // Check if device has AMOLED screen with burn-in protection
        var settings = System.getDeviceSettings();
        if(settings has :requiresBurnInProtection) {       
            canBurnIn = settings.requiresBurnInProtection;
            
            // Initialize AlwaysOnColor once - this doesn't change with settings
            cachedAlwaysOnColor = getProperty("AlwaysOnColor") as Graphics.ColorValue;
        }

        // Set up complications if supported
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
    
    (:ciq1)
    function initCIQ2Features() {
        // No CIQ2+ features available
    }

    //! Load layout - unified implementation for both CIQ1 and CIQ2+
    //! @param dc Draw context
    function onLayout(dc as Dc) as Void { 
        // Common screen resolution calculations
        height = dc.getHeight();
        width = dc.getWidth();
        
        // Status modifier based on screen size
        statusModifier = (height > 240) ? 2.5 : 2;
        
        // Font size calculations
        xtFontH = dc.getFontHeight(Graphics.FONT_XTINY);
        
        // Set default fonts
        xtFont = Graphics.FONT_XTINY;
        lgFont = Graphics.FONT_LARGE;
        
        // Pre-calculate text positions
        timeTextX = width / 2;
        timeTextY = 0;
        dateTextX = width / 2;
        dateTextY = height - xtFontH;
        statusTextY = height - statusModifier * xtFontH;
        statusTextX = width / 2;
        
        setLogo();

        // Call CIQ2+ specific layout calculations
        initCIQ2Layout(dc);
    }
    
    // CIQ2+ specific layout calculations
    (:ciq2plus)
    function initCIQ2Layout(dc as Dc) {
        // Additional screen calculations for CIQ2+
        centerH = height / 2;
        centerW = width / 2;
        
        // Additional font calculations for CIQ2+
        lgFontH = dc.getFontHeight(Graphics.FONT_LARGE);
        
        // Use vector fonts if available
        if (hasScalable) {
            xtFont = Graphics.getVectorFont({:face=>["RobotoCondensedBold","RobotoRegular"], :size=>xtFontH});
            lgFont = Graphics.getVectorFont({:face=>["RobotoCondensedBold","RobotoRegular"], :size=>lgFontH});
            xtR = centerH - Graphics.getFontDescent(xtFont);
            lgR = centerH - Graphics.getFontAscent(lgFont);
        }
    }

    // Empty implementation for CIQ1 devices
    (:ciq1)
    function initCIQ2Layout(dc as Dc) {
        // No CIQ2+ specific layout needed for CIQ1 devices
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
        // Get current time once to minimize system calls
        var currentTime = Time.now().value();
        
        // Update time and date strings if needed
        updateTimeAndDateStrings();
        
        // Check for Sunday service when needed
        checkSundayService();
        
        // Update cached status string every 30 seconds
        if (cachedStatusString == null || (currentTime - lastStatusUpdate) > 30) {
            updateCachedStatus();
        }

        // Update cached complication strings every 5 seconds
        if (cachedComp1String == null || cachedComp2String == null || (currentTime - lastCompUpdate) > 5) {
            updateCachedComplicationStrings();
        }

        // Copy frequently-used member variables into locals once per call.
        // Local variable access is significantly faster than member variable
        // access in Monkey C, so this avoids repeated lookups below.
        var statusString = cachedStatusString;
        var comp1String = cachedComp1String;
        var comp2String = cachedComp2String;

        // Cache the low power state to avoid repeated checks
        var isLowPower = canBurnIn && inLowPower;
        
        // Set background color (always black in low power mode)
        if (isLowPower) {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        } else {
            dc.setColor(cachedBackgroundColor, cachedBackgroundColor);
        }
        dc.clear();

        // Color settings depending on power mode
        var logoColor;
        var textColor;
        if (isLowPower) {
            textColor = cachedAlwaysOnColor;
            logoColor = cachedAlwaysOnColor;
        } else {
            textColor = cachedTextColor;
            logoColor = cachedLogoColor;
        }
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        
        // Text justification used in all drawing operations
        var textJustify = Graphics.TEXT_JUSTIFY_CENTER;
        
        // Draw large complications and/or time and date
        if (hasScalable) {
            // For scalable fonts, draw using radial text
            // Cache direction parameters to optimize drawing calls
            var cwDir = Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE;
            var ccwDir = Graphics.RADIAL_TEXT_DIRECTION_COUNTER_CLOCKWISE;
            
            // Draw time and date (always shown)
            dc.drawRadialText(centerW, centerH, lgFont, cachedTimeString, textJustify, 90, lgR, cwDir);
            dc.drawRadialText(centerW, centerH, xtFont, cachedDateString, textJustify, 270, xtR, ccwDir);
            
            // Only draw complications in normal power mode
            if (!isLowPower && comp1String != null && comp2String != null) {
                dc.drawRadialText(centerW, centerH, xtFont, comp1String, textJustify, 210, xtR, ccwDir);
                dc.drawRadialText(centerW, centerH, xtFont, comp2String, textJustify, 330, xtR, ccwDir);
            }
        } else {
            // For regular fonts, use standard text drawing
            dc.drawText(timeTextX, timeTextY, lgFont, cachedTimeString, textJustify);
            dc.drawText(dateTextX, dateTextY, xtFont, cachedDateString, textJustify);
        }

        // Draw icon status bar using cached status string
        var statusJustify = Graphics.TEXT_JUSTIFY_CENTER;
        if (statusString.length() > 0) {
            dc.drawText(statusTextX, statusTextY, iconFont, statusString, statusJustify);
        }

        // Draw Mild logo if available
        if (logo != null) {
            drawLogo(dc, logoColor);
        }
    }

    // Implementation for devices on CIQ v1. 
    // Cannot use Properties.getValue() and Application.loadResource() API's. 
    // Instead uses Application.getApp().getProperty() and WatchUi.loadResource() respectively.
    //! Update the view
    //! @param dc Draw context
    (:ciq1)
    function onUpdate(dc as Dc) as Void {
        // Get current time once to minimize system calls
        var currentTime = Time.now().value();
        
        // Update time and date strings if needed
        updateTimeAndDateStrings();
        
        // Check for Sunday service when needed
        checkSundayService();
        
        // Update cached status string every 30 seconds
        if (cachedStatusString == null || (currentTime - lastStatusUpdate) > 30) {
            updateCachedStatus();
        }

        // Set background Color
        dc.setColor(cachedBackgroundColor, cachedBackgroundColor);
        dc.clear();
    
        // Draw time and date with cached values
        var justify = Graphics.TEXT_JUSTIFY_CENTER;
        dc.setColor(cachedTextColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(timeTextX, timeTextY, lgFont, cachedTimeString, justify);
        dc.drawText(dateTextX, dateTextY, xtFont, cachedDateString, justify);

        // Draw icon status bar only if there are icons to display
        if (cachedStatusString.length() > 0) {
            dc.drawText(statusTextX, statusTextY, iconFont, cachedStatusString, justify);
        }

        // Draw Logo if available
        if (logo != null) {
            dc.drawBitmap(logoX, logoY, logo);
        }
    }

    //! Called when this View is removed from the screen. Save the
    //! state of this View here. This includes freeing resources from
    //! memory.
    function onHide() {
    }

    //! Handle partial updates for more efficiency on supported devices
    //! @param dc Draw context
    (:ciq2plus)
    function onPartialUpdate(dc as Dc) as Void {
        // Store previous time string to check if it actually changed
        var prevTimeString = cachedTimeString;
        
        // Update time string efficiently using our helper method
        updateTimeAndDateStrings();
        
        // Only redraw if time has changed (saves battery by avoiding identical redraws)
        if (cachedTimeString != prevTimeString) {
            // Set text color based on power mode
            var textColor = (canBurnIn && inLowPower) ? cachedAlwaysOnColor : cachedTextColor;
            dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
            
            // Draw time using partial update - efficient rendering
            var textJustify = Graphics.TEXT_JUSTIFY_CENTER;
            if (hasScalable) {
                dc.drawRadialText(centerW, centerH, lgFont, cachedTimeString, textJustify, 90, lgR, Graphics.RADIAL_TEXT_DIRECTION_CLOCKWISE);
            } else {
                dc.drawText(timeTextX, timeTextY, lgFont, cachedTimeString, textJustify);
            }
        }
        
        // No need to call requestUpdate() here since the system manages partial updates
    }
    
    //! The user has just looked at their watch. Timers and animations may be started here.
    (:ciq2plus)
    function onExitSleep() {
        inLowPower = false;
        
        // Update logo and colors for normal power mode
        setLogo();
        updateCachedColors();
        
        // Force an immediate full update to restore normal display
        WatchUi.requestUpdate();
    }

    //! Terminate any active timers and prepare for slow updates.
    (:ciq2plus)
    function onEnterSleep() {
        inLowPower = true;
        
        // Update logo and colors for low power mode
        setLogo();
        updateCachedColors();
        
        // Trigger an update to apply power saving mode changes
        WatchUi.requestUpdate();
    }

    function updateCachedColors() {
        cachedBackgroundColor = getProperty("BackgroundColor") as Graphics.ColorValue;
        cachedTextColor = getTextColorSetting();
        cachedLogoColor = getLogoColorSetting();
    }

    // Native watch face editor's "Data Color" overrides TextColor when the
    // user has created an on-device config; otherwise falls back to the
    // classic Properties-based setting.
    (:hasWatchFaceConfig)
    function getTextColorSetting() as Graphics.ColorValue {
        if (nativeConfigSettings != null && nativeConfigSettings.complicationColor != null && nativeConfigSettings.complicationColor.color != null) {
            return nativeConfigSettings.complicationColor.color as Graphics.ColorValue;
        }
        return getProperty("TextColor") as Graphics.ColorValue;
    }

    (:noWatchFaceConfig)
    function getTextColorSetting() as Graphics.ColorValue {
        return getProperty("TextColor") as Graphics.ColorValue;
    }

    // Native watch face editor's "Accent Color" overrides LogoColor the same way.
    (:hasWatchFaceConfig)
    function getLogoColorSetting() as Graphics.ColorValue {
        if (nativeConfigSettings != null && nativeConfigSettings.accentColor != null && nativeConfigSettings.accentColor.color != null) {
            return nativeConfigSettings.accentColor.color as Graphics.ColorValue;
        }
        return getProperty("LogoColor") as Graphics.ColorValue;
    }

    (:noWatchFaceConfig)
    function getLogoColorSetting() as Graphics.ColorValue {
        return getProperty("LogoColor") as Graphics.ColorValue;
    }

    // Native watch face editor's "Style" overrides the Logo type the same way.
    // Only ever relevant on (:hasBitmap2) devices - every hasWatchFaceConfig
    // device is also a hasBitmap2 device.
    (:hasWatchFaceConfig)
    function getLogoTypeSetting() as Number {
        if (nativeConfigSettings != null && nativeConfigSettings.styleId != null) {
            return nativeConfigSettings.styleId;
        }
        return getProperty("Logo");
    }

    (:noWatchFaceConfig)
    function getLogoTypeSetting() as Number {
        return getProperty("Logo");
    }

    // Caches the active native watch face config (if any) so the getters
    // above don't call WatchFaceConfig.getSettings() on every draw.
    (:hasWatchFaceConfig) private var nativeConfigSettings as WatchFaceConfig.Settings?;

    (:hasWatchFaceConfig)
    function refreshNativeConfig() as Void {
        nativeConfigSettings = WatchFaceConfig.getSettings(null);
    }

    (:noWatchFaceConfig)
    function refreshNativeConfig() as Void {
        // No native editor on this device - nothing to read.
    }
    
    (:ciq2plus)
    function updateCachedStatus() {
        cachedStatusString = getStatusString();
        lastStatusUpdate = Time.now().value();
    }
    
    (:ciq1)
    function updateCachedStatus() {
        cachedStatusString = getStatusString();
        // No timestamp on CIQ1
    }
    
    // Update complication strings periodically to avoid recalculation on every frame
    (:ciq2plus)
    function updateCachedComplicationStrings() {
        cachedComp1String = getCompStr(getComplicationSetting(1));
        cachedComp2String = getCompStr(getComplicationSetting(2));
        lastCompUpdate = Time.now().value();
    }

    // Native watch face editor's Data slots (uniqueIdentifier 1/2, matching
    // resources/settings/watchface-config.xml) override Comp1/Comp2 when a
    // user-created on-device config is active.
    (:hasWatchFaceConfig)
    function getComplicationSetting(slotId as Number) as Number {
        if (nativeConfigSettings != null && nativeConfigSettings.complicationSettings != null) {
            var refs = nativeConfigSettings.complicationSettings;
            for (var i = 0; i < refs.size(); i++) {
                var ref = refs[i];
                if (ref.uniqueIdentifier == slotId && ref.complicationId != null) {
                    var n = complicationIdToNumber(ref.complicationId);
                    if (n != null) {
                        return n;
                    }
                }
            }
        }
        return getProperty(slotId == 1 ? "Comp1" : "Comp2");
    }

    (:hasWatchFaceConfig)
    function complicationIdToNumber(id as Complications.Id) as Number? {
        if (id.equals(new Complications.Id(Complications.COMPLICATION_TYPE_BATTERY))) { return 1; }
        if (id.equals(new Complications.Id(Complications.COMPLICATION_TYPE_HEART_RATE))) { return 2; }
        if (id.equals(new Complications.Id(Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE))) { return 3; }
        if (id.equals(new Complications.Id(Complications.COMPLICATION_TYPE_STEPS))) { return 4; }
        if (id.equals(new Complications.Id(Complications.COMPLICATION_TYPE_CALORIES))) { return 5; }
        return null;
    }

    (:noWatchFaceConfig)
    function getComplicationSetting(slotId as Number) as Number {
        return getProperty(slotId == 1 ? "Comp1" : "Comp2");
    }

    function onSettingsChanged() {
        // Always check Sunday service state when settings change to ensure correct logo
        refreshNativeConfig();
        checkSundayService();
        setLogo();
        updateCachedColors();
        showDeviceConnectedIcon = getProperty("DeviceConnectedIndicator");
        showAlarmIcon = getProperty("AlarmIndicator");
        showBatteryIcon = getProperty("BatteryIndicator");
    }

    // Complications callback is the only system callback available
    (:ciq2plus)
    function onComplicationUpdated(complicationId as Complications.Id) as Void {
        var valueChanged = false;
        
        if (complicationId.equals(hrId)) {
            var newHr = Complications.getComplication(complicationId).value;
            valueChanged = (newHr != curHr);
            curHr = newHr;
        } else if (complicationId.equals(tempId)) {
            var newTemp = Complications.getComplication(complicationId).value;
            valueChanged = (newTemp != curTemp);
            curTemp = newTemp;
        } else if (complicationId.equals(stepsId)) {
            var newSteps = Complications.getComplication(complicationId).value;
            valueChanged = (newSteps != curSteps);
            curSteps = newSteps;
        } else if (complicationId.equals(calsId)) {
            var newCals = Complications.getComplication(complicationId).value;
            valueChanged = (newCals != curCals);
            curCals = newCals;
        }
        
        // If values have changed, update the cached complication strings
        if (valueChanged) {
            updateCachedComplicationStrings();
            WatchUi.requestUpdate(); // Request a UI update to show the new values
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
        var logoType = getLogoTypeSetting();
        var newLogoId;
        var logoPositionFactor = 10; // Default for most logos
        
        // Automatic Sunday Service Logo
        if (isSundayService) {
            newLogoId = timedLogos[0];
            // Sunday service uses text logo sizing (1/10th of screen)
        } else {
            if (logoType == 0) {
                // Text Logo
                if (canBurnIn && inLowPower) {
                    newLogoId = outlineLogos[0];
                } else {
                    newLogoId = textLogo[0];
                }
            } else if (logoType == 1) {
                // Figure Logo
                logoPositionFactor = 20; // Figure logo uses 1/20th positioning
                if (canBurnIn && inLowPower) {
                    newLogoId = outlineLogos[1];
                } else {
                    newLogoId = figureLogos[0];
                }
            } else if (logoType == 2) {
                // Trails Event Logo
                newLogoId = trailsLogos[0];
            } else {
                // Emporium Event Logo
                newLogoId = eventLogos[0];
            }
        }

        // Always calculate position if width/height are available
        if (width != null) {
            logoX = width / logoPositionFactor;
            logoY = height / logoPositionFactor;
        }
        
        // Only load resource if the logo has changed
        if (currentLogoId == null || currentLogoId != newLogoId) {
            currentLogoId = newLogoId;
            logo = loadResource(newLogoId);
        }
    }

    (:noBitmap2)
    function setLogo() as Void {
        // For devices without Bitmap2, LogoColor's value is an array index instead of a hex value
        var logoIndex = getProperty("LogoColor");
        var newLogoId;
        
        var logoPositionFactor = 10; // Default for most logos
        
        if (isSundayService) {
            newLogoId = timedLogos[logoIndex];
            // Sunday service uses text logo sizing (1/10th of screen)
        } else {
            var logoType = getProperty("Logo");
            if (logoType == 0) {
                newLogoId = textLogo[logoIndex];
            } else if (logoType == 1) { 
                logoPositionFactor = 20; // Figure logo uses 1/20th positioning
                newLogoId = figureLogos[logoIndex];
            } else if (logoType == 2) {
                newLogoId = trailsLogos[logoIndex];
            } else {
                newLogoId = eventLogos[logoIndex];
            }
        }

        // Always calculate position if width/height are available
        if (width != null) {
            logoX = width / logoPositionFactor;
            logoY = height / logoPositionFactor;
        }
        
        // Only load resource if the logo has changed
        if (currentLogoId == null || currentLogoId != newLogoId) {
            currentLogoId = newLogoId;
            logo = loadResource(newLogoId);
        }
    }

    // Draws the cached logo bitmap. Split by the same hasBitmap2/noBitmap2
    // annotations used by setLogo() so the drawBitmap2 capability (which
    // never changes at runtime for a given device) is resolved at compile
    // time instead of via a "dc has :drawBitmap2" check on every onUpdate call.
    (:hasBitmap2)
    function drawLogo(dc as Dc, logoColor) as Void {
        dc.drawBitmap2(logoX, logoY, logo, {:tintColor=>logoColor});
    }

    (:noBitmap2)
    function drawLogo(dc as Dc, logoColor) as Void {
        dc.drawBitmap(logoX, logoY, logo);
    }

    function getStatusString() as String {
        // Pre-allocate array with maximum expected size (3 characters)
        // This is faster than string concatenation according to Garmin optimization guidelines
        var statusChars = ["", "", ""];
        var index = 0;
        
        // Cache device settings to avoid repeated lookups
        var deviceSettings = System.getDeviceSettings();
        
        if (showDeviceConnectedIcon && deviceSettings.phoneConnected) {
            statusChars[index] = "4";
            index++;
        }
        
        if (showAlarmIcon && deviceSettings.alarmCount) {
            statusChars[index] = "0";
            index++;
        }
        
        if (showBatteryIcon) {
            var bat = System.getSystemStats().battery;
            if (bat > 66) {
                statusChars[index] = "1";
            } else if (bat > 15) {
                statusChars[index] = "2";
            } else {
                statusChars[index] = "3";
            }
            index++;
        }
        
        // Join the characters into a single string efficiently
        return index == 3 ? statusChars[0] + statusChars[1] + statusChars[2] : 
               index == 2 ? statusChars[0] + statusChars[1] : 
               index == 1 ? statusChars[0] : "";
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

        // Get current time in seconds since epoch
        var now = Time.now().value();
        
        // Only perform the check if we've reached the next scheduled check time
        if (now >= nextSundayCheckTime) {
            var dateInfo = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var isSunday = dateInfo.day_of_week == 1;
            var hour = dateInfo.hour;
            var isServiceTime = isSunday && hour >= 6 && hour < 12;
            
            // Update the logo if the Sunday service state has changed
            if (isServiceTime != isSundayService) {
                isSundayService = isServiceTime;
                setLogo();
            }
            
            // Determine when to check next based on current time
            var checkInterval;
            
            if (isSunday) {
                if (hour < 6) {
                    // Before service hours - check at 6am
                    checkInterval = ((6 - hour) * 3600) - (dateInfo.min * 60 + dateInfo.sec);
                } else if (hour < 11) {
                    // During early service hours - check every 30 minutes
                    checkInterval = 30 * 60;
                } else if (hour < 12) {
                    // Near end of service (11 AM - 12 PM) - check every 5 minutes for prompt end detection
                    checkInterval = 5 * 60;
                } else {
                    // After service hours - check next day
                    checkInterval = 24 * 3600; 
                }
            } else {
                // Not Sunday - use a longer interval, check once per day
                // This is simpler and more efficient than calculating exact time to next Sunday
                checkInterval = 24 * 3600;
            }
            
            nextSundayCheckTime = now + checkInterval;
        }
    }

    (:ciq2plus)
    function getProperty(key as String) as Application.PropertyValueType {
        return Properties.getValue(key);
    }

    (:ciq1)
    function getProperty(key as String) as Application.PropertyValueType {
        // Note: This uses deprecated API but is necessary for CIQ1 compatibility
        // The warning is expected and cannot be avoided for CIQ1 backward compatibility
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