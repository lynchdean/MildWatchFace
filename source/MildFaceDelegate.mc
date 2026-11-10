//
// Copyright 2015-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//
import Toybox.WatchUi;
import Toybox.Application;
import Toybox.Application.WatchFaceConfig;
import Toybox.Lang;

//! Delegate for the native on-device watch face editor (fenix 8/9 family,
//! D2 Mach 2, Enduro 3/4, fenix E, fr970, Venu 4, vivoactive 6 - see
//! monkey.jungle's hasWatchFaceConfig annotation for the exact list).
//! These callbacks only fire while the system's native editor is actively
//! open on the watch; normal rendering is unaffected.
(:hasWatchFaceConfig)
class MildFaceDelegate extends WatchUi.WatchFaceDelegate {
    private var _view as MildFaceView;

    function initialize(view as MildFaceView) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    //! Use the system's default highlight for whichever complication is selected.
    function getComplicationDrawable(complication as WatchFaceConfig.ComplicationRef) as WatchUi.Drawable or WatchUi.ComplicationDrawableRef or Null {
        return null;
    }

    //! Let the system handle complication-field selection itself.
    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        return false;
    }

    //! The user changed something in the editor - re-read it and re-render.
    function onWatchFaceConfigEdited(options as { :configId as WatchFaceConfig.Id, :type as WatchUi.WatchFaceConfigType or Null, :committed as Lang.Boolean }) as Void {
        _view.refreshNativeConfig();
        _view.setLogo();
        _view.updateCachedColors();
        _view.updateCachedComplicationStrings();
        WatchUi.requestUpdate();
    }
}
