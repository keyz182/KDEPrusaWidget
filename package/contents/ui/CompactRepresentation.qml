pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

Item {
    id: root

    required property PlasmoidItem plasmoidItem

    readonly property var client: plasmoidItem.client
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property var job: client.connState === "ok" ? client.job : null

    // Art + two text lines only on a horizontal panel with a job; otherwise a
    // plain icon with an optional short label.
    readonly property bool richLayout: job !== null && !vertical

    // Attention/error icons must stay visible, so they override the thumbnail.
    readonly property bool alerting: root.plasmoidItem.needsAttention

    readonly property bool showingThumbnail: plasmoidItem.showThumbnail
        && !alerting
        && job !== null
        && client.thumbnailUrl.length > 0
        && thumbnailImage.status === Image.Ready

    function formatTimeLeft() {
        if (!job || job.timeRemaining < 0) {
            return i18n("estimating…")
        }
        const h = Math.floor(job.timeRemaining / 3600)
        const m = Math.floor((job.timeRemaining % 3600) / 60)
        return h > 0 ? i18n("%1h %2m left", h, m) : i18n("%1m left", m)
    }

    Layout.minimumWidth: vertical ? Kirigami.Units.iconSizes.small : layout.implicitWidth
    Layout.minimumHeight: vertical ? layout.implicitHeight : Kirigami.Units.iconSizes.small
    Layout.maximumWidth: richLayout ? -1 : layout.implicitWidth

    RowLayout {
        id: layout
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        Item {
            Layout.fillHeight: true
            Layout.preferredWidth: root.richLayout ? height : Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small

            Image {
                id: thumbnailImage
                anchors.fill: parent
                visible: root.showingThumbnail
                source: (root.plasmoidItem.showThumbnail && root.job !== null) ? root.client.thumbnailUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                sourceSize.width: Kirigami.Units.iconSizes.enormous
                sourceSize.height: Kirigami.Units.iconSizes.enormous
            }

            Kirigami.Icon {
                anchors.fill: parent
                anchors.margins: root.richLayout ? Kirigami.Units.smallSpacing : 0
                visible: !root.showingThumbnail

                source: {
                    if (root.client.connState === "authFailed") {
                        return "dialog-password"
                    }
                    if (root.client.connState === "ok" && root.client.severity === "error") {
                        return "printer-error-symbolic"
                    }
                    if (root.client.connState === "ok" && root.client.severity === "attention") {
                        return "dialog-warning-symbolic"
                    }
                    return "printer"
                }

                opacity: root.client.connState === "unreachable" || root.client.connState === "unknown" ? 0.4 : 1.0
            }
        }

        ColumnLayout {
            visible: root.richLayout
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            QQC2.Label {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
                font.bold: true
                text: root.job ? (root.job.filename || i18n("Printing")) : ""
            }

            QQC2.Label {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
                opacity: 0.7
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                color: root.alerting ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                text: {
                    if (!root.job) {
                        return ""
                    }
                    const pct = i18n("%1%", Math.round(root.job.progress * 100))
                    if (root.alerting) {
                        return i18nc("progress percent, then why the printer needs attention", "%1 · %2", pct,
                            root.client.statusMessage || i18n("Needs attention"))
                    }
                    if (root.client.printerState === "PAUSED") {
                        return i18nc("progress percent, then paused", "%1 · Paused", pct)
                    }
                    return i18nc("progress percent, then time remaining", "%1 · %2", pct, root.formatTimeLeft())
                }
            }
        }

        QQC2.Label {
            visible: !root.richLayout && text.length > 0
            text: {
                if (!root.job) {
                    return ""
                }
                if (root.client.printerState === "PAUSED") {
                    return "‖"
                }
                return i18n("%1%", Math.round(root.job.progress * 100))
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.plasmoidItem.expanded = !root.plasmoidItem.expanded
    }
}
