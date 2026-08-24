pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.thecdrz.sabarchy"
  ipcTarget: moduleName
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var pipeline: null
  property string historyFilter: "all"
  property bool confirmingClear: pipeline ? Boolean(pipeline.setting("_demoConfirmClear", false)) : false
  property string expandedJobId: pipeline && pipeline.demoExpandFirst && downloadJobs.length ? String(downloadJobs[0].id) : ""
  property double nowMs: Date.now()
  property string focusSection: downloadJobs.length > 0 ? "download" : (verifyJobs.length > 0 ? "verify" : (unpackJobs.length > 0 ? "unpack" : "history"))
  property int activeIndex: 0
  property int historyIndex: 0
  property string expandedHistoryId: pipeline && pipeline.demoExpandHistory && recentJobs.length ? String(recentJobs[0].id) : ""
  readonly property var barIdentity: hostWidget || root
  readonly property var pipelineData: pipeline ? pipeline.snapshot : ({})
  readonly property bool connected: pipeline ? pipeline.connected : false
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var downloadJobs: pipelineData && pipelineData.stages ? (pipelineData.stages.download || []) : []
  readonly property var verifyJobs: pipelineData && pipelineData.stages ? (pipelineData.stages.verify || []) : []
  readonly property var unpackJobs: pipelineData && pipelineData.stages ? (pipelineData.stages.unpack || []) : []
  readonly property var activeJobs: [].concat(downloadJobs, verifyJobs, unpackJobs)
  readonly property var recentJobs: pipelineData && pipelineData.stages ? (pipelineData.stages.recent || []) : []
  readonly property var filteredRecentJobs: recentJobs.filter(function(item) {
    if (historyFilter === "issues") return item.failed === true
    if (historyFilter === "completed") return item.failed !== true
    return true
  })
  readonly property bool forceCompact: pipeline ? Boolean(pipeline.setting("_demoCompact", false)) : false
  readonly property bool compact: forceCompact || (panel.width > 0 && panel.width < Style.space(760))
  readonly property int queueTotal: pipelineData && pipelineData.counts ? Number(pipelineData.counts.active_total !== undefined ? pipelineData.counts.active_total : activeJobs.length) : activeJobs.length
  readonly property int downloadQueueTotal: pipelineData && pipelineData.counts ? Number(pipelineData.counts.queue_total || downloadJobs.length) : downloadJobs.length
  readonly property int historyTotal: pipelineData && pipelineData.counts ? Number(pipelineData.counts.history_total || recentJobs.length) : recentJobs.length
  readonly property int issueCount: pipelineData && pipelineData.counts ? Number(pipelineData.counts.failed || 0) : 0
  readonly property int completedCount: pipelineData && pipelineData.counts ? Number(pipelineData.counts.completed || 0) : 0
  readonly property bool diskLow: pipelineData && pipelineData.disk ? pipelineData.disk.low === true : false
  readonly property bool staleMode: pipeline ? pipeline.stale || Boolean(pipeline.setting("_demoStale", false)) : false
  readonly property bool actionable: connected && !staleMode

  onDownloadJobsChanged: clampActiveIndex()
  onVerifyJobsChanged: clampActiveIndex()
  onUnpackJobsChanged: clampActiveIndex()
  onFilteredRecentJobsChanged: {
    historyIndex = Math.max(0, Math.min(historyIndex, filteredRecentJobs.length - 1))
    if (filteredRecentJobs.length === 0 && activeJobs.length > 0 && focusSection === "history") {
      focusSection = downloadJobs.length > 0 ? "download" : (verifyJobs.length > 0 ? "verify" : "unpack")
    }
  }

  function clampActiveIndex() {
    var jobs = sectionJobs(focusSection)
    if (focusSection !== "history") activeIndex = Math.max(0, Math.min(activeIndex, Math.max(0, jobs.length - 1)))
    if (activeJobs.length === 0 && filteredRecentJobs.length > 0) focusSection = "history"
    else if (focusSection === "download" && downloadJobs.length === 0) focusSection = verifyJobs.length > 0 ? "verify" : (unpackJobs.length > 0 ? "unpack" : "history")
    else if (focusSection === "verify" && verifyJobs.length === 0) focusSection = downloadJobs.length > 0 ? "download" : (unpackJobs.length > 0 ? "unpack" : "history")
    else if (focusSection === "unpack" && unpackJobs.length === 0) focusSection = downloadJobs.length > 0 ? "download" : (verifyJobs.length > 0 ? "verify" : "history")
  }

  function orderedSections() {
    var sections = []
    if (downloadJobs.length > 0) sections.push("download")
    if (verifyJobs.length > 0) sections.push("verify")
    if (unpackJobs.length > 0) sections.push("unpack")
    if (filteredRecentJobs.length > 0) sections.push("history")
    if (sections.length === 0) sections.push("download")
    return sections
  }

  function sectionJobs(section) {
    if (section === "download") return downloadJobs
    if (section === "verify") return verifyJobs
    if (section === "unpack") return unpackJobs
    return filteredRecentJobs
  }

  function sectionList(section) {
    if (section === "download") return downloadList
    if (section === "verify") return verifyList
    if (section === "unpack") return unpackList
    return recentList
  }

  function jobStageKind(status) {
    var value = String(status || "").toLowerCase()
    if (value.indexOf("verify") >= 0 || value.indexOf("repair") >= 0 || value.indexOf("check") >= 0) return "verify"
    if (value.indexOf("extract") >= 0 || value.indexOf("unpack") >= 0 || value.indexOf("mov") >= 0 || value.indexOf("run") >= 0) return "unpack"
    return "download"
  }

  function stageColor(job) {
    if (!job) return Color.accent
    if (job.failed === true || String(job.status || "").toLowerCase() === "paused") return Color.urgent
    var kind = jobStageKind(job.status)
    if (kind === "verify") return Qt.lighter(Color.accent, 1.12)
    if (kind === "unpack") return Qt.darker(Color.accent, 1.08)
    return Color.accent
  }

  function historyColor(job) {
    return job && job.failed === true ? Color.urgent : Color.accent
  }

  function lastUpdatedLabel() {
    if (!pipeline || !pipeline.lastSuccessMs) return ""
    var seconds = Math.max(0, Math.round((nowMs - pipeline.lastSuccessMs) / 1000))
    if (seconds < 60) return seconds + "s ago"
    return Math.floor(seconds / 60) + "m ago"
  }

  function moveSelection(dy) {
    if (dy === 0) return
    var sections = orderedSections()
    var sectionIdx = sections.indexOf(focusSection)
    if (focusSection !== "history") {
      var jobs = sectionJobs(focusSection)
      var nextActive = activeIndex + dy
      if (nextActive >= 0 && nextActive < jobs.length) {
        activeIndex = nextActive
        sectionList(focusSection).positionViewAtIndex(activeIndex, ListView.Contain)
        return
      }
      if (nextActive >= jobs.length && sectionIdx < sections.length - 1) {
        focusSection = sections[sectionIdx + 1]
        activeIndex = 0
        historyIndex = 0
        sectionList(focusSection).positionViewAtIndex(0, ListView.Contain)
        return
      }
      if (nextActive < 0 && sectionIdx > 0) {
        focusSection = sections[sectionIdx - 1]
        if (focusSection === "history") {
          historyIndex = Math.max(0, filteredRecentJobs.length - 1)
          recentList.positionViewAtIndex(historyIndex, ListView.Contain)
        } else {
          activeIndex = Math.max(0, sectionJobs(focusSection).length - 1)
          sectionList(focusSection).positionViewAtIndex(activeIndex, ListView.Contain)
        }
        return
      }
    } else if (filteredRecentJobs.length > 0) {
      var nextHistory = historyIndex + dy
      if (nextHistory >= 0 && nextHistory < filteredRecentJobs.length) {
        historyIndex = nextHistory
        recentList.positionViewAtIndex(historyIndex, ListView.Contain)
        return
      }
      if (nextHistory < 0 && sectionIdx > 0) {
        focusSection = sections[sectionIdx - 1]
        activeIndex = Math.max(0, sectionJobs(focusSection).length - 1)
        sectionList(focusSection).positionViewAtIndex(activeIndex, ListView.Contain)
        return
      }
    }
  }

  function activateSelection() {
    if (focusSection !== "history") {
      var jobs = sectionJobs(focusSection)
      if (jobs.length === 0) return
      activeIndex = Math.max(0, Math.min(activeIndex, jobs.length - 1))
      var id = String(jobs[activeIndex].id)
      expandedJobId = expandedJobId === id ? "" : id
    } else if (filteredRecentJobs.length > 0) {
      historyIndex = Math.max(0, Math.min(historyIndex, filteredRecentJobs.length - 1))
      var historyId = String(filteredRecentJobs[historyIndex].id)
      expandedHistoryId = expandedHistoryId === historyId ? "" : historyId
    }
  }

  function setupTitle() {
    var state = String(pipelineData.state || "")
    if (state === "not-configured") return "CONNECT SABNZBD"
    if (state === "offline") return "SABNZBD ISN'T RUNNING"
    if (state === "configuration-error") return "CHECK SABNZBD CONFIGURATION"
    return "CAN'T REACH SABNZBD"
  }

  function setupMessage() {
    var state = String(pipelineData.state || "")
    if (state === "not-configured") return "Start SABnzbd once so it can create its configuration and API key."
    if (state === "offline") return "Start SABnzbd, then retry. Your dashboard will connect automatically."
    return String((pipeline && pipeline.lastError) || pipelineData.message || "Check the configured path and local SABnzbd API settings.")
  }

  function statusIcon(status) {
    var value = String(status || "").toLowerCase()
    if (value.indexOf("download") >= 0) return "󰇚"
    if (value.indexOf("verify") >= 0 || value.indexOf("repair") >= 0 || value.indexOf("check") >= 0) return "󰄬"
    if (value.indexOf("extract") >= 0 || value.indexOf("unpack") >= 0) return "󰏖"
    if (value.indexOf("mov") >= 0) return "󰁔"
    if (value.indexOf("fail") >= 0) return "󰅙"
    if (value.indexOf("complete") >= 0) return "󰄴"
    return "󰑪"
  }

  function open() {
    if (pipeline) pipeline.refresh()
    controller.show()
    Qt.callLater(function() { if (opened) setCenterHoverRevealSuppressed(true) })
  }
  function close() { setCenterHoverRevealSuppressed(false); controller.hide() }
  function toggle() { if (opened) close(); else open() }
  function closeForPopoutSwitch() { close() }
  function switchPanel(direction) {
    if (bar && typeof bar.switchPanelFrom === "function") return bar.switchPanelFrom(barIdentity, direction)
    return false
  }
  function setCenterHoverRevealSuppressed(value) {
    if (bar && "centerHoverRevealSuppressed" in bar) bar.centerHoverRevealSuppressed = value
  }

  function activeRowHeight(section) {
    if (section === "verify" || section === "unpack")
      return root.compact ? Style.space(34) : Style.space(38)
    return root.compact ? Style.space(92) : Style.space(112)
  }

  function activeListHeight(jobCount, section) {
    if (jobCount <= 0) return 0
    var rowHeight = activeRowHeight(section)
    var processing = section === "verify" || section === "unpack"
    var maxVisible = processing ? 2 : (root.compact ? 3 : 3.25)
    var visibleRows = Math.min(jobCount, maxVisible)
    var expandedExtra = !processing && root.expandedJobId !== "" ? Style.space(62) : 0
    return visibleRows * rowHeight + Math.max(0, Math.min(jobCount - 1, maxVisible - 1)) * Style.space(processing ? 6 : 10) + expandedExtra
  }

  component ProcessingJobCard: Rectangle {
    id: processingCard
    required property var jobData
    required property int jobIndex
    required property string jobSection
    required property var listView
    readonly property bool selected: root.focusSection === processingCard.jobSection && root.activeIndex === processingCard.jobIndex
    readonly property color stateColor: root.stageColor(processingCard.jobData)
    readonly property real progressRatio: Math.max(0, Math.min(1, Number(processingCard.jobData.progress || 0) / 100))
    width: processingCard.listView.width
    height: root.activeRowHeight(processingCard.jobSection)
    radius: Math.max(3, Style.cornerRadius - 2)
    color: selected
      ? Qt.rgba(processingCard.stateColor.r, processingCard.stateColor.g, processingCard.stateColor.b, 0.1)
      : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.03)
    border.width: selected ? Style.spacing.hairline : 0
    border.color: processingCard.stateColor
    Rectangle { width: Style.spacing.hairline * 2; height: parent.height; radius: parent.radius; color: processingCard.stateColor }
    Row {
      anchors.fill: parent; anchors.margins: Style.space(8); anchors.leftMargin: Style.space(11); spacing: Style.space(8)
      Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: root.statusIcon(processingCard.jobData.status); color: processingCard.stateColor; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
      Text { textFormat: Text.PlainText;
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, parent.width - progressTrack.width - progressLabel.width - parent.spacing * 3 - Style.space(16))
        text: String(processingCard.jobData.name || "Untitled")
        elide: Text.ElideMiddle
        color: root.contentForeground
        font.family: root.contentFontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
      Rectangle {
        id: progressTrack
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(64)
        height: Style.spacing.hairline * 2
        radius: height / 2
        color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
        Rectangle {
          width: parent.width * processingCard.progressRatio
          height: parent.height
          radius: parent.radius
          color: processingCard.stateColor
          Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        }
      }
      Text { textFormat: Text.PlainText; id: progressLabel; anchors.verticalCenter: parent.verticalCenter; text: Math.round(Number(processingCard.jobData.progress || 0)) + "%"; color: processingCard.stateColor; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: { root.focusSection = processingCard.jobSection; root.activeIndex = processingCard.jobIndex }
    }
  }

  component ActiveJobCard: Rectangle {
    id: activeCard
    required property var jobData
    required property int jobIndex
    required property string jobSection
    required property var listView
    readonly property bool selected: root.focusSection === activeCard.jobSection && root.activeIndex === activeCard.jobIndex
    readonly property bool expanded: root.expandedJobId === String(activeCard.jobData.id)
    readonly property color stateColor: root.stageColor(activeCard.jobData)
    width: activeCard.listView.width
    height: (root.compact ? Style.space(92) : Style.space(112)) + (expanded ? Style.space(62) : 0)
    radius: Style.cornerRadius
    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    color: "transparent"
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Qt.rgba(activeCard.stateColor.r, activeCard.stateColor.g, activeCard.stateColor.b, 0.11) }
      GradientStop { position: 0.32; color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.045) }
      GradientStop { position: 1.0; color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.025) }
    }
    border.width: selected ? Style.space(2) : Style.spacing.hairline
    border.color: selected ? activeCard.stateColor : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.15)
    Rectangle { width: Style.space(4); height: parent.height; radius: parent.radius; color: activeCard.stateColor }
    Column {
      anchors.fill: parent; anchors.margins: Style.space(16); anchors.leftMargin: Style.space(20); spacing: Style.space(11)
      Row {
        width: parent.width; spacing: Style.space(12)
        Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: root.statusIcon(activeCard.jobData.status); color: activeCard.stateColor; font.family: root.contentFontFamily; font.pixelSize: Style.font.title }
        Text { textFormat: Text.PlainText;
          id: activeTitle
          anchors.verticalCenter: parent.verticalCenter; width: parent.width - statusPill.width - expandIcon.width - Style.space(66); text: String(activeCard.jobData.name || "Untitled"); elide: Text.ElideMiddle; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; font.bold: true
          MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.focusSection = activeCard.jobSection; root.activeIndex = activeCard.jobIndex; root.expandedJobId = activeCard.expanded ? "" : String(activeCard.jobData.id) } }
        }
        Rectangle {
          id: statusPill
          width: statusLabel.implicitWidth + Style.space(18); height: Style.space(26); radius: height / 2
          color: Qt.rgba(activeCard.stateColor.r, activeCard.stateColor.g, activeCard.stateColor.b, 0.16)
          Behavior on color { ColorAnimation { duration: 220 } }
          Text { textFormat: Text.PlainText; id: statusLabel; anchors.centerIn: parent; text: String(activeCard.jobData.status || "WORKING").toUpperCase(); color: activeCard.stateColor; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.7 }
        }
        Text { textFormat: Text.PlainText; id: expandIcon; anchors.verticalCenter: parent.verticalCenter; text: activeCard.expanded ? "󰅀" : "󰅂"; color: Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; MouseArea { anchors.fill: parent; anchors.margins: -Style.space(8); cursorShape: Qt.PointingHandCursor; onClicked: { root.focusSection = activeCard.jobSection; root.activeIndex = activeCard.jobIndex; root.expandedJobId = activeCard.expanded ? "" : String(activeCard.jobData.id) } } }
      }
      Row {
        width: parent.width; spacing: Style.space(14)
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter; width: parent.width - progressLabel.width - parent.spacing; height: Style.space(7); radius: height / 2
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
          Rectangle {
            width: parent.width * Math.max(0, Math.min(1, Number(activeCard.jobData.progress || 0) / 100)); height: parent.height; radius: parent.radius; color: activeCard.stateColor
            Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
          }
        }
        Text { textFormat: Text.PlainText; id: progressLabel; anchors.verticalCenter: parent.verticalCenter; text: Math.round(Number(activeCard.jobData.progress || 0)) + "%"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; font.bold: true }
      }
      Row {
        width: parent.width; spacing: Style.space(18)
        visible: !root.compact
        Text { textFormat: Text.PlainText; text: String(activeCard.jobData.category || "UNCATEGORIZED").toUpperCase(); color: Qt.darker(root.contentForeground, 1.48); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
        Text { textFormat: Text.PlainText; text: String(activeCard.jobData.size || ""); color: Qt.darker(root.contentForeground, 1.55); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
        Item { width: Math.max(0, parent.width - parent.children[0].width - parent.children[1].width - remainingText.width - parent.spacing * 3); height: 1 }
        Text { textFormat: Text.PlainText; id: remainingText; text: activeCard.jobData.timeleft ? String(activeCard.jobData.timeleft) + " LEFT  ·  " + String(activeCard.jobData.sizeleft || "") : String(activeCard.jobData.sizeleft || ""); color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
      }
      Rectangle {
        visible: activeCard.expanded
        width: parent.width; height: Style.space(45); radius: Math.max(3, Style.cornerRadius - 2)
        color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.045)
        Row {
          anchors.fill: parent; anchors.margins: Style.space(9); spacing: Style.space(12)
          Column {
            anchors.verticalCenter: parent.verticalCenter; width: parent.width - jobAction.width - parent.spacing; spacing: Style.space(3)
            Text { textFormat: Text.PlainText; width: parent.width; text: (String(activeCard.jobData.category || "Uncategorized").toUpperCase()) + "  ·  " + (String(activeCard.jobData.priority || "Normal").toUpperCase()) + " PRIORITY  ·  " + String(activeCard.jobData.size || "Unknown size"); elide: Text.ElideRight; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
            Text { textFormat: Text.PlainText; width: parent.width; text: activeCard.jobData.labels && activeCard.jobData.labels.length ? "LABELS  " + activeCard.jobData.labels.join(" · ") : "Click the control to pause or resume this job only"; elide: Text.ElideRight; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
          }
          Rectangle {
            id: jobAction
            readonly property bool pausedJob: String(activeCard.jobData.status).toLowerCase() === "paused"
            width: Style.space(92); height: parent.height; radius: Style.cornerRadius
            color: jobActionMouse.containsMouse ? Qt.rgba(activeCard.stateColor.r, activeCard.stateColor.g, activeCard.stateColor.b, 0.18) : Qt.rgba(activeCard.stateColor.r, activeCard.stateColor.g, activeCard.stateColor.b, 0.08)
            border.width: Style.spacing.hairline; border.color: activeCard.stateColor
            Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: root.pipeline && root.pipeline.actionJobId === activeCard.jobData.id && root.pipeline.actionFeedback !== "" ? String(root.pipeline.actionFeedback).toUpperCase() : (jobAction.pausedJob ? "󰐊  RESUME" : "󰏤  PAUSE"); color: activeCard.stateColor; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
            MouseArea { id: jobActionMouse; anchors.fill: parent; enabled: root.actionable && root.pipeline && root.pipeline.actionFeedback !== "pausing" && root.pipeline.actionFeedback !== "resuming"; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.pipeline.runJobAction(jobAction.pausedJob ? "job_resume" : "job_pause", activeCard.jobData.id) }
          }
        }
      }
    }
  }

  Timer { interval: 15000; repeat: true; running: root.opened; onTriggered: root.nowMs = Date.now() }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(root.forceCompact ? 620 : ((!root.connected && !root.staleMode) ? 760 : 960)))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: {
        if (root.expandedJobId !== "" || root.expandedHistoryId !== "") { root.expandedJobId = ""; root.expandedHistoryId = "" }
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) { root.moveSelection(dy !== 0 ? dy : dx) }
      onActivateRequested: root.activateSelection()
      onDeleteRequested: { root.expandedJobId = ""; root.expandedHistoryId = "" }
      onTextKey: function(text) {
        if (text === "r") { if (root.pipeline) root.pipeline.refresh() }
        else if (text === "R" && root.actionable && root.focusSection === "history" && root.historyIndex >= 0 && root.historyIndex < root.filteredRecentJobs.length && root.filteredRecentJobs[root.historyIndex].failed && root.pipeline) { root.pipeline.retryJob(root.filteredRecentJobs[root.historyIndex].id) }
        else if (text === "p" && root.actionable && root.focusSection !== "history") {
          var activeJobsInSection = root.sectionJobs(root.focusSection)
          if (root.activeIndex >= 0 && root.activeIndex < activeJobsInSection.length && root.pipeline) {
            var selected = activeJobsInSection[root.activeIndex]
            root.pipeline.runJobAction(String(selected.status).toLowerCase() === "paused" ? "job_resume" : "job_pause", selected.id)
          }
        }
        else if (text === "P") { if (root.actionable && root.pipeline) root.pipeline.runAction(root.pipeline.paused ? "resume" : "pause") }
        else if (text === "f" && root.focusSection === "history" && root.historyIndex >= 0 && root.historyIndex < root.filteredRecentJobs.length && root.pipeline) root.pipeline.openFolder(root.filteredRecentJobs[root.historyIndex].storage)
        else if ((text === "o" || text === "O") && root.pipelineData.web_url) Qt.openUrlExternally(String(root.pipelineData.web_url))
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: contentColumn
          width: parent.width
          spacing: Style.space(18)

          Row {
            width: parent.width
            spacing: Style.space(18)
            Column {
              width: parent.width - controls.width - parent.spacing
              spacing: Style.space(5)
              Row {
                width: parent.width; spacing: Style.space(9)
                SabarchyIcon { anchors.verticalCenter: parent.verticalCenter; width: Style.space(24); height: width; iconColor: !root.connected || root.staleMode || root.issueCount > 0 || root.diskLow ? Color.urgent : Color.accent }
                Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: "SABARCHY"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.title; font.bold: true; font.letterSpacing: 1.4 }
                Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: "SABNZBD DASHBOARD"; color: Qt.darker(root.contentForeground, 1.55); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
              }
              Text { textFormat: Text.PlainText;
                visible: root.connected || root.staleMode
                width: parent.width
                text: root.connected
                  ? ((root.staleMode ? "STALE  ·  LAST UPDATE " + root.lastUpdatedLabel() : (root.pipeline.paused ? "PAUSED" : String(root.pipelineData.queue.status || "IDLE").toUpperCase())) + "  ·  " + String(root.pipelineData.queue.speed || "0 B/s") + "  ·  " + String(root.pipelineData.queue.sizeleft || "0 B") + " REMAINING")
                  : String((root.pipeline && root.pipeline.lastError) || root.pipelineData.message || "SABnzbd is unavailable")
                color: root.connected && !root.staleMode ? Qt.darker(root.contentForeground, 1.35) : Color.urgent
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }
            }
            Row {
              id: controls
              visible: root.connected || root.staleMode
              spacing: Style.space(8)
              Rectangle {
                width: pauseLabel.implicitWidth + Style.space(24); height: Style.space(34); radius: Style.cornerRadius
                color: pauseMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
                border.width: Style.spacing.hairline; border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.18)
                Text { textFormat: Text.PlainText; id: pauseLabel; anchors.centerIn: parent;
                  text: {
                    if (root.pipeline && root.pipeline.actionJobId === "__queue__" && root.pipeline.actionFeedback !== "")
                      return root.compact ? "…" : String(root.pipeline.actionFeedback).toUpperCase()
                    if (root.compact)
                      return root.pipeline && root.pipeline.paused ? "󰐊" : "󰏤"
                    return root.pipeline && root.pipeline.paused ? "󰐊  RESUME" : "󰏤  PAUSE"
                  }
                  color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true
                }
                MouseArea { id: pauseMouse; anchors.fill: parent; enabled: root.actionable; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.pipeline.runAction(root.pipeline.paused ? "resume" : "pause") }
              }
              Rectangle {
                width: openLabel.implicitWidth + Style.space(24); height: Style.space(34); radius: Style.cornerRadius
                color: openMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.05)
                border.width: Style.spacing.hairline; border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.18)
                Text { textFormat: Text.PlainText; id: openLabel; anchors.centerIn: parent; text: root.compact ? "󰏌" : "OPEN SAB  󰏌"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                MouseArea { id: openMouse; anchors.fill: parent; enabled: !!root.pipelineData.web_url; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: Qt.openUrlExternally(String(root.pipelineData.web_url)) }
              }
            }
          }

          Rectangle { width: parent.width; height: Style.spacing.hairline; color: root.contentForeground; opacity: 0.14 }

          Rectangle {
            visible: !root.connected && !root.staleMode
            width: parent.width; height: Style.space(132); radius: Style.cornerRadius
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.035)
            border.width: Style.spacing.hairline; border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.14)
            Row {
              anchors.fill: parent; anchors.margins: Style.space(24); spacing: Style.space(22)
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter; width: Style.space(56); height: width; radius: width / 2
                color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.1)
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "󰑪"; color: Color.urgent; font.family: root.contentFontFamily; font.pixelSize: Style.font.title }
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter; width: parent.width - retrySetup.width - Style.space(118); spacing: Style.space(8)
                Text { textFormat: Text.PlainText; width: parent.width; text: root.setupTitle(); color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.title; font.bold: true; font.letterSpacing: 1 }
                Text { textFormat: Text.PlainText; width: parent.width; text: root.setupMessage(); wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; color: Qt.darker(root.contentForeground, 1.35); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                Text { textFormat: Text.PlainText; width: parent.width; text: "Default config  ~/.sabnzbd/sabnzbd.ini  ·  Change it in widget settings"; elide: Text.ElideRight; color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
              }
              Rectangle {
                id: retrySetup; anchors.verticalCenter: parent.verticalCenter; width: root.compact ? Style.space(72) : Style.space(118); height: Style.space(36); radius: Style.cornerRadius
                color: retrySetupMouse.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.1)
                border.width: Style.spacing.hairline; border.color: Color.accent
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: root.compact ? "󰑐" : "󰑐  RETRY"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                MouseArea { id: retrySetupMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.pipeline) root.pipeline.refresh() }
              }
            }
          }

          Rectangle {
            visible: (root.connected || root.staleMode) && root.diskLow
            width: parent.width; height: Style.space(42); radius: Style.cornerRadius
            color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.09)
            border.width: Style.spacing.hairline; border.color: Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.45)
            Row {
              anchors.fill: parent; anchors.margins: Style.space(11); spacing: Style.space(10)
              Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: "󰋊"; color: Color.urgent; font.family: root.contentFontFamily; font.pixelSize: Style.font.body }
              Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: "LOW DISK SPACE  ·  " + String(root.pipelineData && root.pipelineData.disk ? root.pipelineData.disk.free || "Unknown" : "Unknown") + " FREE"; color: Color.urgent; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
            }
          }

          Row {
            visible: root.connected || root.staleMode
            width: parent.width; spacing: Style.space(14)
            Text { textFormat: Text.PlainText; text: "NOW"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; font.bold: true; font.letterSpacing: 1.2 }
            Text { textFormat: Text.PlainText; text: root.queueTotal === 1 ? "1 ACTIVE JOB" : String(root.queueTotal) + " ACTIVE JOBS"; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
            Text { textFormat: Text.PlainText; visible: root.activeJobs.length > 0; text: String(root.pipelineData && root.pipelineData.queue ? root.pipelineData.queue.timeleft || "0:00:00" : "0:00:00") + " LEFT"; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
          }

          Column {
            visible: root.connected || root.staleMode
            width: parent.width; spacing: Style.space(8)
            Rectangle {
              visible: root.activeJobs.length === 0
              width: parent.width; height: Style.space(126); radius: Style.cornerRadius
              color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.035)
              border.width: Style.spacing.hairline; border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.11)
              Row {
                anchors.centerIn: parent; spacing: Style.space(16)
                Text { textFormat: Text.PlainText; text: "󰑪"; color: Qt.darker(root.contentForeground, 1.55); font.family: root.contentFontFamily; font.pixelSize: Style.font.display }
                Column {
                  anchors.verticalCenter: parent.verticalCenter; spacing: Style.space(4)
                  Text { textFormat: Text.PlainText; text: root.connected ? "QUEUE IS CLEAR" : "WAITING FOR SABNZBD"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; font.bold: true }
                  Text { textFormat: Text.PlainText; text: root.connected ? "New downloads will appear here with live progress and processing state." : "Start SABnzbd to reconnect this dashboard."; color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
                }
              }
            }

            Row {
              visible: root.downloadJobs.length > 0
              width: parent.width; spacing: Style.space(10)
              Text { textFormat: Text.PlainText; text: "DOWNLOADING"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 1 }
              Text { textFormat: Text.PlainText; visible: root.downloadJobs.length > 0; text: String(root.downloadJobs.length); color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
            }

            ListView {
              id: downloadList
              visible: root.downloadJobs.length > 0
              model: root.downloadJobs
              width: parent.width
              height: root.activeListHeight(count, "download")
              Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              spacing: Style.space(10)
              clip: true
              interactive: contentHeight > height
              boundsBehavior: Flickable.StopAtBounds
              Controls.ScrollBar.vertical: Controls.ScrollBar { policy: downloadList.contentHeight > downloadList.height ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff }
              delegate: ActiveJobCard {
                jobData: modelData
                jobIndex: index
                jobSection: "download"
                listView: downloadList
              }
            }

            Row {
              visible: root.verifyJobs.length > 0
              width: parent.width; spacing: Style.space(8)
              Text { textFormat: Text.PlainText; text: "VERIFYING"; color: Qt.lighter(Color.accent, 1.12); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
              Text { textFormat: Text.PlainText; text: String(root.verifyJobs.length); color: Qt.lighter(Color.accent, 1.12); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
            }

            ListView {
              id: verifyList
              visible: root.verifyJobs.length > 0
              model: root.verifyJobs
              width: parent.width
              height: root.activeListHeight(count, "verify")
              Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              spacing: Style.space(6)
              clip: true
              interactive: contentHeight > height
              boundsBehavior: Flickable.StopAtBounds
              Controls.ScrollBar.vertical: Controls.ScrollBar { policy: verifyList.contentHeight > verifyList.height ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff }
              delegate: ProcessingJobCard {
                jobData: modelData
                jobIndex: index
                jobSection: "verify"
                listView: verifyList
              }
            }

            Row {
              visible: root.unpackJobs.length > 0
              width: parent.width; spacing: Style.space(8)
              Text { textFormat: Text.PlainText; text: "UNPACKING"; color: Qt.darker(Color.accent, 1.08); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
              Text { textFormat: Text.PlainText; text: String(root.unpackJobs.length); color: Qt.darker(Color.accent, 1.08); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
            }

            ListView {
              id: unpackList
              visible: root.unpackJobs.length > 0
              model: root.unpackJobs
              width: parent.width
              height: root.activeListHeight(count, "unpack")
              Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
              spacing: Style.space(6)
              clip: true
              interactive: contentHeight > height
              boundsBehavior: Flickable.StopAtBounds
              Controls.ScrollBar.vertical: Controls.ScrollBar { policy: unpackList.contentHeight > unpackList.height ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff }
              delegate: ProcessingJobCard {
                jobData: modelData
                jobIndex: index
                jobSection: "unpack"
                listView: unpackList
              }
            }

            Rectangle {
              visible: root.downloadQueueTotal > root.downloadJobs.length
              width: parent.width; height: Style.space(34); radius: Style.cornerRadius
              color: loadQueueMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : "transparent"
              Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "SHOW MORE  ·  " + root.downloadJobs.length + " OF " + root.downloadQueueTotal; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
              MouseArea { id: loadQueueMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.pipeline) root.pipeline.loadMoreQueue() }
            }
          }

          Row {
            visible: root.connected || root.staleMode
            width: parent.width; spacing: Style.space(8)
            Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: "HISTORY"; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.body; font.bold: true; font.letterSpacing: 1.2 }
            Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: root.historyTotal === 0 ? "CLEAR" : String(root.historyTotal); color: root.historyTotal === 0 ? Color.accent : Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: root.historyTotal === 0 }
            Item { width: root.historyTotal === 0 ? 0 : Math.max(0, parent.width - historyAll.width - historyDone.width - historyIssues.width - historyClear.width - Style.space(190)); height: 1 }
            Rectangle {
              id: historyAll; visible: root.historyTotal > 0; width: Style.space(54); height: Style.space(27); radius: height / 2
              color: root.historyFilter === "all" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16) : "transparent"
              Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "ALL"; color: root.historyFilter === "all" ? Color.accent : Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.historyFilter = "all" }
            }
            Rectangle {
              id: historyDone; visible: root.historyTotal > 0; width: Style.space(76); height: Style.space(27); radius: height / 2
              color: root.historyFilter === "completed" ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.16) : "transparent"
              Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: root.compact ? "DONE" : "COMPLETED"; color: root.historyFilter === "completed" ? Color.accent : Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.historyFilter = "completed" }
            }
            Rectangle {
              id: historyIssues; visible: root.historyTotal > 0; width: Style.space(76); height: Style.space(27); radius: height / 2
              color: root.historyFilter === "issues" ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.16) : "transparent"
              Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "ISSUES " + root.issueCount; color: root.issueCount > 0 ? Color.urgent : Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.historyFilter = "issues" }
            }
            Rectangle {
              id: historyClear; visible: root.historyTotal > 0; width: Style.space(32); height: Style.space(27); radius: height / 2
              color: clearMouse.containsMouse || root.confirmingClear ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1) : "transparent"
              Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "󰆴"; color: Qt.darker(root.contentForeground, 1.35); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              MouseArea { id: clearMouse; anchors.fill: parent; enabled: root.actionable && root.completedCount > 0; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.confirmingClear = !root.confirmingClear }
            }
          }

          Rectangle {
            visible: (root.connected || root.staleMode) && root.confirmingClear
            width: parent.width; height: Style.space(48); radius: Style.cornerRadius
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.045)
            border.width: Style.spacing.hairline; border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.13)
            Row {
              anchors.fill: parent; anchors.margins: Style.space(10); spacing: Style.space(10)
              Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; width: parent.width - cancelClear.width - confirmClear.width - parent.spacing * 2; text: root.compact ? "Archive completed items? Failures stay visible." : "Clear completed history? Items move to SABnzbd’s archive; failures stay visible."; elide: Text.ElideRight; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall }
              Rectangle {
                id: cancelClear; width: Style.space(70); height: parent.height; radius: Style.cornerRadius; color: cancelClearMouse.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1) : "transparent"
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "CANCEL"; color: Qt.darker(root.contentForeground, 1.35); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                MouseArea { id: cancelClearMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmingClear = false }
              }
              Rectangle {
                id: confirmClear; width: root.compact ? Style.space(92) : Style.space(142); height: parent.height; radius: Style.cornerRadius; color: confirmClearMouse.containsMouse ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.2) : Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.1); border.width: Style.spacing.hairline; border.color: Color.urgent
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: root.pipeline && root.pipeline.actionJobId === "__history__" && root.pipeline.actionFeedback !== "" ? String(root.pipeline.actionFeedback).toUpperCase() : (root.compact ? "CLEAR" : "CLEAR COMPLETED"); color: Color.urgent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                MouseArea { id: confirmClearMouse; anchors.fill: parent; enabled: root.actionable && root.pipeline && root.pipeline.actionFeedback !== "clearing"; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: { root.pipeline.clearCompletedHistory(); root.confirmingClear = false } }
              }
            }
          }

          Rectangle {
            visible: (root.connected || root.staleMode) && root.historyTotal > 0
            width: parent.width
            height: recentList.height + Style.space(20) + (root.historyTotal > root.recentJobs.length ? Style.space(34) : 0)
            radius: Style.cornerRadius
            color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.025)
            border.width: Style.spacing.hairline; border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.1)
            ListView {
              id: recentList
              anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Style.space(10)
              height: count === 0 ? Style.space(54) : Math.min(contentHeight, root.compact ? Style.space(180) : Style.space(240))
              model: root.filteredRecentJobs
              spacing: Style.space(2); clip: true; interactive: contentHeight > height; boundsBehavior: Flickable.StopAtBounds
              Controls.ScrollBar.vertical: Controls.ScrollBar { policy: recentList.contentHeight > recentList.height ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff }
              Text { textFormat: Text.PlainText; visible: recentList.count === 0; anchors.centerIn: parent; text: root.historyFilter === "issues" ? "No failures in loaded history" : "No matching history"; color: Qt.darker(root.contentForeground, 1.55); font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.italic: true }
              delegate: Rectangle {
                id: recentCard
                required property var modelData
                required property int index
                readonly property bool expanded: root.expandedHistoryId === String(recentCard.modelData.id)
                readonly property bool selected: root.focusSection === "history" && root.historyIndex === index
                readonly property color itemColor: root.historyColor(recentCard.modelData)
                readonly property bool failedItem: recentCard.modelData.failed === true
                readonly property bool canOpen: !failedItem && Boolean(recentCard.modelData.storage)
                readonly property int retryCount: Number(recentCard.modelData.retry_count || 0)
                width: recentList.width
                height: (recentCard.failedItem ? Style.space(68) : Style.space(44)) + (expanded ? (recentCard.failedItem ? Style.space(78) : Style.space(52)) : 0)
                radius: Math.max(3, Style.cornerRadius - 2)
                color: selected ? Qt.rgba(recentCard.itemColor.r, recentCard.itemColor.g, recentCard.itemColor.b, 0.11) : (recentCard.failedItem ? Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.06) : "transparent")
                border.width: selected ? Style.spacing.hairline : 0; border.color: recentCard.itemColor
                Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Row {
                  anchors.fill: parent; anchors.margins: Style.space(9); spacing: Style.space(10)
                  Text { textFormat: Text.PlainText; anchors.verticalCenter: parent.verticalCenter; text: root.statusIcon(recentCard.modelData.status); color: recentCard.itemColor; font.family: root.contentFontFamily; font.pixelSize: Style.font.body }
                  Column {
                    anchors.verticalCenter: parent.verticalCenter; width: parent.width - retryButton.width - Style.space(52); spacing: Style.space(4)
                    Text { textFormat: Text.PlainText; width: parent.width; text: String(recentCard.modelData.name || "Untitled"); elide: Text.ElideMiddle; color: root.contentForeground; font.family: root.contentFontFamily; font.pixelSize: Style.font.bodySmall; font.bold: recentCard.failedItem; MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.focusSection = "history"; root.historyIndex = recentCard.index; root.expandedHistoryId = recentCard.expanded ? "" : String(recentCard.modelData.id) } } }
                    Text { textFormat: Text.PlainText; visible: recentCard.failedItem && !recentCard.expanded; width: parent.width; text: String(recentCard.modelData.failure || "SABnzbd reported an unspecified failure"); elide: Text.ElideRight; color: Qt.darker(root.contentForeground, 1.4); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                    Text { textFormat: Text.PlainText; visible: recentCard.expanded; width: parent.width; text: String(recentCard.modelData.category || "Uncategorized").toUpperCase() + "  ·  " + String(recentCard.modelData.size || "Unknown size") + (recentCard.modelData.completed ? "  ·  " + String(recentCard.modelData.completed) : ""); elide: Text.ElideRight; color: Qt.darker(root.contentForeground, 1.45); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { textFormat: Text.PlainText; visible: recentCard.expanded && recentCard.retryCount > 0; width: parent.width; text: "RETRIES  " + String(recentCard.retryCount); color: Qt.darker(root.contentForeground, 1.5); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
                    Text { textFormat: Text.PlainText; visible: recentCard.expanded && recentCard.failedItem; width: parent.width; text: String(recentCard.modelData.failure || "SABnzbd reported an unspecified failure"); wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; color: Color.urgent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                    Text { textFormat: Text.PlainText; visible: recentCard.expanded && recentCard.canOpen; width: parent.width; text: String(recentCard.modelData.storage); elide: Text.ElideMiddle; color: Qt.darker(root.contentForeground, 1.35); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
                  }
                  Rectangle {
                    id: retryButton
                    readonly property bool failedItem: recentCard.failedItem
                    readonly property bool canOpen: recentCard.canOpen
                    width: retryButton.failedItem ? Style.space(78) : Style.space(86); height: Style.space(28); radius: height / 2; anchors.verticalCenter: parent.verticalCenter
                    color: (retryButton.failedItem || retryButton.canOpen) && retryMouse.containsMouse ? Qt.rgba((retryButton.failedItem ? Color.urgent : Color.accent).r, (retryButton.failedItem ? Color.urgent : Color.accent).g, (retryButton.failedItem ? Color.urgent : Color.accent).b, 0.2) : "transparent"
                    border.width: (retryButton.failedItem || retryButton.canOpen) ? Style.spacing.hairline : 0
                    border.color: retryButton.failedItem ? Color.urgent : Color.accent
                    Text { textFormat: Text.PlainText;
                      anchors.centerIn: parent
                      text: retryButton.failedItem
                        ? (root.pipeline && root.pipeline.actionJobId === recentCard.modelData.id && root.pipeline.actionFeedback !== "" ? String(root.pipeline.actionFeedback).toUpperCase() : "󰑓  RETRY")
                        : (retryButton.canOpen ? "OPEN  󰏋" : "COMPLETED")
                      color: retryButton.failedItem ? Color.urgent : (retryButton.canOpen ? Color.accent : Qt.darker(root.contentForeground, 1.4))
                      font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true
                    }
                    MouseArea { id: retryMouse; anchors.fill: parent; enabled: retryButton.failedItem ? (root.actionable && root.pipeline && root.pipeline.actionFeedback !== "retrying") : retryButton.canOpen; hoverEnabled: true; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: { if (retryButton.failedItem) { if (root.pipeline) root.pipeline.retryJob(recentCard.modelData.id) } else if (root.pipeline) root.pipeline.openFolder(recentCard.modelData.storage) } }
                  }
                }
              }
            }
            Rectangle {
              visible: root.historyTotal > root.recentJobs.length
              anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
              height: Style.space(34); radius: Style.cornerRadius
              color: loadHistoryMouse.containsMouse ? Style.hoverFillFor(root.contentForeground, Color.accent) : "transparent"
              Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "LOAD MORE HISTORY  ·  " + root.recentJobs.length + " OF " + root.historyTotal; color: Color.accent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
              MouseArea { id: loadHistoryMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (root.pipeline) root.pipeline.loadMoreHistory() }
            }
          }

          Row {
            width: parent.width; spacing: Style.space(14)
            Text { textFormat: Text.PlainText; text: !root.connected && !root.staleMode ? "r retry  ·  Esc close" : (root.compact ? "j/k select  ·  Enter/Space details  ·  p job" : "j/k or ↑↓ select  ·  Enter/Space details  ·  p job  ·  P queue  ·  r refresh  ·  O open  ·  f folder  ·  Esc close"); color: Qt.darker(root.contentForeground, 1.6); font.family: root.contentFontFamily; font.pixelSize: Style.font.caption }
            Text { textFormat: Text.PlainText; visible: root.pipeline && root.pipeline.actionFeedback === "failed"; text: "ACTION FAILED"; color: Color.urgent; font.family: root.contentFontFamily; font.pixelSize: Style.font.caption; font.bold: true }
          }
        }
      }
    }
  }
}
