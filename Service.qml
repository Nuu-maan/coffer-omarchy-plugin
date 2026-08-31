import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: service

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: ({})
  property var barWidgetRegistry: null
  property var pluginRegistry: null

  readonly property string pluginId: "io.github.nuu-maan.coffer"
  readonly property string home: Quickshell.env("HOME")

  readonly property string sourceDir: manifest && manifest.__sourceDir
    ? String(manifest.__sourceDir)
    : home + "/.config/omarchy/plugins/" + pluginId

  readonly property string launcher: sourceDir + "/bin/omarchy-coffer"

  readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")) + "/coffer"
  readonly property string storePath: configDir + "/store.json"
  readonly property string imagesDir: configDir + "/images"

  property var items: []
  property var sections: []
  property string storeError: ""
  property bool storeMissing: false
  property bool loaded: false
  property string lastError: ""

  readonly property var openItems: Model.openItems(items)
  readonly property int openCount: openItems.length

  signal actionFailed(string action, string message)

  function grouped(limit) { return Model.groupItems(items, sections, limit) }
  function imagePathFor(item) { return Model.imagePathFor(imagesDir, item) }

  function applyStore(raw) {
    var parsed = Model.parseStore(raw)
    service.items = parsed.items
    service.sections = parsed.sections
    service.storeError = parsed.error
    service.storeMissing = false
    service.loaded = true
  }

  FileView {
    id: storeFile
    path: service.storePath
    watchChanges: true
    printErrors: false
    onLoaded: service.applyStore(text())
    onFileChanged: reload()
    onLoadFailed: {
      service.items = []
      service.sections = []
      service.storeError = ""
      service.storeMissing = true
      service.loaded = true
    }
  }

  Timer {
    running: service.storeMissing
    interval: 5000
    repeat: true
    onTriggered: storeFile.reload()
  }

  property var pending: []

  function run(action, id) {
    var argv = [service.launcher, String(action)]
    if (id !== undefined && id !== null && String(id) !== "") argv.push(String(id))
    if (actionProc.running) {
      var queue = service.pending.slice()
      queue.push(argv)
      service.pending = queue
      return
    }
    actionProc.start(argv)
  }

  function stash() { service.run("stash") }
  function clip() { service.run("clip") }
  function markDone(id) { service.run("done", id) }

  function copyItem(item) {
    if (!item) return false
    if (item.kind === "image") {
      var path = service.imagePathFor(item)
      if (!path) return false
      Quickshell.execDetached(["bash", "-c", "wl-copy --type image/png < \"$1\"", "wl-copy", path])
      return true
    }
    var text = String(item.text || "")
    if (!text) return false
    Quickshell.execDetached(["wl-copy", "--", text])
    return true
  }

  Process {
    id: actionProc
    property string action: ""
    property bool launched: false

    stderr: StdioCollector { id: actionErr; waitForEnd: true }

    function start(argv) {
      actionProc.action = argv.length > 1 ? argv[1] : ""
      actionProc.launched = false
      actionProc.command = argv
      actionProc.running = true
    }

    function drain() {
      if (!service.pending.length) return
      var queue = service.pending.slice()
      var next = queue.shift()
      service.pending = queue
      actionProc.start(next)
    }

    onStarted: launched = true

    onRunningChanged: {
      if (running || launched) return
      service.lastError = "Cannot run bin/omarchy-coffer — check it is executable"
      service.actionFailed(actionProc.action, service.lastError)
      actionProc.drain()
    }

    onExited: function (exitCode) {
      if (exitCode === 0) {
        service.lastError = ""
      } else {
        var text = String(actionErr.text || "").trim()
        service.lastError = text || ("Coffer " + actionProc.action + " failed (exit " + exitCode + ")")
        service.actionFailed(actionProc.action, service.lastError)
      }
      actionProc.drain()
    }
  }
}
