//
// Copyright 2015-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//
import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;

//! App class for the Mild Watch Face
class MildFaceApp extends Application.AppBase {

    private var _view;

    //! Constructor
    function initialize() {
        AppBase.initialize();
    }

    //! Return the initial view of your application here
    (:noWatchFaceConfig)
    function getInitialView() {
        _view = new MildFaceView();
        return [ _view ];
    }

    //! On devices with the native watch face editor, also return a
    //! delegate so the system can drive editor interactions.
    (:hasWatchFaceConfig)
    function getInitialView() {
        _view = new MildFaceView();
        return [ _view, new MildFaceDelegate(_view) ];
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() as Void {
        _view.onSettingsChanged();
        WatchUi.requestUpdate();
    }
}