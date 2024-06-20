//
// Copyright 2015-2021 by Garmin Ltd. or its subsidiaries.
// Subject to Garmin SDK License Agreement and Wearables
// Application Developer Agreement.
//
import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;

//! App class for the TypedFace
class MildFaceApp extends Application.AppBase {

    var _view;

    //! Constructor
    function initialize() {
        AppBase.initialize();
    }

    //! onStart() is called on application start up
    //! @param state Start parameters
    function onStart(state as Dictionary?) {
    }

    //! onStop() is called when your application is exiting
    //! @param state Stop parameters
    function onStop(state as Dictionary?) {
    }

    //! Return the initial view of your application here
    function getInitialView() {
        _view = new MildFaceView();
        return [ _view ];
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() as Void {
        _view.onSettingsChanged();
        WatchUi.requestUpdate();
    }
}