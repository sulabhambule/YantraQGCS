import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlightMap
import QGroundControl.FlyView
import QGroundControl.PlanView
import QGroundControl.Toolbar
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

/// @brief Native QML top level window
/// All properties defined here are visible to all QML pages.
ApplicationWindow {
    id: mainWindow

    property int _closeChecksToSkip: 0
    property bool _forceClose: false

    // Analyze page items (both in-panel and popped-out windows) are created with mainWindow as their
    // QObject parent so their lifetime is not tied to AnalyzeView. This lets a popped-out window
    // survive AnalyzeView being unloaded from the tool drawer.

    // Tracks the analyze page item currently shown inside AnalyzeView's panel (not popped out).
    // null when no page is loaded or the item has been handed off to a popup window.
    property var _inPanelAnalyzePage: null
    property bool _reentrantCloseGuard: false
    readonly property int _skipActiveConnectionsCheckMask: 0x04
    readonly property int _skipPendingParameterWritesCheckMask: 0x02

    // Check for things which should prevent the app from closing
    //  Returns true if it is OK to close
    readonly property int _skipUnsavedMissionCheckMask: 0x01
    readonly property real _topBottomMargins: ScreenTools.defaultFontPixelHeight * 0.5
    property bool suppressCriticalVehicleMessages: false

    //-------------------------------------------------------------------------
    //-- Actions

    signal armVehicleRequest
    signal disarmVehicleRequest
    signal forceArmVehicleRequest
    signal showPreFlightChecklistIfNeeded
    signal vtolTransitionToFwdFlightRequest
    signal vtolTransitionToMRFlightRequest

    // This variant is only meant to be called by QGCApplication
    function _showMessageDialog(dialogTitle, dialogText) {
        _showMessageDialogWorker(mainWindow, dialogTitle, dialogText);
    }

    //-------------------------------------------------------------------------
    //-- Global simple message dialog

    function _showMessageDialogWorker(owner, dialogTitle, dialogText, buttons = Dialog.Ok, acceptFunction = null, closeFunction = null, bypassNavigationCheck = false) {
        let dialog = simpleMessageDialogComponent.createObject(owner, {
            title: dialogTitle,
            text: dialogText,
            buttons: buttons,
            acceptFunction: acceptFunction,
            closeFunction: closeFunction,
            bypassNavigationCheck: bypassNavigationCheck
        });
        dialog.open();
    }

    // This variant is only meant to be called by QGCApplication. Ok reboots the active vehicle.
    function _showRebootVehicleDialog(dialogTitle, dialogText) {
        _showMessageDialogWorker(mainWindow, dialogTitle, dialogText + " " + qsTr("Click Ok to reboot the vehicle now."), Dialog.Ok | Dialog.Cancel, function () {
            const activeVehicle = QGroundControl.multiVehicleManager.activeVehicle;
            if (activeVehicle) {
                activeVehicle.rebootVehicle();
            }
        });
    }

    //-------------------------------------------------------------------------
    //-- Global Scope Functions

    // This function is used to prevent view switching if there are validation errors
    function allowViewSwitch(previousValidationErrorCount = 0, showErrorOnDisallow = true) {
        // Check for explicit navigation block (e.g. calibration in progress)
        if (globals.navigationBlockedReason !== "") {
            if (showErrorOnDisallow) {
                validationErrorToast.text = globals.navigationBlockedReason;
                if (validationErrorToast.visible) {
                    validationErrorToast.close();
                }
                validationErrorToast.open();
            }
            return false;
        }
        // Run validation on active focus control to ensure it is valid before switching views
        if (mainWindow.activeFocusControl instanceof FactTextField) {
            mainWindow.activeFocusControl._onEditingFinished();
        }
        var allowed = globals.validationErrorCount <= previousValidationErrorCount;
        if (!allowed && showErrorOnDisallow) {
            validationErrorToast.text = qsTr("Please correct the invalid value before continuing");
            if (validationErrorToast.visible) {
                validationErrorToast.close();
            }
            validationErrorToast.open();
        }
        return allowed;
    }

    // Called by AnalyzeView when the in-panel item is handed off to a popup window.
    // Clears _inPanelAnalyzePage so destroyInPanelAnalyzePage() does not destroy it
    // when AnalyzeView is torn down.
    function analyzePageMovedToPopup() {
        _inPanelAnalyzePage = null;
    }

    function checkForActiveConnections() {
        if (QGroundControl.multiVehicleManager.activeVehicle) {
            let accepted = false;
            _reentrantCloseGuard = true;
            _showMessageDialogWorker(mainWindow, qsTr("Active Vehicle Connections"), qsTr("There are still active connections to vehicles. Are you sure you want to exit?"), Dialog.Yes | Dialog.No, function () {
                accepted = true;
                _closeChecksToSkip |= _skipActiveConnectionsCheckMask;
                performCloseChecks();
            }, function () {
                if (!accepted)
                    _reentrantCloseGuard = false;
            }, true /* bypassNavigationCheck */);
            return false;
        } else {
            return true;
        }
    }

    function checkForPendingParameterWrites() {
        for (var index = 0; index < QGroundControl.multiVehicleManager.vehicles.count; index++) {
            if (QGroundControl.multiVehicleManager.vehicles.get(index).parameterManager.pendingWrites) {
                let accepted = false;
                _reentrantCloseGuard = true;
                _showMessageDialogWorker(mainWindow, qsTr("Pending Parameter Updates"), qsTr("You have pending parameter updates to a vehicle. If you close you will lose changes. Are you sure you want to close?"), Dialog.Yes | Dialog.No, function () {
                    accepted = true;
                    _closeChecksToSkip |= _skipPendingParameterWritesCheckMask;
                    performCloseChecks();
                }, function () {
                    if (!accepted)
                        _reentrantCloseGuard = false;
                }, true /* bypassNavigationCheck */);
                return false;
            }
        }
        return true;
    }

    function checkForUnsavedMission() {
        // Only warn when edits are neither saved to disk nor uploaded to the vehicle.
        // If either happened the edits are recoverable, so closing loses nothing.
        // With no active vehicle an upload can't have happened, so treat the plan as
        // not uploaded regardless of dirtyForUpload.
        if (planView._planMasterController.dirtyForSave && (planView._planMasterController.dirtyForUpload || !QGroundControl.multiVehicleManager.activeVehicle)) {
            let accepted = false;
            _reentrantCloseGuard = true;
            _showMessageDialogWorker(mainWindow, qsTr("Unsaved Mission"), qsTr("You have a mission edit in progress which has not been saved/uploaded. If you close you will lose changes. Are you sure you want to close?"), Dialog.Yes | Dialog.No, function () {
                accepted = true;
                _closeChecksToSkip |= _skipUnsavedMissionCheckMask;
                performCloseChecks();
            }, function () {
                if (!accepted)
                    _reentrantCloseGuard = false;
            }, true /* bypassNavigationCheck */);
            return false;
        } else {
            return true;
        }
    }

    function closeIndicatorDrawer() {
        indicatorDrawer.close();
    }

    // Called by AnalyzeView to create an analyze page item owned by mainWindow.
    // The caller sets the visual parent to panelContainer after creation.
    function createAnalyzePage(source) {
        if (_inPanelAnalyzePage) {
            _inPanelAnalyzePage.destroy();
            _inPanelAnalyzePage = null;
        }
        var component = Qt.createComponent(source);
        if (component.status !== Component.Ready) {
            console.warn("createAnalyzePage failed source:", source, "errorString:", component.errorString());
            return null;
        }
        _inPanelAnalyzePage = component.createObject(mainWindow);
        return _inPanelAnalyzePage;
    }

    function createWindowedAnalyzePage(title, source, requiresVehicle, existingItem) {
        var windowedPage = windowedAnalyzePage.createObject(mainWindow);
        windowedPage.title = title;
        windowedPage.requiresVehicle = requiresVehicle;
        if (existingItem) {
            windowedPage.adoptItem(existingItem);
        } else {
            windowedPage.source = source;
        }
        windowedPage.visible = true;
    }

    // Called by AnalyzeView.Component.onDestruction to destroy the in-panel item while
    // panelContainer is still alive.
    function destroyInPanelAnalyzePage() {
        if (_inPanelAnalyzePage) {
            _inPanelAnalyzePage.destroy();
            _inPanelAnalyzePage = null;
        }
    }

    function finishCloseProcess() {
        _forceClose = true;
        // For some reason on the Qml side Qt doesn't automatically disconnect a signal when an object is destroyed.
        // So we have to do it ourselves otherwise the signal flows through on app shutdown to an object which no longer exists.
        firstRunPromptManager.clearNextPromptSignal();
        QGroundControl.linkManager.shutdown();
        QGroundControl.videoManager.stopVideo();
        mainWindow.close();
    }

    function performCloseChecks() {
        if (!(_closeChecksToSkip & _skipUnsavedMissionCheckMask) && !checkForUnsavedMission()) {
            return false;
        }
        if (!(_closeChecksToSkip & _skipPendingParameterWritesCheckMask) && !checkForPendingParameterWrites()) {
            return false;
        }
        if (!(_closeChecksToSkip & _skipActiveConnectionsCheckMask) && !checkForActiveConnections()) {
            return false;
        }
        finishCloseProcess();
        return true;
    }

    function showAnalyzeTool() {
        showTool(qsTr("Analyze Tools"), "qrc:/qml/QGroundControl/AnalyzeView/AnalyzeView.qml", "/qmlimages/Analyze.svg");
    }

    //-------------------------------------------------------------------------
    //-- Critical Vehicle Message Popup

    function showCriticalVehicleMessage(message) {
        if (suppressCriticalVehicleMessages) {
            return;
        }
        if (criticalVehicleMessagePopup.visible || QGroundControl.videoManager.fullScreen) {
            // We received additional warning message while an older warning message was still displayed.
            // When the user close the older one drop the message indicator tool so they can see the rest of them.
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = true;
        } else {
            criticalVehicleMessagePopup.criticalVehicleMessage = message;
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false;
            criticalVehicleMessagePopup.open();
        }
    }

    function showFlyView() {
        flyView.visible = true;
        planView.visible = false;
        toolDrawer.visible = false;
    }

    //-------------------------------------------------------------------------
    //-- Indicator Drawer

    function showIndicatorDrawer(drawerComponent, indicatorItem) {
        indicatorDrawer.sourceComponent = drawerComponent;
        indicatorDrawer.indicatorItem = indicatorItem;
        indicatorDrawer.open();
    }

    function showKnownVehicleComponentConfigPage(knownVehicleComponent) {
        showVehicleConfig();
        let vehicleComponent = globals.activeVehicle.autopilotPlugin.findKnownVehicleComponent(knownVehicleComponent);
        if (vehicleComponent) {
            toolDrawerLoader.item.showVehicleComponentPanel(vehicleComponent);
        }
    }

    function showPlanView() {
        flyView.visible = false;
        planView.visible = true;
        toolDrawer.visible = false;
    }

    function showSettingsTool(settingsPage = "") {
        showTool(qsTr("Application Settings"), "qrc:/qml/QGroundControl/Controls/AppSettings.qml", "/res/QGCLogoWhite");
        if (settingsPage !== "") {
            toolDrawerLoader.item.showSettingsPage(settingsPage);
        }
    }

    function showTool(toolTitle, toolSource, toolIcon) {
        toolDrawer.backIcon = flyView.visible ? "/qmlimages/PaperPlane.svg" : "/qmlimages/Plan.svg";
        toolDrawer.toolTitle = toolTitle;
        toolDrawer.toolSource = toolSource;
        toolDrawer.toolIcon = toolIcon;
        toolDrawer.visible = true;
    }

    function showToolSelectDialog() {
        if (mainWindow.allowViewSwitch()) {
            mainWindow.showIndicatorDrawer(toolSelectComponent, null);
        }
    }

    function showVehicleConfig() {
        showTool(qsTr("Vehicle Configuration"), "qrc:/qml/QGroundControl/VehicleSetup/VehicleConfigView.qml", "/qmlimages/Gears.svg");
    }

    function showVehicleConfigParametersPage() {
        showVehicleConfig();
        toolDrawerLoader.item.showParametersPanel();
    }

    bottomPadding: 0
    // The special casing for android prevents white bars from showing up on the edges of the screen with newer android versions
    flags: Qt.Window | (ScreenTools.isAndroid ? Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint : 0)
    leftPadding: 0
    rightPadding: 0

    // Qt 6.9+ auto-sets ApplicationWindow padding to the display safe-area insets on mobile,
    // which insets our full-bleed content and leaves a blank strip along the screen edge.
    // QGC draws edge-to-edge and manages its own insets, so zero the padding.
    topPadding: 0
    visible: true

    background: Rectangle {
        anchors.fill: parent
        color: QGroundControl.globalPalette.window
    }
    footer: LogReplayStatusBar {
        visible: QGroundControl.settingsManager.flyViewSettings.showLogReplayStatusBar.rawValue
    }

    Component.onCompleted: {
        // Start first run prompts only if login overlay is inactive; otherwise triggered on login success
        if (!loginOverlay.visible) {
            firstRunPromptManager.nextPrompt();
        }
    }
    onClosing: close => {
        if (!_forceClose) {
            if (_reentrantCloseGuard) {
                close.accepted = false;
                return;
            }
            _closeChecksToSkip = 0;
            close.accepted = performCloseChecks();
        }
    }

    /// Saves main window position and size and re-opens it in the same position and size next time
    MainWindowSavedState {
        window: mainWindow
    }

    QtObject {
        id: firstRunPromptManager

        property var currentDialog: null
        property int nextPromptIdIndex: 0
        property var rgPromptIds: QGroundControl.corePlugin.firstRunPromptsToShow()

        function clearNextPromptSignal() {
            if (currentDialog) {
                currentDialog.closed.disconnect(nextPrompt);
            }
        }

        function nextPrompt() {
            if (nextPromptIdIndex < rgPromptIds.length) {
                var component = Qt.createComponent(QGroundControl.corePlugin.firstRunPromptResource(rgPromptIds[nextPromptIdIndex]));
                currentDialog = component.createObject(mainWindow);
                currentDialog.closed.connect(nextPrompt);
                currentDialog.open();
                nextPromptIdIndex++;
            } else {
                currentDialog = null;
                showPreFlightChecklistIfNeeded();
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Global Scope Variables

    QtObject {
        id: globals

        readonly property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

        // Property to manage RemoteID quick access to settings page
        property bool commingFromRIDIndicator: false
        readonly property real defaultTextHeight: ScreenTools.defaultFontPixelHeight
        readonly property real defaultTextWidth: ScreenTools.defaultFontPixelWidth
        readonly property var guidedControllerFlyView: flyView.guidedController

        // Set to a non-empty string to block navigation with a custom reason (e.g. during calibration)
        property string navigationBlockedReason: ""
        readonly property var planMasterControllerFlyView: flyView.planController

        // Number of QGCTextField's with validation errors. Used to prevent closing panels with validation errors.
        property int validationErrorCount: 0
    }

    /// Default color palette used throughout the UI
    QGCPalette {
        id: qgcPal

        colorGroupEnabled: true
    }

    Connections {
        function onShowMessageDialogRequested(owner, title, text, buttons, acceptFunction, closeFunction) {
            _showMessageDialogWorker(owner, title, text, buttons, acceptFunction, closeFunction);
        }

        target: QGroundControl
    }

    Component {
        id: simpleMessageDialogComponent

        QGCSimpleMessageDialog {
        }
    }

    FlyView {
        id: flyView

        anchors.fill: parent
        objectName: "mainView_fly"
    }

    PlanView {
        id: planView

        anchors.fill: parent
        objectName: "mainView_plan"
        visible: false
    }

    MessageDialog {
        id: showTouchAreasNotification

        buttons: MessageDialog.Ok
        text: qsTr("Touch Area display toggled")
        title: qsTr("Debug Touch Areas")
    }

    MessageDialog {
        id: advancedModeOnConfirmation

        buttons: MessageDialog.Yes | MessageDialog.No
        text: QGroundControl.corePlugin.showAdvancedUIMessage
        title: qsTr("Advanced Mode")

        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = true;
            }
        }
    }

    MessageDialog {
        id: advancedModeOffConfirmation

        buttons: MessageDialog.Yes | MessageDialog.No
        text: qsTr("Turn off Advanced Mode?")
        title: qsTr("Advanced Mode")

        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = false;
            }
        }
    }

    // Toast notification shown when a view switch is blocked by a validation error
    ToolTip {
        id: validationErrorToast

        closePolicy: Popup.NoAutoClose
        text: qsTr("Please correct the invalid value before continuing")
        timeout: 3000
        x: (mainWindow.width - width) / 2
        y: mainWindow.height - height - ScreenTools.defaultFontPixelHeight * 3

        background: Rectangle {
            color: qgcPal.alertBackground
            radius: ScreenTools.defaultFontPixelWidth / 2
        }
        contentItem: QGCLabel {
            color: qgcPal.alertText
            text: validationErrorToast.text
        }
    }

    Component {
        id: toolSelectComponent

        SelectViewDropdown {
        }
    }

    Rectangle {
        id: toolDrawer

        property var backIcon
        property var toolIcon
        property alias toolSource: toolDrawerLoader.source
        property string toolTitle

        anchors.fill: parent
        color: qgcPal.window
        objectName: "mainView_toolDrawer"
        visible: false

        onVisibleChanged: {
            if (!toolDrawer.visible) {
                toolDrawerLoader.source = "";
            }
        }

        // This need to block click event leakage to underlying map.
        DeadMouseArea {
            anchors.fill: parent
        }

        Rectangle {
            id: toolDrawerToolbar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            color: qgcPal.toolbarBackground
            height: ScreenTools.toolbarHeight

            RowLayout {
                id: toolDrawerToolbarLayout

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.leftMargin: ScreenTools.defaultFontPixelWidth
                anchors.top: parent.top
                spacing: ScreenTools.defaultFontPixelWidth

                QGCToolBarButton {
                    id: qgcButton

                    height: parent.height
                    icon.source: "/res/QGCLogoFull.svg"
                    logo: true
                    objectName: "toolbar_qgcLogo"

                    onClicked: mainWindow.showToolSelectDialog()
                }

                QGCLabel {
                    id: toolbarDrawerText

                    font.pointSize: ScreenTools.largeFontPointSize
                    text: toolDrawer.toolTitle
                }
            }
        }

        Loader {
            id: toolDrawerLoader

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: toolDrawerToolbar.bottom
        }
    }

    Popup {
        id: criticalVehicleMessagePopup

        property bool additionalCriticalMessagesReceived: false
        property alias criticalVehicleMessage: criticalVehicleMessageText.text

        focus: true
        height: criticalVehicleMessageText.contentHeight + ScreenTools.defaultFontPixelHeight * 2
        modal: false
        width: mainWindow.width * 0.55
        x: Math.round((mainWindow.width - width) * 0.5)
        y: ScreenTools.toolbarHeight + ScreenTools.defaultFontPixelHeight

        background: Rectangle {
            anchors.fill: parent
            border.color: qgcPal.alertBorder
            border.width: 2
            color: qgcPal.alertBackground
            radius: ScreenTools.defaultFontPixelHeight * 0.5

            Rectangle {
                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: -(height / 2)
                border.color: qgcPal.alertBorder
                border.width: 1
                color: qgcPal.alertBackground
                height: vehicleWarningLabel.contentHeight + _margins
                radius: ScreenTools.defaultFontPixelHeight * 0.25
                width: vehicleWarningLabel.contentWidth + _margins

                QGCLabel {
                    id: vehicleWarningLabel

                    anchors.centerIn: parent
                    color: qgcPal.alertText
                    font.pointSize: ScreenTools.smallFontPointSize
                    text: qsTr("Vehicle Error")
                }
            }

            Rectangle {
                id: additionalErrorsIndicator

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                anchors.bottom: parent.bottom
                anchors.bottomMargin: -(height / 2)
                anchors.horizontalCenter: parent.horizontalCenter
                border.color: qgcPal.alertBorder
                border.width: 1
                color: qgcPal.alertBackground
                height: additionalErrorsLabel.contentHeight + _margins
                radius: ScreenTools.defaultFontPixelHeight * 0.25
                visible: criticalVehicleMessagePopup.additionalCriticalMessagesReceived
                width: additionalErrorsLabel.contentWidth + _margins

                QGCLabel {
                    id: additionalErrorsLabel

                    anchors.centerIn: parent
                    color: qgcPal.alertText
                    font.pointSize: ScreenTools.smallFontPointSize
                    text: qsTr("Additional errors received")
                }
            }
        }

        QGCLabel {
            id: criticalVehicleMessageText

            anchors.centerIn: parent
            color: qgcPal.alertText
            textFormat: TextEdit.RichText
            width: criticalVehicleMessagePopup.width - ScreenTools.defaultFontPixelHeight
            wrapMode: Text.WordWrap
        }

        MouseArea {
            anchors.fill: parent

            onClicked: {
                criticalVehicleMessagePopup.close();
                if (criticalVehicleMessagePopup.additionalCriticalMessagesReceived) {
                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false;
                    flyView.dropMainStatusIndicatorTool();
                } else if (QGroundControl.multiVehicleManager.activeVehicle) {
                    QGroundControl.multiVehicleManager.activeVehicle.resetErrorLevelMessages();
                }
            }
        }
    }

    Popup {
        id: indicatorDrawer

        property bool _expanded: false
        property real _margins: ScreenTools.defaultFontPixelHeight / 4
        property var indicatorItem
        property var sourceComponent

        function calcXPosition() {
            if (indicatorItem) {
                var xCenter = indicatorItem.mapToItem(mainWindow.contentItem, indicatorItem.width / 2, 0).x;
                return Math.max(_margins, Math.min(xCenter - (contentItem.implicitWidth / 2), mainWindow.contentItem.width - contentItem.implicitWidth - _margins - (indicatorDrawer.padding * 2) - (ScreenTools.defaultFontPixelHeight / 2)));
            } else {
                return _margins;
            }
        }

        bottomInset: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        focus: true
        leftInset: 0
        modal: true
        padding: _margins * 2
        rightInset: 0
        topInset: 0
        visible: false
        x: calcXPosition()
        y: ScreenTools.toolbarHeight + _margins

        background: Item {
            Rectangle {
                id: backgroundRect

                anchors.fill: parent
                color: QGroundControl.globalPalette.window
                opacity: 0.85
                radius: indicatorDrawer._margins
            }

            Rectangle {
                anchors.horizontalCenter: backgroundRect.right
                anchors.verticalCenter: backgroundRect.top
                border.color: QGroundControl.globalPalette.buttonText
                color: QGroundControl.globalPalette.button
                height: width
                objectName: "indicatorDrawerExpandButton"
                radius: width / 2
                visible: indicatorDrawerLoader.item && indicatorDrawerLoader.item._showExpand && !indicatorDrawer._expanded
                width: ScreenTools.largeFontPixelHeight

                QGCLabel {
                    anchors.centerIn: parent
                    color: QGroundControl.globalPalette.buttonText
                    text: ">"
                }

                QGCMouseArea {
                    fillItem: parent

                    onClicked: indicatorDrawer._expanded = true
                }
            }
        }
        contentItem: QGCFlickable {
            id: indicatorDrawerLoaderFlickable

            contentHeight: indicatorDrawerLoader.height
            contentWidth: indicatorDrawerLoader.width
            implicitHeight: Math.min(mainWindow.contentItem.height - ScreenTools.toolbarHeight - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.height)
            implicitWidth: Math.min(mainWindow.contentItem.width - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.width)

            Loader {
                id: indicatorDrawerLoader

                objectName: "indicatorDrawerLoader"

                Binding {
                    property: "expanded"
                    target: indicatorDrawerLoader.item
                    value: indicatorDrawer._expanded
                }

                Binding {
                    property: "drawer"
                    target: indicatorDrawerLoader.item
                    value: indicatorDrawer
                }
            }
        }

        onClosed: {
            _expanded = false;
            indicatorItem = undefined;
            indicatorDrawerLoader.sourceComponent = undefined;
        }
        onOpened: {
            _expanded = false;
            indicatorDrawerLoader.sourceComponent = indicatorDrawer.sourceComponent;
        }
    }

    Component {
        id: windowedAnalyzePage

        Window {
            property bool requiresVehicle: false
            property alias source: loader.source

            function adoptItem(item) {
                loader.visible = false;
                loader.source = "";
                item.parent = contentRect;
                item.anchors.fill = contentRect;
                item.popped = true;
                item.visible = true;
            }

            height: ScreenTools.defaultFontPixelHeight * 40
            visible: false
            width: ScreenTools.defaultFontPixelWidth * 100

            onClosing: {
                visible = false;
                // Destroy any reparented children (not owned by loader)
                for (var i = contentRect.children.length - 1; i >= 0; i--) {
                    var child = contentRect.children[i];
                    if (child !== loader) {
                        child.destroy();
                    }
                }
                source = "";
                Qt.callLater(destroy);
            }

            Connections {
                function onActiveVehicleChanged() {
                    if (requiresVehicle) {
                        close();
                    }
                }

                target: QGroundControl.multiVehicleManager
            }

            Rectangle {
                id: contentRect

                anchors.fill: parent
                color: QGroundControl.globalPalette.window

                Loader {
                    id: loader

                    anchors.fill: parent

                    onLoaded: item.popped = true
                }
            }
        }
    }

    // Login overlay covering the entire window until authentication succeeds
    LoginPage {
        id: loginOverlay

        anchors.fill: parent
        visible: true
        z: 99999

        onLoginSucceeded: {
            loginOverlay.visible = false;

            Qt.inputMethod.hide();

            firstRunPromptManager.nextPrompt();
        }
    }
}
