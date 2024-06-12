//
// Copyright 2015-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
import Toybox.Application;

import Complicated;

//! Main watch face view
class MildFaceView extends WatchUi.WatchFace {
    // We can't initialize time label in the initializer
    // so it has to be declared as accepting null
    private var _timeLabel as Text?;  
    private var _complications as Array<ComplicationDrawable>;
    private var _mildLogo as BitmapReference?;

    //! Constructor
    function initialize() {
        WatchFace.initialize();
        _complications = new Array<ComplicationDrawable>[3];
    }

    //! Load layout
    //! @param dc Draw context
    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.WatchFace(dc));

        _timeLabel = View.findDrawableById("TimeLabel") as Text;
        
        setMildLogo();
        setComplications();
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
        var timeFormat = "$1$:$2$";
        var clockTime = System.getClockTime();
        var hours = clockTime.hour;
        if (!System.getDeviceSettings().is24Hour) {
            if (hours > 12) {
                hours = hours - 12;
            }
        } else {
            if (Properties.getValue("UseMilitaryFormat")) {
                timeFormat = "$1$$2$";
                hours = hours.format("%02d");
            }
        }
        var timeString = Lang.format(timeFormat, [hours, clockTime.min.format("%02d")]);

        // Update the view
        _timeLabel.setColor(Properties.getValue("TextColor"));
        _timeLabel.setText(timeString);

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);

        // Draw Mild logo
        dc.drawBitmap(0, 0, _mildLogo);
    }


    //Formula for your curved line
    function formula(x) {
        var y = 20 * Math.sin(x / 30f);
        return y;
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

    function setMildLogo() {
        // Set Mild Logo colour
        var mildColor = Properties.getValue("MildColor");
        if (mildColor != null) {
            switch (mildColor) {
                case 1:
                    // Black
                    _mildLogo = Application.loadResource(Rez.Drawables.mildBlack);
                    break;
                case 2:
                    // Olive
                    _mildLogo = Application.loadResource(Rez.Drawables.mildOlive);
                    break;
                case 3:
                    // Yellow
                    _mildLogo = Application.loadResource(Rez.Drawables.mildYellow);
                    break;
                case 4:
                    // Lavender
                    _mildLogo = Application.loadResource(Rez.Drawables.mildLavender);
                    break;
                case 5:
                    // Spice
                    _mildLogo = Application.loadResource(Rez.Drawables.mildSpice);
                    break;
                default:
                // White
                    _mildLogo = Application.loadResource(Rez.Drawables.mildWhite);
            }
        } else {
            // A quick test suggests null isn't handled by switch cases so this is just to be safe.
            // Default to white as default background is black.
            _mildLogo = Application.loadResource(Rez.Drawables.mildWhite);
        }
    }

    function setComplications() {
        _complications[0] = View.findDrawableById("Complication1") as ComplicationDrawable;
        var prop = Properties.getValue("Complication1");
        _complications[0].setModelUpdater(Complicated.getComplication(prop));

        _complications[1] = View.findDrawableById("Complication2") as ComplicationDrawable;    
        prop = Properties.getValue("Complication2");
        _complications[1].setModelUpdater(Complicated.getComplication(prop));

        _complications[2] = View.findDrawableById("Complication3") as ComplicationDrawable;    
        prop = Properties.getValue("Complication3");
        _complications[2].setModelUpdater(Complicated.getComplication(prop));
    }
}
