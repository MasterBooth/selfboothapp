import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

ColumnLayout {
    id: root
    spacing: 12

    property int eventId: -1

    // Digital Props
    EffectToggle {
        Layout.fillWidth: true
        effectName: "Digital Props"
        effectKey: "digitalProps"
        eventId: root.eventId
    }

    // Beauty Filter
    EffectToggle {
        Layout.fillWidth: true
        effectName: "Beauty Filter"
        effectKey: "beautyFilter"
        eventId: root.eventId
    }

    // Watermark
    EffectToggle {
        Layout.fillWidth: true
        effectName: "Watermark"
        effectKey: "watermark"
        eventId: root.eventId
    }

    // Post Processing
    EffectToggle {
        Layout.fillWidth: true
        effectName: "Post Processing"
        effectKey: "postProcessing"
        eventId: root.eventId
    }

    // Disclaimer
    EffectToggle {
        Layout.fillWidth: true
        effectName: "Disclaimer"
        effectKey: "disclaimer"
        eventId: root.eventId
    }

    // Green Screen
    EffectToggle {
        Layout.fillWidth: true
        effectName: "Green Screen"
        effectKey: "greenScreen"
        eventId: root.eventId
    }
}
