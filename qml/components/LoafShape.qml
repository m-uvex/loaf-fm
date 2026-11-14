import QtQuick
import QtQuick.Shapes
import app.loaf

// LoafShape -- filled Material 3 Expressive shape (cookie, clover, sunny...).
// Every shape is a circle whose radius is modulated around the edge, so they
// all fit the same box and can be swapped or rotated freely.
Item {
    id: root

    // circle | cookie4 | cookie6 | cookie9 | cookie12 | clover4 | clover8 |
    // sunny | burst | flower
    property string shape: "circle"
    property color color: theme.primaryContainer

    implicitWidth: 48
    implicitHeight: 48

    // lobes: bumps around the edge; depth: how far the valleys dip (0..1);
    // sharpness > 1 narrows the bumps (sunny), < 1 rounds them (cookie, clover).
    readonly property var spec: ({
        "circle": [0, 0, 1],
        "cookie4": [4, 0.12, 0.6],
        "cookie6": [6, 0.1, 0.6],
        "cookie9": [9, 0.08, 0.6],
        "cookie12": [12, 0.07, 0.6],
        "clover4": [4, 0.3, 0.45],
        "clover8": [8, 0.18, 0.5],
        "sunny": [8, 0.12, 1.6],
        "burst": [12, 0.16, 2.2],
        "flower": [6, 0.22, 0.4]
    })[root.shape] || [0, 0, 1]

    function outline(w, h) {
        var lobes = root.spec[0], depth = root.spec[1], sharp = root.spec[2];
        var cx = w / 2, cy = h / 2, rx = w / 2, ry = h / 2;
        var steps = lobes > 0 ? Math.max(96, lobes * 16) : 96;
        var pts = [];
        for (var i = 0; i <= steps; i++) {
            var a = (i / steps) * Math.PI * 2 - Math.PI / 2;
            var bump = Math.pow((1 + Math.cos(lobes * (a + Math.PI / 2))) / 2, sharp);
            var r = 1 - depth + depth * bump;
            pts.push(Qt.point(cx + Math.cos(a) * rx * r, cy + Math.sin(a) * ry * r));
        }
        return pts;
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeWidth: -1

            PathPolyline { path: root.outline(root.width, root.height) }
        }
    }
}
