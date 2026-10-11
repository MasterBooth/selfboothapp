import QtQuick
import QtQuick.Shapes
import "../theme"

// Lightweight vector icon used by the Settings UI. Paths are intentionally
// simple and monochrome so every category shares one visual language.
Item {
    id: root
    property string name: "settings"
    property color color: Theme.settingsCopper
    property real strokeWidth: 1.8
    implicitWidth: 24
    implicitHeight: 24

    readonly property var svgIcons: ({
        "settings": "qrc:/assets/icons/settings_button.png",
        "camera": "qrc:/assets/icons/camera_setting.png",
        "capture": "qrc:/assets/icons/capture.svg",
        "printer": "qrc:/assets/icons/printer.svg",
        "share": "qrc:/assets/icons/share.svg",
        "frames": "qrc:/assets/icons/frames.svg",
        "account": "qrc:/assets/icons/account_setting.png",
        "image": "qrc:/assets/icons/gallery_setting.png",
        "palette": "qrc:/assets/icons/palette.svg",
        "ticket": "qrc:/assets/icons/coupon_setting.png",
        "revenue": "qrc:/assets/icons/revenue.svg",
        "info": "qrc:/assets/icons/info.svg",
        "mode": "qrc:/assets/icons/mode.svg"
    })
    readonly property string svgSource: root.svgIcons[root.name] || ""

    readonly property var iconPaths: ({
        "settings": ["M12 8.5A3.5 3.5 0 1 0 12 15.5A3.5 3.5 0 1 0 12 8.5", "M19.4 15A1.7 1.7 0 0 0 19.7 16.9L20 17.4L17.4 20L16.9 19.7A1.7 1.7 0 0 0 15 19.4A1.7 1.7 0 0 0 14 21H10A1.7 1.7 0 0 0 9 19.4A1.7 1.7 0 0 0 7.1 19.7L6.6 20L4 17.4L4.3 16.9A1.7 1.7 0 0 0 4.6 15A1.7 1.7 0 0 0 3 14V10A1.7 1.7 0 0 0 4.6 9A1.7 1.7 0 0 0 4.3 7.1L4 6.6L6.6 4L7.1 4.3A1.7 1.7 0 0 0 9 4.6A1.7 1.7 0 0 0 10 3H14A1.7 1.7 0 0 0 15 4.6A1.7 1.7 0 0 0 16.9 4.3L17.4 4L20 6.6L19.7 7.1A1.7 1.7 0 0 0 19.4 9A1.7 1.7 0 0 0 21 10V14A1.7 1.7 0 0 0 19.4 15"],
        "camera": ["M4 7H7L8.5 5H15.5L17 7H20A2 2 0 0 1 22 9V18A2 2 0 0 1 20 20H4A2 2 0 0 1 2 18V9A2 2 0 0 1 4 7", "M12 10A4 4 0 1 0 12 18A4 4 0 1 0 12 10"],
        "capture": ["M4 4H9V6H6V9H4ZM15 4H20V9H18V6H15ZM4 15H6V18H9V20H4ZM18 15H20V20H15V18H18Z", "M12 9A3 3 0 1 0 12 15A3 3 0 1 0 12 9"],
        "printer": ["M6 9V3H18V9", "M6 18H4A2 2 0 0 1 2 16V11A2 2 0 0 1 4 9H20A2 2 0 0 1 22 11V16A2 2 0 0 1 20 18H18", "M6 14H18V21H6Z"],
        "share": ["M12 3V15", "M7 8L12 3L17 8", "M5 13H3V21H21V13H19"],
        "frames": ["M3 3H21V21H3Z", "M7 7H17V17H7Z"],
        "account": ["M12 4A4 4 0 1 0 12 12A4 4 0 1 0 12 4", "M4 21A8 7 0 0 1 20 21"],
        "image": ["M3 4H21V20H3Z", "M8 9A2 2 0 1 0 8 5A2 2 0 1 0 8 9", "M3 17L8 12L12 16L15 13L21 19"],
        "palette": ["M12 3A9 9 0 0 0 12 21H13.5A2 2 0 0 0 15.5 19A2 2 0 0 0 13.5 17H12A5 5 0 0 1 12 7H13A3 3 0 0 1 16 10A3 3 0 0 0 19 13A3 3 0 0 0 22 10A9 9 0 0 0 12 3", "M7.5 10H7.6M9 6.5H9.1M16.5 7H16.6"],
        "ticket": ["M3 8A2 2 0 0 0 3 12A2 2 0 0 0 3 16V19H21V16A2 2 0 0 0 21 12A2 2 0 0 0 21 8V5H3Z", "M13 5V19"],
        "revenue": ["M4 19V10M10 19V5M16 19V8M22 19V3", "M2 21H22"],
        "info": ["M12 3A9 9 0 1 0 12 21A9 9 0 1 0 12 3", "M12 11V17", "M12 7V7.1"],
        "mode": ["M4 7H20", "M4 17H20", "M8 4V10", "M16 14V20"],
        "search": ["M10.5 4A6.5 6.5 0 1 0 10.5 17A6.5 6.5 0 1 0 10.5 4", "M15.5 15.5L21 21"],
        "arrow-left": ["M20 12H4", "M10 6L4 12L10 18"],
        "play": ["M7 4L20 12L7 20Z"],
        "maximize": ["M8 3H3V8M16 3H21V8M3 16V21H8M21 16V21H16"],
        "more": ["M5 12H5.1M12 12H12.1M19 12H19.1"],
        "shield": ["M12 3L20 6V11C20 16 16.7 19.4 12 21C7.3 19.4 4 16 4 11V6Z"],
        "monitor": ["M3 4H21V17H3Z", "M8 21H16", "M12 17V21"],
        "folder": ["M3 5H9L11 8H21V20H3Z"],
        "text": ["M5 5H19M12 5V20M8 20H16"],
        "video": ["M3 6H16V18H3Z", "M16 10L21 7V17L16 14Z"]
    })

    Image {
        anchors.fill: parent
        visible: root.svgSource !== ""
        source: root.svgSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    Repeater {
        visible: root.svgSource === ""
        model: root.iconPaths[root.name] || root.iconPaths.settings
        delegate: Shape {
            anchors.fill: parent
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: modelData }
            }
        }
    }
}
