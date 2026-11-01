// AI Usage panel — unified SpaceXAI plan with Cursor / Grok Bot / Chat breakdown.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "io.github.hurlydesousa.ai-usage"
    manageIpc: false

    property var anchorItem: null
    property var hostWidget: null
    property var settings: ({})
    readonly property var barIdentity: hostWidget || root

    property var snapshot: ({ agents: [] })
    property bool updating: false
    property bool updatePending: false
    property bool showSettings: false
    property bool backgroundUpdateTried: false
    readonly property string appVersion: "0.7.0"

    readonly property string pluginDir: {
        var s = String(Qt.resolvedUrl("."))
        if (s.indexOf("file://") === 0)
            s = decodeURIComponent(s.slice(7))
        if (s.length > 1 && s.charAt(s.length - 1) === "/")
            s = s.slice(0, s.length - 1)
        return s
    }
    readonly property string backend: pluginDir + "/omarchy-ai-usage"

    readonly property string emDash: "\u2014"
    readonly property int refreshMs: 300000

    // Live Omarchy theme tokens — Color/Style update on `omarchy theme set`.
    readonly property color themeForeground: bar ? bar.foreground : OmColor.foreground
    readonly property color themeUrgent: (bar && bar.urgent) ? bar.urgent : OmColor.urgent
    readonly property color cardSurface: {
        var _live = Style.normalFill
        return Style.normalFillFor(themeForeground, OmColor.accent, OmColor.urgent)
    }
    readonly property color barTrack: {
        var _live = Style.selectedFill
        return Style.selectedFillFor(themeForeground, OmColor.accent, OmColor.urgent)
    }
    readonly property color cursorBarFill: OmColor.accent
    readonly property color otherBarFill: themeForeground
    readonly property color grokBotBarFill: OmColor.accent
    readonly property color mutedCaption: OmColor.muted

    // Per-widget options live on this widget's entry in shell.json.
    function setting(name, fallback) {
        var value = root.settings ? root.settings[name] : undefined
        return value === undefined || value === null ? fallback : value
    }

    // Text on the right of a section title: the user's own label, else the plan.
    function sectionLabel(key, agent, hiddenTier) {
        var label = root.setting(key, "")
        if (label !== "") return String(label)
        var tier = agent && agent.tierLabel ? String(agent.tierLabel) : ""
        return tier === hiddenTier ? "" : tier
    }

    function allowRenewal(provider) {
        if (consentProc.running) return
        consentProc.command = [root.backend, "consent", provider, "on"]
        consentProc.running = true
    }

    function splitMeterTitle(label) {
        var text = String(label || "Usage")
        var idx = text.indexOf(" \u00b7 ")
        if (idx < 0)
            return { bold: text, rest: "" }
        return { bold: text.slice(0, idx), rest: text.slice(idx) }
    }

    function open() {
        root.controller.show()
        root.backgroundUpdateTried = false
        refresh()
    }

    function openFromHotkey() {
        root.open()
    }

    function close() {
        root.showSettings = false
        root.controller.hide()
    }

    function toggle() {
        if (root.opened) root.close()
        else root.openFromHotkey()
    }

    function refresh() {
        if (usageProc.running)
            usageProc.running = false
        usageProc.running = true
    }

    // Never kill a running update: it may be mid-way through saving a renewed
    // grok sign-in.
    function updateAndRefresh() {
        if (updateProc.running) {
            root.updatePending = true
            return
        }
        root.updating = true
        updateProc.running = true
    }

    function agentById(id) {
        var agents = root.snapshot.agents || []
        for (var i = 0; i < agents.length; i++) {
            if (agents[i].id === id) return agents[i]
        }
        return null
    }

    // The backend stores every percent as a fraction of 1.
    function limitPercent(limit) {
        if (!limit) return null
        var p = Number(limit.percent)
        if (!isFinite(p)) return null
        return Math.max(0, Math.min(1, p))
    }

    function percentLabel(limit) {
        var p = limitPercent(limit)
        return p === null ? root.emDash : Math.round(p * 100) + "% used"
    }

    function statusLine(agent) {
        if (!agent) return "No data yet"
        if (agent.authHelpText) return agent.authHelpText
        if (agent.usageStatusText) return agent.usageStatusText
        return agent.available ? "" : "No data yet"
    }

    Process {
        id: usageProc
        stdout: SplitParser {
            onRead: function(line) {
                var l = line.trim()
                if (!l) return
                try { root.snapshot = JSON.parse(l) } catch (e) { return }
                if (root.opened && root.snapshot.stale === true && !root.backgroundUpdateTried && !root.updating) {
                    root.backgroundUpdateTried = true
                    root.updateAndRefresh()
                }
            }
        }
        command: [root.backend, "read"]
    }

    Process {
        id: updateProc
        onRunningChanged: {
            if (running) return
            root.updating = false
            if (root.updatePending) {
                root.updatePending = false
                root.updateAndRefresh()
                return
            }
            root.refresh()
        }
        command: [root.backend, "update"]
    }

    // A hung update must not leave the panel on "Updating…" forever.
    Timer {
        interval: 120000
        repeat: false
        running: updateProc.running
        onTriggered: updateProc.signal(15)
    }

    Process {
        id: consentProc
        onRunningChanged: {
            if (!running && root.opened) root.updateAndRefresh()
        }
    }

    Timer {
        id: refreshTimer
        interval: root.refreshMs
        repeat: true
        running: root.opened
        triggeredOnStart: false
        onTriggered: {
            root.backgroundUpdateTried = false
            root.updateAndRefresh()
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.barIdentity
        bar: root.bar
        open: root.opened
        centerOnBar: false
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(440))
        contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight, Style.space(820))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(direction) {
                if (root.hostWidget && root.hostWidget.switchPanel)
                    root.hostWidget.switchPanel(direction)
                else if (typeof root.switchPanel === "function")
                    root.switchPanel(direction)
            }

            Flickable {
                id: flick
                anchors.fill: parent
                contentWidth: width
                contentHeight: mainColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: mainColumn
                    width: flick.width
                    spacing: Style.space(10)

                    RowLayout {
                        width: parent.width - Style.space(32)
                        x: Style.space(16)
                        spacing: Style.space(8)

                        Label {
                            text: "AI Usage"
                            font.pixelSize: Style.font.title
                            font.bold: true
                            color: root.bar.foreground
                            font.family: root.bar.fontFamily
                            Layout.fillWidth: true
                        }

                        Label {
                            visible: root.updating
                            text: "Updating\u2026"
                            color: Qt.darker(root.bar.foreground, 1.3)
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.caption
                        }

                        Rectangle {
                            width: 26; height: 26; radius: Style.cornerRadius
                            opacity: root.updating ? 0.5 : 1.0
                            color: Style.hoverFillFor(root.bar.foreground, OmColor.accent)
                            Label {
                                anchors.centerIn: parent
                                text: "󰑐"
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.body
                                color: root.bar.foreground
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !root.updating
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.updateAndRefresh()
                            }
                        }

                        Rectangle {
                            width: 26; height: 26; radius: Style.cornerRadius
                            color: root.showSettings
                                ? Style.hoverFillFor(root.bar.foreground, OmColor.accent) : "transparent"
                            Label {
                                anchors.centerIn: parent
                                text: "󰒓"
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.body
                                color: root.showSettings
                                    ? Style.hoverStateColor(root.bar.foreground, OmColor.accent)
                                    : Qt.darker(root.bar.foreground, 1.4)
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.showSettings = !root.showSettings
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Style.spacing.hairline
                        color: root.bar.foreground
                        opacity: 0.12
                    }

                    Column {
                        visible: root.showSettings
                        width: parent.width - Style.space(32)
                        x: Style.space(16)
                        spacing: Style.space(10)

                        Label {
                            text: "About"
                            color: Qt.darker(root.bar.foreground, 1.4)
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.caption
                            font.letterSpacing: 1
                        }

                        Label {
                            text: "Version " + root.appVersion
                            color: root.bar.foreground
                            font.family: root.bar.fontFamily
                            font.pixelSize: Style.font.body
                        }
                    }

                    Column {
                        visible: !root.showSettings
                        width: parent.width - Style.space(32)
                        x: Style.space(16)
                        spacing: Style.space(14)

                        SpaceXaiUsageSection {
                            width: parent.width
                            visible: root.setting("showSpaceXai", true) !== false
                            agent: root.agentById("spacexai")
                            bar: root.bar
                            emDash: root.emDash
                            percentLabel: root.percentLabel
                            limitPercent: root.limitPercent
                            statusLine: root.statusLine(root.agentById("spacexai"))
                            splitMeterTitle: root.splitMeterTitle
                            cardSurface: root.cardSurface
                            barTrack: root.barTrack
                            cursorBarFill: root.cursorBarFill
                            otherBarFill: root.otherBarFill
                            grokBotBarFill: root.grokBotBarFill
                            mutedCaption: root.mutedCaption
                        }

                        SectionNameRow {
                            width: parent.width
                            visible: titleText !== ""
                            titleText: String(root.setting("footerTitle", ""))
                            titleBold: true
                            titleSize: Style.font.caption
                            restText: String(root.setting("footerDetail", ""))
                            modelMeta: String(root.setting("footerLabel", ""))
                        }
                    }
                }
            }
        }
    }

    component SectionNameRow: RowLayout {
        property string titleText: ""
        property string restText: ""
        property string modelMeta: ""
        property bool titleBold: false
        property int titleSize: Style.font.bodySmall

        spacing: Style.space(8)
        width: parent ? parent.width : 0

        Row {
            spacing: 0
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            clip: true

            Label {
                text: titleText
                textFormat: Text.PlainText
                font.bold: titleBold
                font.pixelSize: titleSize
                font.family: root.bar.fontFamily
                color: root.bar.foreground
            }
            Label {
                visible: restText !== ""
                text: restText
                textFormat: Text.PlainText
                font.pixelSize: titleSize
                font.family: root.bar.fontFamily
                color: root.bar.foreground
            }
        }

        Label {
            visible: modelMeta !== ""
            text: modelMeta
            textFormat: Text.PlainText
            color: root.mutedCaption
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignRight
            wrapMode: Text.NoWrap
            elide: Text.ElideLeft
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: parent.width * 0.68
        }
    }

    component MeterBar: Item {
        property real fraction: 0
        property string barStyle: "cursor"
        property color trackColor: Style.selectedFill
        property color fillColor: OmColor.accent
        readonly property bool alarming: fraction >= 0.9
        height: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: parent.trackColor
            Rectangle {
                height: parent.height
                width: parent.width * Math.max(0, Math.min(1, fraction))
                radius: parent.radius
                color: parent.parent.alarming ? root.themeUrgent : parent.parent.fillColor
                Behavior on width {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    component UsageMeterRow: Column {
        id: row
        property var limit
        property var bar
        property var percentLabel
        property var limitPercent
        property var splitMeterTitle
        property color barTrack
        property color cursorBarFill
        property color otherBarFill
        property color grokBotBarFill
        property color mutedCaption

        spacing: Style.space(6)
        width: parent.width

        readonly property var titleParts: splitMeterTitle
            ? splitMeterTitle(limit ? (limit.label || limit.title || "Usage") : "")
            : ({ bold: limit ? (limit.label || limit.title || "Usage") : "", rest: "" })

        // Limit titles come from provider APIs; the title label is rich text.
        function escapeHtml(value) {
            return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        }
        readonly property string rowCaption: {
            if (!limit) return ""
            if (limit.caption) return limit.caption
            if (limit.resetCaption) return limit.resetCaption
            return ""
        }
        readonly property string meterStyle: {
            if (!limit || !limit.barStyle) return "cursor"
            if (limit.barStyle === "muted") return "muted"
            if (limit.barStyle === "grokbot") return "grokbot"
            return "cursor"
        }
        readonly property color meterFill: {
            if (meterStyle === "muted") return otherBarFill
            if (meterStyle === "grokbot") return grokBotBarFill
            return cursorBarFill
        }

        RowLayout {
            width: parent.width
            spacing: Style.space(8)

            Label {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                wrapMode: Text.WordWrap
                textFormat: Text.RichText
                text: "<b>" + row.escapeHtml(row.titleParts.bold) + "</b>" + row.escapeHtml(row.titleParts.rest)
                color: bar.foreground
                font.family: bar.fontFamily
                font.pixelSize: Style.font.bodySmall
            }

            Label {
                text: limit ? percentLabel(limit) : ""
                textFormat: Text.PlainText
                color: (limit && limitPercent && (limitPercent(limit) || 0) >= 0.9)
                    ? root.themeUrgent : bar.foreground
                font.family: bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignRight
                Layout.alignment: Qt.AlignTop
            }
        }

        MeterBar {
            width: parent.width
            fraction: limit ? (limitPercent(limit) || 0) : 0
            barStyle: row.meterStyle
            trackColor: row.barTrack
            fillColor: row.meterFill
        }

        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: rowCaption !== ""
            text: rowCaption
            textFormat: Text.PlainText
            color: row.mutedCaption
            font.family: bar.fontFamily
            font.pixelSize: Style.font.caption
            topPadding: Style.space(2)
        }
    }

    component UsageCard: BorderSurface {
        id: card
        property var limits
        property var bar
        property var percentLabel
        property var limitPercent
        property var splitMeterTitle
        property color cardSurface
        property color barTrack
        property color cursorBarFill
        property color otherBarFill
        property color grokBotBarFill
        property color mutedCaption
        property string statusLine: ""
        property string notice: ""
        property bool showMeters: true

        radius: Style.cornerRadius
        color: card.cardSurface
        borderSpec: Border.controlSpec("normal", bar ? bar.foreground : OmColor.foreground, OmColor.accent)
        implicitWidth: parent ? parent.width : 0
        implicitHeight: cardColumn.implicitHeight + Style.space(28)

        Column {
            id: cardColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(14)
            spacing: Style.space(14)

            Repeater {
                model: card.showMeters ? (card.limits || []) : []
                delegate: UsageMeterRow {
                    required property var modelData
                    width: parent.width
                    limit: modelData
                    bar: card.bar
                    percentLabel: card.percentLabel
                    limitPercent: card.limitPercent
                    splitMeterTitle: card.splitMeterTitle
                    barTrack: card.barTrack
                    cursorBarFill: card.cursorBarFill
                    otherBarFill: card.otherBarFill
                    grokBotBarFill: card.grokBotBarFill
                    mutedCaption: card.mutedCaption
                }
            }

            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: card.statusLine !== "" && (!card.showMeters || !(card.limits || []).length)
                text: card.statusLine
                textFormat: Text.PlainText
                color: card.mutedCaption
                font.family: card.bar.fontFamily
                font.pixelSize: Style.font.caption
            }

            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: card.notice !== "" && card.showMeters
                text: card.notice
                textFormat: Text.PlainText
                color: root.themeUrgent
                font.family: card.bar.fontFamily
                font.pixelSize: Style.font.caption
            }
        }
    }

    component BreakdownMeterRow: Column {
        id: breakdownRow
        property var entry
        property var bar
        property var percentLabel
        property var limitPercent
        property color barTrack
        property color cursorBarFill
        property color otherBarFill
        property color grokBotBarFill
        property color mutedCaption

        spacing: Style.space(4)
        width: parent.width

        readonly property var asLimit: ({
            label: entry ? (entry.label || "") : "",
            title: entry ? (entry.label || "") : "",
            percent: entry ? entry.percent : null,
            barStyle: entry && entry.barStyle ? entry.barStyle : "accent",
            caption: entry && entry.detail ? entry.detail : ""
        })

        RowLayout {
            width: parent.width
            spacing: Style.space(8)

            Label {
                Layout.fillWidth: true
                text: breakdownRow.asLimit.label
                textFormat: Text.PlainText
                color: bar.foreground
                font.family: bar.fontFamily
                font.pixelSize: Style.font.caption
            }

            Label {
                text: percentLabel(breakdownRow.asLimit)
                textFormat: Text.PlainText
                color: (limitPercent(breakdownRow.asLimit) || 0) >= 0.9
                    ? root.themeUrgent : mutedCaption
                font.family: bar.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignRight
            }
        }

        MeterBar {
            width: parent.width
            height: Math.max(Style.space(3), Math.round(Style.spacing.controlHeight * 0.10))
            fraction: limitPercent(breakdownRow.asLimit) || 0
            barStyle: breakdownRow.asLimit.barStyle
            trackColor: barTrack
            fillColor: {
                if (breakdownRow.asLimit.barStyle === "muted") return otherBarFill
                if (breakdownRow.asLimit.barStyle === "grokbot") return grokBotBarFill
                return cursorBarFill
            }
        }

        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: breakdownRow.asLimit.caption !== ""
            text: breakdownRow.asLimit.caption
            textFormat: Text.PlainText
            color: mutedCaption
            font.family: bar.fontFamily
            font.pixelSize: Style.font.caption
        }
    }

    component SpaceXaiUsageSection: Column {
        id: spaceSection
        property var agent
        property var bar
        property string emDash
        property var percentLabel
        property var limitPercent
        property string statusLine: ""
        property var splitMeterTitle
        property color cardSurface
        property color barTrack
        property color cursorBarFill
        property color otherBarFill
        property color grokBotBarFill
        property color mutedCaption

        spacing: Style.space(8)
        width: parent.width

        SectionNameRow {
            width: parent.width
            titleText: "SpaceXAI"
            modelMeta: root.sectionLabel("spaceXaiLabel", spaceSection.agent, "SpaceXAI Plan")
        }

        UsageCard {
            width: parent.width
            bar: spaceSection.bar
            limits: spaceSection.agent ? (spaceSection.agent.limits || []) : []
            notice: spaceSection.agent && spaceSection.agent.notice ? spaceSection.agent.notice : ""
            percentLabel: spaceSection.percentLabel
            limitPercent: spaceSection.limitPercent
            splitMeterTitle: spaceSection.splitMeterTitle
            cardSurface: spaceSection.cardSurface
            barTrack: spaceSection.barTrack
            cursorBarFill: spaceSection.cursorBarFill
            otherBarFill: spaceSection.otherBarFill
            grokBotBarFill: spaceSection.grokBotBarFill
            mutedCaption: spaceSection.mutedCaption
            statusLine: spaceSection.statusLine
            showMeters: spaceSection.agent && (spaceSection.agent.limits || []).length > 0
        }

        Column {
            width: parent.width
            spacing: Style.space(8)
            visible: spaceSection.agent && (spaceSection.agent.breakdown || []).length > 0

            Label {
                text: "Usage breakdown"
                color: spaceSection.mutedCaption
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 0.6
            }

            BorderSurface {
                width: parent.width
                radius: Style.cornerRadius
                color: spaceSection.cardSurface
                borderSpec: Border.controlSpec("normal", root.bar.foreground, OmColor.accent)
                implicitHeight: breakdownColumn.implicitHeight + Style.space(24)

                Column {
                    id: breakdownColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(12)
                    spacing: Style.space(10)

                    Repeater {
                        model: spaceSection.agent ? (spaceSection.agent.breakdown || []) : []
                        delegate: BreakdownMeterRow {
                            required property var modelData
                            width: parent.width
                            entry: modelData
                            bar: spaceSection.bar
                            percentLabel: spaceSection.percentLabel
                            limitPercent: spaceSection.limitPercent
                            barTrack: spaceSection.barTrack
                            cursorBarFill: spaceSection.cursorBarFill
                            otherBarFill: spaceSection.otherBarFill
                            grokBotBarFill: spaceSection.grokBotBarFill
                            mutedCaption: spaceSection.mutedCaption
                        }
                    }
                }
            }
        }

        RenewSignInButton {
            agent: spaceSection.agent
            provider: "grok"
            bar: spaceSection.bar
        }
    }

    // Offered while a sign-in has lapsed and renewal is off. Pressing it is the
    // consent to rewrite that app's credential file, so it only appears here.
    component RenewSignInButton: WidgetButton {
        property var agent
        property string provider

        visible: !!(agent && agent.renewOffered)
        text: consentProc.running ? "Renewing…" : "Renew this sign-in automatically"
        fontSize: Style.font.caption
        onPressed: root.allowRenewal(provider)
    }
}
