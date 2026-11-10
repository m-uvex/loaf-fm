import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import app.loaf

// UsageBar -- storage usage bar (value clamped to 0..1). By default the used
// part is drawn as a Material 3 Expressive wavy line, followed by a gap, the
// flat track and a stop dot; wavy: false gives the plain rounded bar.
Item {
    id: root

    property real value: 0
    property color barColor: theme.primary
    property color trackColor: theme.track
    property bool wavy: true
    property real thickness: 4
    property real amplitude: 3
    property real wavelength: 40

    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    implicitHeight: root.wavy ? root.thickness + root.amplitude * 2 + 2 : 6
    implicitWidth: 120

    readonly property real clampedValue: Math.max(0, Math.min(1, isNaN(root.value) ? 0 : root.value))
    property real shown: root.clampedValue
    Behavior on shown { enabled: theme.animate; NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

    Rectangle {
        visible: !root.wavy
        anchors.fill: parent
        radius: height / 2
        color: root.trackColor

        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }
    }

    Rectangle {
        visible: !root.wavy
        height: parent.height
        radius: height / 2
        color: root.barColor
        width: parent.width * root.shown

        Behavior on color { enabled: theme.animate; ColorAnimation { duration: theme.durationNormal } }
    }

    readonly property real cap: root.thickness / 2
    readonly property real gap: root.thickness + 2
    readonly property real activeEnd: root.cap + (root.width - root.thickness) * root.shown
    readonly property real trackStart: Math.min(root.width - root.cap, root.activeEnd + root.gap + root.thickness)

    function wave() {
        var mid = root.height / 2, pts = [];
        var len = root.activeEnd - root.cap;
        // Flatten the wave while the bar is shorter than one wavelength.
        var amp = root.amplitude * Math.min(1, len / root.wavelength);
        var steps = Math.max(2, Math.ceil(len / 2));
        for (var i = 0; i <= steps; i++) {
            var x = root.cap + len * i / steps;
            pts.push(Qt.point(x, mid + Math.sin((x - root.cap) / root.wavelength * Math.PI * 2) * amp));
        }
        return pts;
    }

    Shape {
        visible: root.wavy
        anchors.fill: parent

        ShapePath {
            strokeColor: root.trackStart < root.width - root.cap ? root.trackColor : "transparent"
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            startX: root.trackStart
            startY: root.height / 2

            PathLine { x: root.width - root.cap; y: root.height / 2 }
        }

        ShapePath {
            strokeColor: root.shown > 0.001 ? root.barColor : "transparent"
            strokeWidth: root.thickness
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            fillColor: "transparent"

            PathPolyline { path: root.wave() }
        }
    }

    // Stop indicator at the end of the track.
    Rectangle {
        visible: root.wavy && root.shown < 0.98
        width: root.thickness
        height: root.thickness
        radius: width / 2
        x: root.width - width
        y: (root.height - height) / 2
        color: root.barColor
    }
}
