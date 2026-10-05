import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root

    property alias cfg_printerUrl: printerUrlField.text
    property alias cfg_username: usernameField.text
    property alias cfg_password: passwordField.text
    property alias cfg_apiKey: apiKeyField.text
    property alias cfg_webUiUrl: webUiUrlField.text
    property alias cfg_pollIntervalActive: pollActiveField.value
    property alias cfg_pollIntervalIdle: pollIdleField.value
    property alias cfg_showThumbnail: showThumbnailField.checked

    function urlLooksValid(text) {
        return text.length === 0 || /^https?:\/\/[^\s/@]+/.test(text)
    }

    Kirigami.FormLayout {
        QQC2.TextField {
            id: printerUrlField
            Kirigami.FormData.label: i18n("Printer URL:")
            placeholderText: "http://192.168.1.60"
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: !root.urlLooksValid(printerUrlField.text)
            type: Kirigami.MessageType.Warning
            text: i18n("Enter a full URL starting with http:// or https://, without a username or password in it")
        }

        QQC2.TextField {
            id: usernameField
            Kirigami.FormData.label: i18n("Username:")
            enabled: apiKeyField.text.length === 0
            placeholderText: "maker"
        }

        QQC2.TextField {
            id: passwordField
            Kirigami.FormData.label: i18n("Password:")
            enabled: apiKeyField.text.length === 0
            echoMode: TextInput.PasswordEchoOnEdit
            placeholderText: i18n("Shown on the printer under Settings → Network → PrusaLink")
        }

        QQC2.TextField {
            id: apiKeyField
            Kirigami.FormData.label: i18n("API key:")
            echoMode: TextInput.PasswordEchoOnEdit
            placeholderText: i18n("Optional, replaces username and password")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: apiKeyField.text.length > 0
            type: Kirigami.MessageType.Information
            text: i18n("Print thumbnails need the username and password; they are not shown when an API key is used.")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: passwordField.text.length > 0 || apiKeyField.text.length > 0
            type: Kirigami.MessageType.Information
            text: i18n("Stored in plain text in plasma-org.kde.plasma.desktop-appletsrc")
        }

        QQC2.TextField {
            id: webUiUrlField
            Kirigami.FormData.label: i18n("Web UI URL:")
            placeholderText: printerUrlField.text.length > 0 ? printerUrlField.text : i18n("Same as printer URL")
        }

        QQC2.SpinBox {
            id: pollActiveField
            Kirigami.FormData.label: i18n("Poll interval while printing (s):")
            from: 1
            to: 3600
        }

        QQC2.SpinBox {
            id: pollIdleField
            Kirigami.FormData.label: i18n("Poll interval while idle (s):")
            from: 1
            to: 3600
        }

        QQC2.CheckBox {
            id: showThumbnailField
            Kirigami.FormData.label: i18n("Panel:")
            text: i18n("Show print thumbnail when available")
        }
    }
}
