import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.AppSettings

/// Post-login comm-link setup dialog.
/// Reuses the standard LinkConfigurationManager from AppSettings so the user
/// gets the exact same functionality (Add, Edit, UDP Port, TCP Host/Port, Connect)
/// as seen inside Application Settings -> Comm Links.
QGCPopupDialog {
    id:      _dialog
    title:   qsTr("Communication Links")
    buttons: Dialog.Close

    LinkConfigurationManager {
        width: Math.max(ScreenTools.defaultFontPixelWidth * 55, _dialog.headerMinWidth)
    }
}
