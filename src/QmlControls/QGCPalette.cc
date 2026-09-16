#include "QGCPalette.h"
#include "QGCCorePlugin.h"

#include <QtCore/QDebug>

QList<QGCPalette*>   QGCPalette::_paletteObjects;

QGCPalette::Theme QGCPalette::_theme = QGCPalette::Dark;

QMap<int, QMap<int, QMap<QString, QColor>>> QGCPalette::_colorInfoMap;

QStringList QGCPalette::_colors;

QGCPalette::QGCPalette(QObject* parent) :
    QObject(parent),
    _colorGroupEnabled(true)
{
    if (_colorInfoMap.isEmpty()) {
        _buildMap();
    }

    // We have to keep track of all QGCPalette objects in the system so we can signal theme change to all of them
    _paletteObjects += this;
}

QGCPalette::~QGCPalette()
{
    bool fSuccess = _paletteObjects.removeOne(this);
    if (!fSuccess) {
        qWarning() << "Internal error";
    }
}

void QGCPalette::_buildMap()
{
    //                                      Light                 Dark
    //                                      Disabled   Enabled    Disabled   Enabled
    DECLARE_QGC_COLOR(window,               "#1A1524", "#15121B", "#1A1524", "#15121B")
    DECLARE_QGC_COLOR(windowTransparent,    "#cc1a1524", "#cc15121b", "#cc1a1524", "#cc15121b")
    DECLARE_QGC_COLOR(windowShadeLight,     "#382F48", "#2E273A", "#382F48", "#2E273A")
    DECLARE_QGC_COLOR(windowShade,          "#251E31", "#1E1828", "#251E31", "#1E1828")
    DECLARE_QGC_COLOR(windowShadeDark,      "#191422", "#131018", "#191422", "#131018")
    DECLARE_QGC_COLOR(text,                 "#7A7287", "#FFFFFF", "#7A7287", "#FFFFFF")
    DECLARE_QGC_COLOR(warningText,          "#E52E42", "#E52E42", "#E52E42", "#E52E42")
    DECLARE_QGC_COLOR(button,               "#221C2B", "#292135", "#221C2B", "#292135")
    DECLARE_QGC_COLOR(buttonBorder,         "#352B44", "#423654", "#352B44", "#423654")
    DECLARE_QGC_COLOR(buttonText,           "#7A7287", "#FFFFFF", "#7A7287", "#FFFFFF")
    DECLARE_QGC_COLOR(buttonHighlight,      "#3D1622", "#E52E42", "#3D1622", "#E52E42")
    DECLARE_QGC_COLOR(buttonHighlightText,  "#FFFFFF", "#FFFFFF", "#FFFFFF", "#FFFFFF")
    DECLARE_QGC_COLOR(primaryButton,        "#541924", "#E52E42", "#541924", "#E52E42")
    DECLARE_QGC_COLOR(primaryButtonText,    "#FFFFFF", "#FFFFFF", "#FFFFFF", "#FFFFFF")
    DECLARE_QGC_COLOR(textField,            "#1A1523", "#221B2C", "#1A1523", "#221B2C")
    DECLARE_QGC_COLOR(textFieldText,        "#7A7287", "#FFFFFF", "#7A7287", "#FFFFFF")
    DECLARE_QGC_COLOR(mapButton,            "#1A1523", "#1E1828", "#1A1523", "#1E1828")
    DECLARE_QGC_COLOR(mapButtonHighlight,   "#541924", "#E52E42", "#541924", "#E52E42")
    DECLARE_QGC_COLOR(mapIndicator,         "#541924", "#E52E42", "#541924", "#E52E42")
    DECLARE_QGC_COLOR(mapIndicatorChild,    "#3D1622", "#9E1B2C", "#3D1622", "#9E1B2C")
    DECLARE_QGC_COLOR(colorGreen,           "#008f2d", "#00E676", "#008f2d", "#00E676")
    DECLARE_QGC_COLOR(colorYellow,          "#a2a200", "#FFEA00", "#a2a200", "#FFEA00")
    DECLARE_QGC_COLOR(colorYellowGreen,     "#799f26", "#AEEA00", "#799f26", "#AEEA00")
    DECLARE_QGC_COLOR(colorOrange,          "#bf7539", "#FF9100", "#bf7539", "#FF9100")
    DECLARE_QGC_COLOR(colorRed,             "#b52b2b", "#E52E42", "#b52b2b", "#E52E42")
    DECLARE_QGC_COLOR(colorGrey,            "#60586E", "#9890A6", "#60586E", "#9890A6")
    DECLARE_QGC_COLOR(colorBlue,            "#3D1622", "#E52E42", "#3D1622", "#E52E42")
    DECLARE_QGC_COLOR(alertBackground,      "#28141C", "#28141C", "#28141C", "#28141C")
    DECLARE_QGC_COLOR(alertBorder,          "#E52E42", "#E52E42", "#E52E42", "#E52E42")
    DECLARE_QGC_COLOR(alertText,            "#FFFFFF", "#FFFFFF", "#FFFFFF", "#FFFFFF")
    DECLARE_QGC_COLOR(missionItemEditor,    "#2B2338", "#241C2E", "#2B2338", "#241C2E")
    DECLARE_QGC_COLOR(toolStripHoverColor,  "#332A42", "#3D2E4F", "#332A42", "#3D2E4F")
    DECLARE_QGC_COLOR(statusFailedText,     "#7A7287", "#E52E42", "#7A7287", "#E52E42")
    DECLARE_QGC_COLOR(statusPassedText,     "#7A7287", "#00E676", "#7A7287", "#00E676")
    DECLARE_QGC_COLOR(statusPendingText,    "#7A7287", "#FFEA00", "#7A7287", "#FFEA00")
    DECLARE_QGC_COLOR(toolbarBackground,    "#F015121B", "#F015121B", "#F015121B", "#F015121B")
    DECLARE_QGC_COLOR(groupBorder,          "#332A40", "#3F3450", "#332A40", "#3F3450")
    DECLARE_QGC_COLOR(modifiedParamValue,   "#bf7539", "#FF9100", "#bf7539", "#FF9100")

    // Colors not affecting by theming
    //                                                      Disabled     Enabled
    DECLARE_QGC_NONTHEMED_COLOR(brandingPurple,             "#8E2242", "#E52E42")
    DECLARE_QGC_NONTHEMED_COLOR(brandingBlue,               "#E52E42", "#E52E42")
    DECLARE_QGC_NONTHEMED_COLOR(toolStripFGColor,           "#707070", "#ffffff")
    DECLARE_QGC_NONTHEMED_COLOR(photoCaptureButtonColor,    "#707070", "#ffffff")
    DECLARE_QGC_NONTHEMED_COLOR(videoCaptureButtonColor,    "#f89a9e", "#f32836")

    // Colors not affecting by theming or enable/disable
    DECLARE_QGC_SINGLE_COLOR(mapWidgetBorderLight,          "#ffffff")
    DECLARE_QGC_SINGLE_COLOR(mapWidgetBorderDark,           "#000000")
    DECLARE_QGC_SINGLE_COLOR(mapMissionTrajectory,          "#be781c")
    DECLARE_QGC_SINGLE_COLOR(surveyPolygonInterior,         "green")
    DECLARE_QGC_SINGLE_COLOR(surveyPolygonTerrainCollision, "red")

}

void QGCPalette::setColorGroupEnabled(bool enabled)
{
    _colorGroupEnabled = enabled;
    emit paletteChanged();
}

void QGCPalette::setGlobalTheme(Theme newTheme)
{
    // Mobile build does not have themes
    if (_theme != newTheme) {
        _theme = newTheme;
        _signalPaletteChangeToAll();
    }
}

void QGCPalette::_signalPaletteChangeToAll()
{
    // Notify all objects of the new theme
    for (QGCPalette *palette : std::as_const(_paletteObjects)) {
        palette->_signalPaletteChanged();
    }
}

void QGCPalette::_signalPaletteChanged()
{
    emit paletteChanged();
}
