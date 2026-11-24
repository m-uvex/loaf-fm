import QtQuick

// SideRoundedRect -- a rectangle whose left and right corners have
// different radii, built from two plain Rectangles so it works on Qt 6.4
// (per-corner radius properties only exist from Qt 6.7).
//
// The left half carries leftRadius and the right half rightRadius; each
// overlaps the other by (leftRadius + rightRadius) / 2, which hides its
// inner corners inside the other half.
Item {
    id: root

    property real leftRadius: 0
    property real rightRadius: 0
    property color color: "transparent"

    readonly property real maxR: Math.max(leftRadius, rightRadius)
    readonly property real overlap: (leftRadius + rightRadius) / 2
    // Too narrow to hide the inner corners: fall back to one shape.
    readonly property bool split: leftRadius !== rightRadius
        && width >= leftRadius + rightRadius + 2 * maxR

    Rectangle {
        visible: !root.split
        anchors.fill: parent
        radius: Math.min(root.leftRadius, root.rightRadius)
        color: root.color
    }

    Rectangle {
        visible: root.split
        x: 0
        width: root.width / 2 + root.overlap
        height: root.height
        radius: root.leftRadius
        color: root.color
    }

    Rectangle {
        visible: root.split
        x: root.width / 2 - root.overlap
        width: root.width / 2 + root.overlap
        height: root.height
        radius: root.rightRadius
        color: root.color
    }
}
