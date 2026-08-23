pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.thecdrz.sabarchy"

  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "")
  readonly property string helperPath: pluginDir + "bin/sabnzbd-pipeline-api"
  readonly property int refreshMs: Math.max(2, Number(setting("refreshSeconds", 3))) * 1000
  readonly property string configPath: String(setting("configPath", ""))
  readonly property string demoState: String(setting("_demoState", ""))
  readonly property bool demoExpandFirst: Boolean(setting("_demoExpandFirst", false))
  readonly property bool demoExpandHistory: Boolean(setting("_demoExpandHistory", false))
  readonly property string demoNotify: String(setting("_demoNotify", ""))
  readonly property bool notifyCompletion: Boolean(setting("notifyOnCompletion", true))
  readonly property bool notifyFailure: Boolean(setting("notifyOnFailure", true))
  readonly property bool notifySound: Boolean(setting("notifySound", false))
  readonly property real diskThresholdGb: Math.max(0, Number(setting("lowDiskThresholdGb", 20)))
  readonly property string soundDir: "/usr/share/sounds/freedesktop/stereo"

  property var snapshot: ({
    ok: false,
    state: "loading",
    message: "Connecting to SABnzbd…",
    queue: { paused: false, speed: "0 B/s", timeleft: "0:00:00", jobs: [] },
    stages: { download: [], verify: [], unpack: [], recent: [] },
    counts: { download: 0, verify: 0, unpack: 0, recent: 0 }
  })
  property string lastError: ""
  property bool refreshing: false
  property string actionJobId: ""
  property string actionStatus: ""
  property int queueLimit: 100
  property int historyLimit: 50
  property bool hasGoodSnapshot: false
  property bool stale: false
  property bool snapshotTimedOut: false
  property double lastSuccessMs: 0
  property var notifiedJobs: ({})
  property bool notificationBaseline: false
  property bool demoNotifiedOnce: false
  property var pendingNotifications: []

  readonly property bool connected: snapshot && snapshot.ok === true
  readonly property bool actionable: connected && !stale
  readonly property bool paused: connected && snapshot.queue && snapshot.queue.paused === true
  readonly property string speedText: connected && snapshot.queue ? String(snapshot.queue.speed || "0 B/s") : "offline"
  readonly property bool showSpeed: connected && snapshot.queue && Number(snapshot.queue.kbpersec || 0) > 0
  readonly property int activeCount: connected && snapshot.counts
    ? Number(snapshot.counts.active_total !== undefined
        ? snapshot.counts.active_total
        : Number(snapshot.counts.download || 0) + Number(snapshot.counts.verify || 0) + Number(snapshot.counts.unpack || 0))
    : 0

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: speedContent.implicitWidth

  function helperCommand(action) {
    var command = [root.helperPath, action]
    if (root.configPath !== "") command.push("--config", root.configPath)
    if (action === "snapshot") {
      command.push("--queue-limit", String(root.queueLimit), "--history-limit", String(root.historyLimit), "--disk-threshold", String(root.diskThresholdGb))
      if (root.demoState !== "") command.push("--demo", root.demoState)
    }
    return command
  }

  function refresh() {
    if (snapshotProc.running) return
    refreshing = true
    snapshotTimedOut = false
    snapshotProc.command = helperCommand("snapshot")
    snapshotTimeout.restart()
    snapshotProc.running = true
  }

  function runAction(action) {
    if (actionProc.running || !root.actionable) return
    if (root.demoState !== "") {
      demoActionTimer.restart()
      return
    }
    actionProc.command = helperCommand(action)
    actionTimeout.restart()
    actionProc.running = true
  }

  function retryJob(jobId) {
    if (actionProc.running || !root.actionable || !jobId) return
    actionJobId = String(jobId)
    actionStatus = "retrying"
    if (root.demoState !== "") {
      demoActionTimer.restart()
      return
    }
    actionProc.command = [root.helperPath, "retry", "--id", actionJobId]
    if (root.configPath !== "") actionProc.command.push("--config", root.configPath)
    actionTimeout.restart()
    actionProc.running = true
  }

  function loadMoreQueue() { queueLimit = Math.min(1000, queueLimit + 100); refresh() }
  function loadMoreHistory() { historyLimit = Math.min(1000, historyLimit + 50); refresh() }

  function clearCompletedHistory() {
    if (actionProc.running || !root.actionable) return
    actionJobId = "__history__"
    actionStatus = "clearing"
    if (root.demoState !== "") {
      demoActionTimer.restart()
      return
    }
    actionProc.command = [root.helperPath, "clear_completed"]
    if (root.configPath !== "") actionProc.command.push("--config", root.configPath)
    actionTimeout.restart()
    actionProc.running = true
  }

  function runJobAction(action, jobId) {
    if (actionProc.running || !root.actionable || !jobId) return
    actionJobId = String(jobId)
    actionStatus = action === "job_pause" ? "pausing" : "resuming"
    if (root.demoState !== "") {
      demoActionTimer.restart()
      return
    }
    actionProc.command = [root.helperPath, action, "--id", actionJobId]
    if (root.configPath !== "") actionProc.command.push("--config", root.configPath)
    actionTimeout.restart()
    actionProc.running = true
  }

  function clipText(value, limit) {
    var result = String(value || "")
    if (result.length > limit) result = result.substring(0, limit - 1) + "…"
    return result
  }

  function processNotifications(nextSnapshot) {
    var stages = nextSnapshot && nextSnapshot.stages
    if (!stages) return
    if (root.demoState !== "" && root.demoNotify !== "" && !root.demoNotifiedOnce) {
      root.demoNotifiedOnce = true
      if ((root.demoNotify === "completed" || root.demoNotify === "both") && root.notifyCompletion)
        root.queueNotification("Download complete", "omarchy-4.0.0.iso  ·  5.8 GB", false)
      if ((root.demoNotify === "failed" || root.demoNotify === "both") && root.notifyFailure)
        root.queueNotification("Download failed", "omarchy-4.0.0.iso  ·  Repair failed, not enough repair blocks (142 short)", true)
    }
    var recent = stages.recent || []
    var seen = {}
    var index
    for (index = 0; index < recent.length; index++) {
      var seenId = String(recent[index].id || "")
      if (seenId) seen[seenId] = true
    }
    if (!root.notificationBaseline) {
      root.notificationBaseline = true
      root.notifiedJobs = seen
      return
    }
    var fresh = []
    for (index = 0; index < recent.length; index++) {
      var item = recent[index]
      var itemId = String(item.id || "")
      if (itemId && !root.notifiedJobs[itemId]) fresh.push(item)
    }
    root.notifiedJobs = seen
    if (fresh.length === 0 || root.opened) return
    var failures = 0
    for (index = 0; index < fresh.length; index++) if (fresh[index].failed === true) failures++
    if (fresh.length > 5) {
      root.queueNotification("Download updates", fresh.length + " downloads finished" + (failures > 0 ? "  ·  " + failures + " failed" : ""), failures > 0)
      return
    }
    for (index = 0; index < fresh.length; index++) {
      var job = fresh[index]
      var failed = job.failed === true
      if (failed ? !root.notifyFailure : !root.notifyCompletion) continue
      var body = clipText(job.name, 90)
      if (job.size) body += "  ·  " + clipText(job.size, 24)
      root.queueNotification(failed ? "Download failed" : "Download complete", body, failed)
    }
  }

  function queueNotification(summary, body, urgent) {
    pendingNotifications.push({ summary: summary, body: body, urgent: urgent })
    dispatchNotifications()
  }

  function dispatchNotifications() {
    if (notifyProc.running || pendingNotifications.length === 0) return
    var notification = pendingNotifications.shift()
    notifyProc.command = [
      "notify-send", "-a", "SABarchy",
      "-u", notification.urgent ? "critical" : "normal",
      "-t", notification.urgent ? "0" : "6000",
      "-i", notification.urgent ? "dialog-error" : "folder-download",
      notification.summary, notification.body
    ]
    notifyProc.running = true
    if (root.notifySound && !soundProc.running) {
      soundProc.command = ["pw-play", notification.urgent ? root.soundDir + "/dialog-error.oga" : root.soundDir + "/complete.oga"]
      soundProc.running = true
    }
  }

  function openFolder(path) {
    var target = String(path || "")
    if (!target || target.charAt(0) !== "/") return
    if (root.demoState !== "") {
      demoActionTimer.restart()
      return
    }
    folderProc.command = ["xdg-open", target]
    folderProc.running = true
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.anchorItem = button
    target.hostWidget = root
    target.pipeline = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: refreshTimer.restart()

  Process {
    id: snapshotProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        snapshotTimeout.stop()
        root.refreshing = false
        if (root.snapshotTimedOut) return
        var raw = String(text || "").trim()
        if (!raw) {
          root.lastError = "SABnzbd helper returned no data"
          root.stale = root.hasGoodSnapshot
          return
        }
        try {
          var nextSnapshot = JSON.parse(raw)
          if (nextSnapshot.ok) {
            root.snapshot = nextSnapshot
            root.hasGoodSnapshot = true
            root.stale = false
            root.lastSuccessMs = Date.now()
            root.lastError = ""
            root.processNotifications(nextSnapshot)
          } else {
            root.lastError = String(nextSnapshot.message || "SABnzbd unavailable")
            root.stale = root.hasGoodSnapshot
            if (!root.hasGoodSnapshot) root.snapshot = nextSnapshot
          }
        } catch (error) {
          root.lastError = "Could not parse SABnzbd response"
          root.stale = root.hasGoodSnapshot
        }
      }
    }
    onExited: function(exitCode) {
      snapshotTimeout.stop()
      root.refreshing = false
      if (exitCode !== 0 && root.lastError === "") root.lastError = "Could not contact SABnzbd"
      if (exitCode !== 0) root.stale = root.hasGoodSnapshot
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { waitForEnd: true }
    onExited: function(exitCode) {
      actionTimeout.stop()
      root.actionStatus = exitCode === 0 ? "accepted" : "failed"
      Qt.callLater(root.refresh)
      actionClearTimer.restart()
    }
  }

  Timer { id: actionClearTimer; interval: 3000; onTriggered: { root.actionJobId = ""; root.actionStatus = "" } }
  Timer { id: demoActionTimer; interval: 650; onTriggered: { root.actionStatus = "accepted"; actionClearTimer.restart() } }

  Process {
    id: notifyProc
    onExited: dispatchNotifications()
  }

  Process {
    id: soundProc
  }

  Process {
    id: folderProc
  }
  Timer {
    id: snapshotTimeout
    interval: 12000
    onTriggered: {
      if (!snapshotProc.running) return
      root.snapshotTimedOut = true
      root.lastError = "SABnzbd helper timed out"
      root.stale = root.hasGoodSnapshot
      root.refreshing = false
      snapshotProc.running = false
    }
  }
  Timer {
    id: actionTimeout
    interval: 6000
    onTriggered: {
      if (!actionProc.running) return
      root.actionStatus = "failed"
      actionProc.running = false
      actionClearTimer.restart()
    }
  }

  Timer {
    id: refreshTimer
    interval: root.refreshMs
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  function statusTooltip(): string {
    if (!root.connected)
      return "SABnzbd · Unavailable"
    if (root.paused)
      return "SABnzbd · Paused"
    if (root.activeCount > 0)
      return "SABnzbd · " + root.activeCount + (root.activeCount === 1 ? " active job" : " active jobs")
    return "SABnzbd · Idle"
  }

  IpcHandler {
    target: root.moduleName
    function refresh(): void { root.refresh() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function pause(): void { root.runAction("pause") }
    function resume(): void { root.runAction("resume") }
    function loadMoreQueue(): void { root.loadMoreQueue() }
    function loadMoreHistory(): void { root.loadMoreHistory() }
    function retry(id: string): void { root.retryJob(id) }
    function clearCompletedHistory(): void { root.clearCompletedHistory() }
    function pauseJob(id: string): void { root.runJobAction("job_pause", id) }
    function resumeJob(id: string): void { root.runJobAction("job_resume", id) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    fixedWidth: !root.vertical ? (root.showSpeed ? speedContent.implicitWidth + Style.space(16) : Style.bar.iconSlot) : -1
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1
    tooltipText: root.statusTooltip()
    active: !root.connected || root.paused
    activeColor: Color.urgent
    Row {
      id: speedContent
      anchors.centerIn: parent
      spacing: Style.space(6)
      SabarchyIcon {
        width: Style.space(18)
        height: width
        anchors.verticalCenter: parent.verticalCenter
        iconColor: button.active && button.useActiveColor ? button.activeColor : button.foreground
      }
      Text { textFormat: Text.PlainText;
        visible: root.showSpeed && !root.vertical
        anchors.verticalCenter: parent.verticalCenter
        text: root.speedText
        color: button.active && button.useActiveColor ? button.activeColor : button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        renderType: Text.NativeRendering
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton && root.actionable)
        root.runAction(root.paused ? "resume" : "pause")
      else
        root.toggle()
    }
  }
}
