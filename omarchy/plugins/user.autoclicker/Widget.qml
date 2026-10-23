import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "user.autoclicker"
  property bool clicking: false
  property int intervalMs: 5
  property string mouseButton: "left"

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "user.autoclicker"
    function refresh(): void { root.refresh() }
    function status(): string { return root.clicking ? "active" : "inactive" }
  }

  Process {
    id: statusProcess
    command: ["@BINDIR@/autoclicker-info"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var config = JSON.parse(text)
          root.clicking = config.active === true
          root.intervalMs = config.interval_ms
          root.mouseButton = config.button
        } catch (error) { root.clicking = false }
      }
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    bar: root.bar
    text: "\udb80\udf7d"
    active: root.clicking
    dimmed: !root.clicking
    tooltipText: "Autoclicker " + (root.clicking ? "ON" : "OFF")
      + " · " + root.mouseButton + " click · " + root.intervalMs + " ms\n"
      + (root.clicking ? "Click to stop" : "Click for Rofi controls")
      + " · Home toggles · Right-click stops"
    onPressed: function(mouseButton) {
      if (!root.bar) return
      root.bar.run(root.clicking || mouseButton === Qt.RightButton
        ? "@BINDIR@/autoclicker stop"
        : "@BINDIR@/autoclicker menu")
    }
  }
}
