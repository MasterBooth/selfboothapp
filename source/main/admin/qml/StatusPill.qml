import QtQuick

// Nhãn trạng thái máy: chấm màu + chữ. Không dùng màu làm tín hiệu duy nhất.
Rectangle {
    id: p
    property string machineState: "pending"     // pending | licensed | revoked
    readonly property color _fg: machineState === "licensed" ? Tk.success : machineState === "revoked" ? Tk.error : Tk.accent
    implicitHeight: 24
    implicitWidth: row.implicitWidth + Tk.sSm * 2
    radius: Tk.radiusPill
    color: machineState === "licensed" ? Tk.successSoft : machineState === "revoked" ? Tk.errorSoft : Tk.accentSoft

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Rectangle { width: 6; height: 6; radius: 3; color: p._fg; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: Tk.stateLabel(p.machineState)
            color: p._fg
            font.family: Tk.body
            font.pixelSize: Tk.textXs
            font.weight: Font.DemiBold
        }
    }
}
