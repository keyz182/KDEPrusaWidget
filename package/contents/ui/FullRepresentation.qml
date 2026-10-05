pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

Item {
    id: root

    required property PlasmoidItem plasmoidItem

    readonly property var client: plasmoidItem.client
    readonly property var job: client.connState === "ok" ? client.job : null
    readonly property var temps: client.connState === "ok" ? client.temps : null

    // Stop ends the job for good, so it takes two clicks: the first arms it
    // for a few seconds, the second sends the request. Disarms itself on
    // timeout, when the popup closes, or when the job changes state.
    property bool stopArmed: false

    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.minimumHeight: Kirigami.Units.gridUnit * 12
    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
    Layout.preferredHeight: Kirigami.Units.gridUnit * 15

    function formatDuration(seconds) {
        if (seconds === undefined || seconds < 0 || !Number.isFinite(seconds)) {
            return "--:--"
        }
        const h = Math.floor(seconds / 3600)
        const m = Math.floor((seconds % 3600) / 60)
        return h > 0 ? i18n("%1h %2m", h, m) : i18n("%1m", m)
    }

    function formatTemp(current, target) {
        if (current === undefined) {
            return "--"
        }
        if (target === undefined) {
            return i18n("%1°C", Math.round(current))
        }
        return i18n("%1°C → %2°C", Math.round(current), Math.round(target))
    }

    Timer {
        id: disarmTimer
        interval: 5000
        onTriggered: root.stopArmed = false
    }

    Connections {
        target: root.plasmoidItem
        function onExpandedChanged() {
            root.stopArmed = false
        }
    }

    Connections {
        target: root.client
        function onPrinterStateChanged() {
            root.stopArmed = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        PlasmaExtras.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.client.connState !== "ok"
            iconName: root.client.connState === "authFailed" ? "dialog-password" : "network-disconnect"
            text: {
                switch (root.client.connState) {
                case "unknown":
                    return i18n("Not configured")
                case "authFailed":
                    return i18n("Login failed")
                default:
                    return i18n("Printer offline")
                }
            }
            explanation: {
                if (root.client.connState === "unknown") {
                    return i18n("Set the printer URL in the widget settings")
                }
                let msg = root.client.lastSuccess
                    ? i18n("Last seen: %1", Qt.formatDateTime(root.client.lastSuccess, "hh:mm:ss"))
                    : i18n("Never connected")
                if (root.client.statusMessage.length > 0) {
                    msg += "\n" + root.client.statusMessage
                }
                return msg
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.client.connState === "ok"
            spacing: Kirigami.Units.smallSpacing

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: root.plasmoidItem.needsAttention
                type: root.client.severity === "error" ? Kirigami.MessageType.Error : Kirigami.MessageType.Warning
                text: root.client.statusMessage.length > 0
                    ? root.client.statusMessage
                    : i18nc("printer state e.g. ATTENTION, ERROR", "Printer needs attention (%1)", root.client.printerState)
            }

            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Kirigami.Units.iconSizes.enormous
                Layout.preferredHeight: Kirigami.Units.iconSizes.enormous
                visible: root.job !== null && root.client.thumbnailUrl.length > 0 && status === Image.Ready
                source: root.job !== null ? root.client.thumbnailUrl : ""
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                sourceSize.width: Kirigami.Units.iconSizes.enormous * 2
                sourceSize.height: Kirigami.Units.iconSizes.enormous * 2
            }

            QQC2.Label {
                Layout.fillWidth: true
                elide: Text.ElideMiddle
                font.bold: true
                text: root.job
                    ? (root.job.filename || i18n("Printing"))
                    : i18nc("printer state e.g. IDLE, FINISHED", "State: %1", root.client.printerState)
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.job !== null

                QQC2.ProgressBar {
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: root.job ? root.job.progress : 0
                }
                QQC2.Label {
                    text: i18n("%1%", Math.round((root.job ? root.job.progress : 0) * 100))
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: root.job !== null
                text: root.job
                    ? i18n("Elapsed %1 · Remaining %2", root.formatDuration(root.job.timePrinting), root.formatDuration(root.job.timeRemaining))
                    : ""
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: root.job !== null
                opacity: 0.7
                text: i18nc("printer state e.g. PRINTING, PAUSED", "State: %1", root.client.printerState)
            }

            Kirigami.Separator {
                Layout.fillWidth: true
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2

                QQC2.Label {
                    text: i18n("Nozzle:")
                    opacity: 0.7
                }
                QQC2.Label {
                    text: root.temps ? root.formatTemp(root.temps.nozzle, root.temps.nozzleTarget) : "--"
                }
                QQC2.Label {
                    text: i18n("Bed:")
                    opacity: 0.7
                }
                QQC2.Label {
                    text: root.temps ? root.formatTemp(root.temps.bed, root.temps.bedTarget) : "--"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.client.canPause || root.client.canResume || root.client.canStop

                QQC2.Button {
                    Layout.fillWidth: true
                    visible: root.client.canPause
                    text: i18n("Pause")
                    icon.name: "media-playback-pause"
                    enabled: !root.client.controlsBusy
                    onClicked: root.client.pause()
                }
                QQC2.Button {
                    Layout.fillWidth: true
                    visible: root.client.canResume
                    text: i18n("Resume")
                    icon.name: "media-playback-start"
                    enabled: !root.client.controlsBusy
                    onClicked: root.client.resume()
                }
                QQC2.Button {
                    Layout.fillWidth: true
                    visible: root.client.canStop
                    text: root.stopArmed ? i18n("Confirm stop?") : i18n("Stop")
                    icon.name: root.stopArmed ? "dialog-warning" : "media-playback-stop"
                    highlighted: root.stopArmed
                    enabled: !root.client.controlsBusy
                    onClicked: {
                        if (root.stopArmed) {
                            root.stopArmed = false
                            disarmTimer.stop()
                            root.client.stop()
                        } else {
                            root.stopArmed = true
                            disarmTimer.restart()
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: root.client.lastActionError.length > 0
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.negativeTextColor
            text: root.client.lastActionError
        }

        QQC2.Button {
            Layout.fillWidth: true
            text: i18n("Open Web UI")
            icon.name: "internet-web-browser"
            enabled: root.plasmoidItem.webUrl.length > 0
            onClicked: root.plasmoidItem.openWebUi()
        }
    }
}
