import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Basic
import QtQuick.Layouts

/// @brief Login page for Yantra GCS — optimised for landscape GCS controller screens.
///
/// Layout adapts automatically:
///   • Landscape (width > height): single card, brand content left / form right (no visual divider).
///   • Portrait / square:          single centred card (fallback).
///
/// The form column is wrapped in a Flickable so it is always reachable even
/// when the on-screen keyboard reduces available height.
Item {
    id: loginPage

    // -------------------------------------------------------------------------
    // Internal state
    // -------------------------------------------------------------------------
    property bool _busy: false
    property string _errorText: ""

    // True when we are in landscape (controller) orientation
    readonly property bool _landscape: width > height
    property bool _showForgotInfo: false

    signal loginSucceeded

    // =========================================================================
    // Helpers
    // =========================================================================
    function _canLogin() {
        return !_busy && usernameField.text.length > 0 && passwordField.text.length > 0;
    }

    function _doLogin() {
        // 1. Force Android keyboard to accept the currently typed word
        Qt.inputMethod.commit();

        if (!_canLogin())
            return;

        // 2. Remove focus and hide the keyboard IMMEDIATELY
        usernameField.focus = false;
        passwordField.focus = false;
        loginPage.forceActiveFocus();
        Qt.inputMethod.hide();

        // 3. Start the login request
        _busy = true;
        _errorText = "";
        authManager.login(usernameField.text, passwordField.text);
    }

    // =========================================================================
    // Auth result handler
    // =========================================================================
    Connections {
        function onLoginResult(success, message) {
            loginPage._busy = false;

            if (success) {
                loginPage._errorText = "";
                loginPage.loginSucceeded();
            } else {
                loginPage._errorText = message;
                passwordField.text = "";
                // Only bring the keyboard back up if there was an error
                passwordField.forceActiveFocus();
            }
        }

        target: authManager
    }

    // =========================================================================
    // Background — full-bleed dark gradient
    // =========================================================================
    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop {
                color: "#070f1f"
                position: 0.0
            }

            GradientStop {
                color: "#0d1f3c"
                position: 1.0
            }
        }

        // Block all touch/mouse from reaching views behind the overlay
        MouseArea {
            anchors.fill: parent
            preventStealing: true
        }
    }

    // Subtle grid
    Canvas {
        anchors.fill: parent
        opacity: 0.035

        onPaint: {
            const ctx = getContext("2d");
            ctx.strokeStyle = "#ffffff";
            ctx.lineWidth = 0.5;
            ctx.beginPath();
            for (let x = 0; x < width; x += 40) {
                ctx.moveTo(x, 0);
                ctx.lineTo(x, height);
            }
            for (let y = 0; y < height; y += 40) {
                ctx.moveTo(0, y);
                ctx.lineTo(width, y);
            }
            ctx.stroke();
        }
    }

    // Ambient glow — top-left
    Rectangle {
        color: "transparent"
        height: width
        radius: width
        width: parent.width * 0.55
        x: -width * 0.25
        y: -height * 0.25

        Rectangle {
            anchors.centerIn: parent
            color: "#1565C0"
            height: width
            opacity: 0.14
            radius: width
            width: parent.width * 0.6
        }
    }

    // Ambient glow — bottom-right
    Rectangle {
        color: "transparent"
        height: width
        radius: width
        width: parent.width * 0.4
        x: parent.width - width * 0.75
        y: parent.height - height * 0.75

        Rectangle {
            anchors.centerIn: parent
            color: "#0d47a1"
            height: width
            opacity: 0.10
            radius: width
            width: parent.width * 0.6
        }
    }

    // =========================================================================
    // Root layout — a SINGLE bordered card. In landscape the brand content and
    // the form sit side-by-side inside it (no divider, no separate box); in
    // portrait they stack, still inside the same card.
    // =========================================================================
    Item {
        id: sizer

        property real implicitFormHeight: formFlickable.contentHeight + 48

        anchors.centerIn: parent
        height: _landscape ? Math.min(parent.height * 0.90, 420) : implicitFormHeight + 48
        width: _landscape ? Math.min(parent.width * 0.92, 860) : Math.min(parent.width * 0.92, 420)

        // =====================================================================
        // MAIN PANEL — the one and only card background/border for both modes
        // =====================================================================
        Rectangle {
            id: mainPanel

            anchors.fill: parent
            border.color: "#1e3a6e"
            border.width: 1
            color: "#0f1f3a"
            radius: 16

            // Single blue accent top-line for the whole card
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                color: "#2979FF"
                height: 2
                opacity: 0.6
                radius: 1
                width: parent.width * 0.55
            }

            // =================================================================
            // BRAND CONTENT (landscape only — left side, no background of its own)
            // =================================================================
            Item {
                id: brandColumn

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.top: parent.top
                visible: _landscape
                width: parent.width * 0.38

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0
                    width: parent.width * 0.8

                    // Logo (reduced size)
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        border.color: "#2979FF"
                        border.width: 1.5
                        color: "#1565C0"
                        height: 74
                        radius: 38
                        width: 74

                        Image {
                            anchors.fill: parent
                            anchors.margins: 7
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            source: "qrc:/qmlimages/YantraLogo.png"
                        }

                        Text {
                            anchors.centerIn: parent
                            color: "white"
                            font.bold: true
                            font.pixelSize: 30
                            text: "Y"
                            visible: false  // shown only if image fails — Image covers it
                        }
                    }

                    Item {
                        Layout.preferredHeight: 16
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        color: "#FFFFFF"
                        font.bold: true
                        font.family: "Inter, Roboto, Arial, sans-serif"
                        font.letterSpacing: 1.5
                        font.pixelSize: 28
                        text: qsTr("Yantra GCS")
                    }

                    Item {
                        Layout.preferredHeight: 6
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        color: "#5577aa"
                        font.family: "Inter, Roboto, Arial, sans-serif"
                        font.letterSpacing: 0.5
                        font.pixelSize: 11
                        text: qsTr("Ground Control Station")
                    }
                }
            }

            // =================================================================
            // FORM CONTENT — right side (landscape) or full width (portrait)
            // =================================================================
            Item {
                id: formPanel

                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.top: parent.top
                width: _landscape ? parent.width - brandColumn.width : parent.width

                // -----------------------------------------------------------------
                // Flickable so the form is reachable when keyboard is up
                // -----------------------------------------------------------------
                Flickable {
                    id: formFlickable

                    clip: true
                    contentHeight: formColumn.implicitHeight
                    contentWidth: width

                    // Auto-scroll to keep the active field visible
                    onContentHeightChanged: {
                        if (contentHeight > height)
                            contentY = Math.max(0, contentHeight - height);
                    }

                    anchors {
                        fill: parent
                        margins: 24
                    }

                    ColumnLayout {
                        id: formColumn

                        spacing: 0
                        width: formFlickable.width

                        // Portrait-only logo + title (hidden in landscape — brand side shows them)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            visible: !_landscape

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                border.color: "#2979FF"
                                border.width: 1.5
                                color: "#1565C0"
                                height: 64
                                radius: 32
                                width: 64

                                Text {
                                    anchors.centerIn: parent
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: 26
                                    text: "Y"
                                }
                            }

                            Item {
                                Layout.preferredHeight: 12
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                color: "#FFFFFF"
                                font.bold: true
                                font.family: "Inter, Roboto, Arial, sans-serif"
                                font.letterSpacing: 1.5
                                font.pixelSize: 26
                                text: qsTr("Yantra GCS")
                            }

                            Item {
                                Layout.preferredHeight: 4
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                color: "#8899aa"
                                font.family: "Inter, Roboto, Arial, sans-serif"
                                font.pixelSize: 12
                                text: qsTr("Sign in to continue")
                            }

                            Item {
                                Layout.preferredHeight: 20
                            }
                        }

                        // Landscape title (compact)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            visible: _landscape

                            Text {
                                color: "#FFFFFF"
                                font.bold: true
                                font.family: "Inter, Roboto, Arial, sans-serif"
                                font.pixelSize: 18
                                text: qsTr("Welcome back")
                            }

                            Item {
                                Layout.preferredHeight: 2
                            }

                            Text {
                                color: "#8899aa"
                                font.family: "Inter, Roboto, Arial, sans-serif"
                                font.pixelSize: 11
                                text: qsTr("Sign in to continue")
                            }

                            Item {
                                Layout.preferredHeight: 16
                            }
                        }

                        // ----------------------------------------------------------
                        // Username
                        // ----------------------------------------------------------
                        Text {
                            color: "#5577aa"
                            font.bold: true
                            font.family: "Inter, Roboto, Arial, sans-serif"
                            font.letterSpacing: 1.2
                            font.pixelSize: 10
                            text: qsTr("USERNAME")
                        }

                        Item {
                            Layout.preferredHeight: 5
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            border.color: usernameField.activeFocus ? "#2979FF" : "#1e3a6e"
                            border.width: usernameField.activeFocus ? 1.5 : 1
                            color: usernameField.activeFocus ? "#1a2f55" : "#162040"
                            height: _landscape ? 38 : 44
                            radius: 8

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            TextField {
                                id: usernameField

                                anchors.fill: parent
                                anchors.margins: 1
                                background: null
                                color: "#FFFFFF"
                                enabled: !loginPage._busy
                                font.family: "Inter, Roboto, Arial, sans-serif"
                                font.pixelSize: _landscape ? 13 : 14
                                leftPadding: 12
                                placeholderText: qsTr("Enter username")
                                placeholderTextColor: "#445566"
                                rightPadding: 12

                                Keys.onEnterPressed: if (text.length > 0)
                                    passwordField.forceActiveFocus()
                                Keys.onReturnPressed: if (text.length > 0)
                                    passwordField.forceActiveFocus()
                            }
                        }

                        Item {
                            Layout.preferredHeight: _landscape ? 10 : 14
                        }

                        // ----------------------------------------------------------
                        // Password
                        // ----------------------------------------------------------
                        Text {
                            color: "#5577aa"
                            font.bold: true
                            font.family: "Inter, Roboto, Arial, sans-serif"
                            font.letterSpacing: 1.2
                            font.pixelSize: 10
                            text: qsTr("PASSWORD")
                        }

                        Item {
                            Layout.preferredHeight: 5
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            border.color: passwordField.activeFocus ? "#2979FF" : "#1e3a6e"
                            border.width: passwordField.activeFocus ? 1.5 : 1
                            color: passwordField.activeFocus ? "#1a2f55" : "#162040"
                            height: _landscape ? 38 : 44
                            radius: 8

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            TextField {
                                id: passwordField

                                anchors.fill: parent
                                anchors.margins: 1
                                background: null
                                color: "#FFFFFF"
                                echoMode: TextInput.Password
                                enabled: !loginPage._busy
                                font.family: "Inter, Roboto, Arial, sans-serif"
                                font.pixelSize: _landscape ? 13 : 14
                                leftPadding: 12
                                placeholderText: qsTr("Enter password")
                                placeholderTextColor: "#445566"
                                rightPadding: 12

                                Keys.onEnterPressed: if (loginPage._canLogin())
                                    loginPage._doLogin()
                                Keys.onReturnPressed: if (loginPage._canLogin())
                                    loginPage._doLogin()
                            }
                        }

                        Item {
                            Layout.preferredHeight: 6
                        }

                        // Forgot password link
                        Text {
                            Layout.alignment: Qt.AlignRight
                            color: forgotMA.containsMouse ? "#5599ff" : "#2979FF"
                            font.family: "Inter, Roboto, Arial, sans-serif"
                            font.pixelSize: 11
                            font.underline: forgotMA.containsMouse
                            text: qsTr("Forgot Password?")

                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            MouseArea {
                                id: forgotMA

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: loginPage._showForgotInfo = !loginPage._showForgotInfo
                            }
                        }

                        Item {
                            Layout.preferredHeight: loginPage._showForgotInfo ? 8 : 0

                            Behavior on Layout.preferredHeight {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }

                        // Inline "contact the manufacturer" notice
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: loginPage._showForgotInfo ? (forgotInfoContent.implicitHeight + 16) : 0
                            border.color: "#1e3a6e"
                            border.width: 1
                            clip: true
                            color: "#132a4d"
                            opacity: loginPage._showForgotInfo ? 1.0 : 0.0
                            radius: 7

                            Behavior on Layout.preferredHeight {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                }
                            }

                            RowLayout {
                                id: forgotInfoContent

                                spacing: 8

                                anchors {
                                    left: parent.left
                                    margins: 10
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    color: "#2979FF"
                                    font.pixelSize: 13
                                    text: "ℹ"
                                }

                                Text {
                                    Layout.fillWidth: true
                                    color: "#9db6dd"
                                    font.family: "Inter, Roboto, Arial, sans-serif"
                                    font.pixelSize: _landscape ? 11 : 12
                                    text: qsTr("Please contact the manufacturer for password reset.")
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        Item {
                            Layout.preferredHeight: _landscape ? 10 : 14
                        }

                        // ----------------------------------------------------------
                        // Error banner — always visible, never clips
                        // ----------------------------------------------------------
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: loginPage._errorText.length > 0 ? (errorContent.implicitHeight + 16) : 0
                            border.color: "#c0392b"
                            border.width: 1
                            clip: true
                            color: "#1e0808"
                            opacity: loginPage._errorText.length > 0 ? 1.0 : 0.0
                            radius: 7

                            Behavior on Layout.preferredHeight {
                                NumberAnimation {
                                    duration: 150
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 150
                                }
                            }

                            RowLayout {
                                id: errorContent

                                spacing: 8

                                anchors {
                                    left: parent.left
                                    margins: 10
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    color: "#e74c3c"
                                    font.pixelSize: 13
                                    text: "⚠"
                                }

                                Text {
                                    Layout.fillWidth: true
                                    color: "#ff8080"
                                    font.family: "Inter, Roboto, Arial, sans-serif"
                                    font.pixelSize: _landscape ? 11 : 12
                                    text: loginPage._errorText
                                    wrapMode: Text.Wrap
                                }
                            }
                        }

                        Item {
                            Layout.preferredHeight: _landscape ? 10 : 14
                        }

                        // Sign In button
                        Rectangle {
                            Layout.fillWidth: true
                            height: _landscape ? 40 : 46
                            opacity: loginBtnMA.containsMouse && !loginBtnMA.pressed ? 0.90 : 1.0
                            radius: 8

                            gradient: Gradient {
                                orientation: Gradient.Horizontal

                                GradientStop {
                                    color: (loginPage._canLogin() || loginPage._busy) ? (loginBtnMA.pressed ? "#1253c4" : "#1565C0") : "#1a2a44"
                                    position: 0.0
                                }

                                GradientStop {
                                    color: (loginPage._canLogin() || loginPage._busy) ? (loginBtnMA.pressed ? "#1976D2" : "#2196F3") : "#1e3050"
                                    position: 1.0
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 100
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                color: loginPage._canLogin() ? "white" : "#445566"
                                font.bold: true
                                font.family: "Inter, Roboto, Arial, sans-serif"
                                font.letterSpacing: 1.5
                                font.pixelSize: _landscape ? 13 : 14
                                text: qsTr("SIGN IN")
                            }

                            Text {
                                anchors.centerIn: parent
                                color: loginPage._canLogin() ? "white" : "#445566"
                                font.bold: true
                                font.family: "Inter, Roboto, Arial, sans-serif"
                                font.letterSpacing: 1.5
                                font.pixelSize: _landscape ? 13 : 14
                                text: qsTr("SIGN IN")
                                visible: !loginPage._busy
                            }

                            MouseArea {
                                id: loginBtnMA

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: loginPage._canLogin()
                                hoverEnabled: true

                                onClicked: loginPage._doLogin()
                            }
                        }

                        Item {
                            Layout.preferredHeight: _landscape ? 6 : 20
                        }
                    }
                }
            }

            // "ALWAYS READY" tag — centred under the WHOLE card, not just one side
            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                color: '#f62c2c'
                font.bold: true
                font.family: "Inter, Roboto, Arial, sans-serif"
                font.letterSpacing: 3.5
                font.pixelSize: 18
                opacity: 0.55
                text: qsTr("ALWAYS READY")
            }

            Rectangle {
                anchors.fill: parent
                color: "#050d1c"
                opacity: loginPage._busy ? 0.78 : 0.0
                radius: parent.radius
                visible: opacity > 0
                z: 100

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 16

                    BusyIndicator {
                        Layout.alignment: Qt.AlignHCenter
                        height: 56
                        running: loginPage._busy
                        width: 56
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        color: "white"
                        font.bold: true
                        font.family: "Inter, Roboto, Arial, sans-serif"
                        font.pixelSize: 14
                        text: qsTr("Signing in…")
                    }
                }
            }
        }
    }
}
