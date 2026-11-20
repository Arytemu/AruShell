import QtQuick

/**
 * Official Material Design 3 Emphasized Decelerate animation (used in Caelestia & end-4 Quickshell).
 */
NumberAnimation {
    duration: 380
    easing.type: Easing.BezierSpline
    easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
}
