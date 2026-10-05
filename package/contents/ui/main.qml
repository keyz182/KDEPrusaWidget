import QtQuick

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property var client: prusaLinkClient
    readonly property bool showThumbnail: Plasmoid.configuration.showThumbnail

    readonly property string webUrl: Plasmoid.configuration.webUiUrl.length > 0
        ? Plasmoid.configuration.webUiUrl
        : Plasmoid.configuration.printerUrl.replace(/\/+$/, "")

    readonly property bool needsAttention: client.connState === "ok"
        && (client.severity === "attention" || client.severity === "error")

    Plasmoid.status: {
        if (needsAttention) {
            return PlasmaCore.Types.NeedsAttentionStatus
        }
        if (client.connState === "ok" && client.severity === "active") {
            return PlasmaCore.Types.ActiveStatus
        }
        return PlasmaCore.Types.PassiveStatus
    }
    Plasmoid.configurationRequired: Plasmoid.configuration.printerUrl.length === 0
    Plasmoid.title: i18n("Prusa Status")

    toolTipMainText: i18n("Prusa Status")
    toolTipSubText: {
        switch (client.connState) {
        case "ok": {
            let text = client.job
                ? i18n("%1 — %2%", client.job.filename || i18n("Printing"), Math.round(client.job.progress * 100))
                : i18nc("printer state e.g. IDLE, FINISHED", "State: %1", client.printerState)
            if (client.statusMessage.length > 0) {
                text += "\n" + client.statusMessage
            }
            return text
        }
        case "authFailed":
        case "unreachable":
            return client.statusMessage
        default:
            return i18n("Not configured")
        }
    }

    function openWebUi() {
        if (webUrl.length > 0) {
            Qt.openUrlExternally(webUrl)
        }
    }

    PrusaLinkClient {
        id: prusaLinkClient
        baseUrl: Plasmoid.configuration.printerUrl
        username: Plasmoid.configuration.username
        password: Plasmoid.configuration.password
        apiKey: Plasmoid.configuration.apiKey
        activeInterval: Plasmoid.configuration.pollIntervalActive
        idleInterval: Plasmoid.configuration.pollIntervalIdle
    }

    switchWidth: Kirigami.Units.gridUnit * 10
    switchHeight: Kirigami.Units.gridUnit * 10

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : null

    compactRepresentation: CompactRepresentation {
        plasmoidItem: root
    }

    fullRepresentation: FullRepresentation {
        plasmoidItem: root
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        onClicked: root.openWebUi()
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Open Web UI")
            icon.name: "internet-web-browser"
            enabled: root.webUrl.length > 0
            onTriggered: root.openWebUi()
        }
    ]
}
