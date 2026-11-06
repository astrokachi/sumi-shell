import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Commons

// The control center, as in the Sumi design, with each part opening in
// place for more: Wi-Fi to pick a network and join it, Bluetooth to connect
// or pair devices, sound to choose the output, and the battery for power
// modes and its health. One part is open at a time. Opened from the bar's
// status glyphs; a click outside or Escape closes it.
PanelWindow {
  id: cc

  required property var host
  required property var bar
  required property string screenName

  readonly property var ds: host.ds
  readonly property var sys: host.system
  readonly property bool wanted: host.controlCenterScreen === screenName

  readonly property color ink: ds.ink
  readonly property color ink2: ds.ink2
  readonly property color ink3: ds.ink3
  readonly property color raised: ds.raised
  readonly property color raised2: ds.raised2

  // "wifi", "bluetooth", "display", "sound", "system", "clocks", "battery" or "".
  property string open: ""
  // The one Wi-Fi network showing its password field or actions, by SSID.
  property string openNetwork: ""

  // "Resets in 2 h 14 m" from a limit's ISO time; "" when unknown.
  function resetsIn(iso) {
    var at = Date.parse(iso || "")
    if (!(at > 0)) return ""
    var minutes = Math.max(0, Math.round((at - Date.now()) / 60000))
    var h = Math.floor(minutes / 60)
    var m = minutes % 60
    return "Resets in " + (h > 0 ? h + " h " : "") + m + " m"
  }

  // Bring an item into the scrolled view, top first if it is taller.
  function reveal(item) {
    var top = item.mapToItem(body, 0, 0).y
    var bottom = top + item.height
    var y = scroller.contentY
    if (bottom > y + scroller.height) y = bottom - scroller.height
    if (top < y) y = top
    y = Math.max(0, Math.min(y, scroller.contentHeight - scroller.height))
    if (y === scroller.contentY) return
    scrollAnim.to = y
    scrollAnim.restart()
  }

  NumberAnimation { id: scrollAnim; target: scroller; property: "contentY"; duration: Style.duration(180); easing.type: Easing.OutCubic }

  // The part open now if it is one of these, else "": what a Fold opens for.
  function partIn(parts) { return parts.indexOf(open) >= 0 ? open : "" }

  function toggle(part) {
    open = open === part ? "" : part
    if (open === "wifi") sys.scanWifi()
    if (open === "hotspot") sys.refreshHotspot()
    if (open === "agents") { sys.readAgents(); sys.updateAgents(false) }
    if (open === "display") sys.refreshDisplays()
    if (open === "clocks") { sys.refreshClocks(); sys.refreshWeather() }
    if (open !== "bluetooth" && sys.discovering) sys.setDiscovering(false)
  }

  readonly property var nightlight: host.nightlightService
  readonly property var notifications: host.notificationsService
  readonly property var idle: host.idleService

  // Asked to open at a part (`controlCenterAt`), whether or not it is up.
  function takePart() {
    var part = host.controlCenterPart
    if (!wanted || part === "") return
    host.controlCenterPart = ""
    if (open !== part) toggle(part)
  }

  Connections {
    target: cc.host
    function onControlCenterPartChanged() { cc.takePart() }
  }

  onWantedChanged: {
    if (wanted) {
      host.resolveServices()
      refreshAfterOpen.restart()
      takePart()
    } else {
      refreshAfterOpen.stop()
    }
  }

  // Settles in from the status glyphs it hangs under on a gentle spring, and
  // leaves quicker with no bounce. Input and focus follow `wanted` at once.
  readonly property real appear: appearSpring.value
  SumiSpring {
    id: appearSpring
    animated: Style.duration(1) > 0
    response: cc.wanted ? cc.ds.openResponse : cc.ds.closeResponse
    dampingRatio: cc.wanted ? cc.ds.openDamping : cc.ds.closeDamping
    target: cc.wanted ? 1 : 0
  }

  // Fully faded out: only now put the open part away, so the panel leaves
  // showing what it showed rather than snapping shut mid-fade.
  readonly property bool settledClosed: !wanted && appear <= 0 && !appearSpring.moving
  onSettledClosedChanged: {
    if (!settledClosed) return
    open = ""
    if (sys.discovering) sys.setDiscovering(false)
  }

  // refreshAll starts nine readers at once; starting them in the same turn as
  // the open held its first frame back. They only update what is shown.
  Timer {
    id: refreshAfterOpen
    interval: 30
    onTriggered: cc.sys.refreshAll()
  }

  // Mapped once and parked rather than mapped fresh on every open, which cost
  // ~150 ms before the first frame and then the layer fade. While closed it
  // is transparent, takes no keyboard focus and has no input region, so
  // clicks fall through to the desktop.
  screen: bar.screen
  visible: !!bar.screen
  // Parked, the surface shrinks to one pixel in the corner. Hyprland blurs a
  // blurred layer wherever what is under it changes, even a transparent one,
  // and four parked fullscreen layers halved the frame rate (30 FPS over
  // video). Opening grows it back; that is a resize, not a new surface.
  anchors { top: true; left: true; bottom: !settledClosed; right: !settledClosed }
  implicitWidth: 1
  implicitHeight: 1
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "sumi-cc"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  Item { id: inputCover; anchors.fill: parent }
  mask: Region { item: cc.wanted ? inputCover : null }

  Binding {
    target: cc.contentItem
    property: "opacity"
    value: Math.max(0, Math.min(1, cc.appear / cc.ds.opaqueAt))
  }
  Binding {
    target: cc.contentItem
    property: "scale"
    value: cc.ds.settleFrom + (1 - cc.ds.settleFrom) * cc.appear
  }
  Binding {
    target: cc.contentItem
    property: "transformOrigin"
    value: Item.TopRight
  }

  MouseArea {
    anchors.fill: parent
    onClicked: cc.host.closeControlCenter()
  }

  Rectangle {
    id: panel
    anchors.right: parent.right
    anchors.rightMargin: Style.space(10)
    y: cc.host.barSize + Style.space(8)
    width: Style.space(340)
    height: Math.min(body.implicitHeight + Style.space(24), cc.height - y - Style.space(12))
    radius: cc.ds.rPanel
    color: cc.host.panelBackground
    border.width: 1
    border.color: cc.ds.line
    clip: true

    focus: cc.wanted
    Keys.onEscapePressed: {
      if (cc.open !== "") cc.open = ""
      else cc.host.closeControlCenter()
    }

    MouseArea { anchors.fill: parent }

    Flickable {
      id: scroller
      anchors.fill: parent
      anchors.margins: Style.space(12)
      contentHeight: body.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      clip: true

      Column {
        id: body
        width: parent.width
        spacing: Style.space(10)

        // ---- network, and three quick switches beside it ----------------------
        // Opening a connection flows the network tile out over the switches
        // to the full width, then opens it downward.
        Item {
          width: body.width
          height: netFold.height

          Fold {
            id: netFold
            z: 1
            part: cc.partIn(["wifi", "bluetooth", "hotspot"])
            restWidth: (body.width - 2 * Style.space(8)) / 3 * 2 + Style.space(8)
            headHeight: networkRows.implicitHeight + Style.space(12)

            head: Column {
              id: networkRows
              x: Style.space(6)
              y: Style.space(6)
              width: parent.width - Style.space(12)
              spacing: Style.space(2)

              ConnectionRow {
                glyph: "wifi"
                label: "Wi-Fi"
                on: cc.sys.wifiOn
                expanded: cc.open === "wifi"
                value: !cc.sys.wifiOn ? "Off" : cc.sys.ssid || "Not connected"
                onToggled: cc.sys.setWifi(!cc.sys.wifiOn)
                onOpened: cc.toggle("wifi")
              }

              ConnectionRow {
                glyph: "bluetooth"
                label: "Bluetooth"
                on: cc.sys.bluetoothOn
                expanded: cc.open === "bluetooth"
                value: !cc.sys.bluetoothOn ? "Off" : cc.sys.bluetoothDevice || "On"
                onToggled: cc.sys.setBluetooth(!cc.sys.bluetoothOn)
                onOpened: cc.toggle("bluetooth")
              }

              ConnectionRow {
                glyph: "hotspot"
                label: "Hotspot"
                on: cc.sys.hotspotOn
                expanded: cc.open === "hotspot"
                value: cc.sys.hotspotBusy ? (cc.sys.hotspotOn ? "Starting…" : "Stopping…")
                  : cc.sys.hotspotOn ? (cc.sys.hotspotClients > 0 ? cc.sys.hotspotClients + (cc.sys.hotspotClients === 1 ? " device" : " devices") : "Sharing") : "Off"
                onToggled: cc.sys.toggleHotspot()
                onOpened: cc.toggle("hotspot")
              }
            }

            // ---- Wi-Fi: networks -------------------------------------------------
            Section {
              shown: netFold.shownPart === "wifi"
              title: cc.sys.scanning ? "Looking for networks…" : "Networks"
              actionGlyph: "refresh"
              onAction: cc.sys.scanWifi()

              Text {
                visible: !cc.sys.wifiOn
                width: parent.width
                topPadding: Style.space(4)
                bottomPadding: Style.space(6)
                leftPadding: Style.space(8)
                textFormat: Text.PlainText
                text: "Wi-Fi is off."
                color: cc.ink2
                font.family: cc.ds.fontUi
                font.pixelSize: 12
              }

              Repeater {
                model: cc.sys.wifiOn ? cc.sys.networks.slice(0, 8) : []

                NetworkRow {
                  required property var modelData
                  net: modelData
                }
              }
            }

            // ---- hotspot: what it shares, and a code to join it -----------------
            Section {
              shown: netFold.shownPart === "hotspot"
              title: cc.sys.hotspotOn ? "Sharing " + (cc.sys.hotspotUpstream || "this connection") : "Hotspot is off"

              Row {
                width: parent.width
                spacing: Style.space(12)
                leftPadding: Style.space(8)
                bottomPadding: Style.space(6)

                Column {
                  width: parent.width - qr.width - Style.space(28)
                  spacing: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter

                  Fact { label: "Network"; value: cc.sys.hotspotSsid || "—" }
                  Fact { label: "Security"; value: cc.sys.hotspotSecurity === "open" ? "Open" : cc.sys.hotspotSecurity ? "WPA2" : "—" }
                  Fact { label: "Connected"; value: cc.sys.hotspotOn ? String(cc.sys.hotspotClients) : "—" }
                }

                // Scan to join, drawn in ink on paper so phones can read it.
                Rectangle {
                  id: qr
                  visible: cc.sys.hotspotOn && cc.sys.hotspotQr.length > 0
                  width: visible ? Style.space(112) : 0
                  height: width
                  radius: cc.ds.rRow
                  color: "#FFFFFB"

                  Canvas {
                    id: qrCanvas
                    anchors.fill: parent
                    anchors.margins: Style.space(4)
                    property var rows: cc.sys.hotspotQr
                    onRowsChanged: requestPaint()
                    onPaint: {
                      var ctx = getContext("2d")
                      ctx.clearRect(0, 0, width, height)
                      var n = rows.length
                      if (n === 0) return
                      var cell = Math.floor(Math.min(width, height) / n)
                      var off = Math.floor((width - cell * n) / 2)
                      ctx.fillStyle = "#1C1C1C"
                      for (var y = 0; y < n; y++)
                        for (var x = 0; x < rows[y].length; x++)
                          if (rows[y].charAt(x) === "1") ctx.fillRect(off + x * cell, off + y * cell, cell, cell)
                    }
                  }
                }
              }
            }

            // ---- Bluetooth: devices -----------------------------------------------
            Section {
              shown: netFold.shownPart === "bluetooth"
              title: cc.sys.discovering ? "Looking for devices…" : "Devices"
              actionGlyph: cc.sys.discovering ? "close" : "search"
              actionLabel: cc.sys.discovering ? "Stop" : "Scan"
              onAction: cc.sys.setDiscovering(!cc.sys.discovering)

              Text {
                visible: !cc.sys.bluetoothOn || cc.sys.bluetoothDevices.length === 0
                width: parent.width
                topPadding: Style.space(4)
                bottomPadding: Style.space(6)
                leftPadding: Style.space(8)
                textFormat: Text.PlainText
                text: !cc.sys.bluetoothOn ? "Bluetooth is off." : "No devices yet. Scan to find one nearby."
                color: cc.ink2
                font.family: cc.ds.fontUi
                font.pixelSize: 12
              }

              Repeater {
                model: cc.sys.bluetoothOn ? cc.sys.bluetoothDevices.filter(function(d) { return d.paired || cc.sys.discovering }).slice(0, 8) : []

                ListRow {
                  required property var modelData
                  glyph: "bluetooth"
                  title: String(modelData.name || modelData.deviceName)
                  detail: modelData.pairing ? "Pairing…"
                    : modelData.connected ? ("Connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : ""))
                    : modelData.paired ? "Not connected" : "Tap to pair"
                  checked: modelData.connected
                  onClicked: cc.sys.toggleDevice(modelData)
                }
              }
            }
          }

          // The switches give way while the network tile flows over them.
          Column {
            id: quickTiles
            anchors.right: parent.right
            width: (body.width - 2 * Style.space(8)) / 3
            height: netFold.headHeight
            opacity: 1 - netFold.grow
            visible: opacity > 0
            transform: Scale {
              origin.x: quickTiles.width
              origin.y: quickTiles.height / 2
              xScale: 1 - 0.14 * netFold.grow
              yScale: 1 - 0.06 * netFold.grow
            }
            spacing: Style.space(8)

            QuickTile {
              height: (parent.height - 2 * Style.space(8)) / 3
              glyph: "moon"
              label: "Night Light"
              on: !!cc.nightlight && cc.nightlight.enabled
              onToggled: {
                if (cc.nightlight) cc.nightlight.setNightlight(!cc.nightlight.enabled)
                else Util.execDetached("omarchy toggle nightlight")
              }
            }

            QuickTile {
              height: (parent.height - 2 * Style.space(8)) / 3
              glyph: "silent"
              label: "Do Not Disturb"
              on: !!cc.notifications && cc.notifications.doNotDisturb
              onToggled: {
                if (cc.notifications) cc.notifications.setDoNotDisturb(!cc.notifications.doNotDisturb)
                else Util.execDetached("omarchy toggle notification silencing")
              }
            }

            QuickTile {
              height: (parent.height - 2 * Style.space(8)) / 3
              glyph: "coffee"
              label: "Stay Awake"
              on: !!cc.idle && cc.idle.stayAwake
              onToggled: {
                if (cc.idle) cc.idle.setIdleEnabled(cc.idle.stayAwake)
                else Util.execDetached("omarchy toggle idle")
              }
            }
          }
        }

        // ---- display and sound --------------------------------------------------
        Fold {
          id: displayFold
          part: cc.partIn(["display"])
          headHeight: Style.space(58)

          head: SliderTile {
            label: "Display"
            detail: {
              // With more than one monitor, name the one the slider dims.
              var m = cc.sys.focusedMonitor
              if (!m) return ""
              if (cc.sys.monitors.filter(function(x) { return x.enabled }).length > 1)
                return m.label + (cc.sys.brightnessAvailable ? "" : " · no brightness control")
              return m.width + " × " + m.height + " · " + m.refresh + " Hz · " + cc.sys.scale + "×"
            }
            glyph: "sun"
            value: cc.sys.brightness
            expandable: true
            expanded: displayFold.open
            onMoved: function(v) { cc.sys.setBrightness(v) }
            onOpened: cc.toggle("display")
          }

          // Displays, scale, text size and the night light's warmth, as
          // Omarchy's and Shibumi's display panels offer them.
          Section {
            shown: true
            title: cc.sys.monitors.length > 1 ? "Displays" : "Display"

            Repeater {
              model: cc.sys.monitors

              Item {
                id: monitorRow
                required property var modelData
                width: parent.width
                height: Style.space(40)

                SumiIcon {
                  id: monitorGlyph
                  x: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  name: "monitor"
                  size: 15
                  color: monitorRow.modelData.enabled ? cc.ink : cc.ink3
                }

                Column {
                  anchors.left: monitorGlyph.right
                  anchors.leftMargin: Style.space(10)
                  anchors.right: monitorSwitch.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: monitorRow.modelData.name + (monitorRow.modelData.description ? " · " + monitorRow.modelData.description : "")
                    elide: Text.ElideRight
                    color: cc.ink
                    font.family: cc.ds.fontUi
                    font.pixelSize: 13
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: monitorRow.modelData.enabled
                      ? monitorRow.modelData.width + " × " + monitorRow.modelData.height + " · " + monitorRow.modelData.refresh + " Hz" + (monitorRow.modelData.name === cc.sys.brightnessMonitor ? " · focused" : "")
                      : "Off"
                    color: cc.ink2
                    font.family: cc.ds.fontUi
                    font.pixelSize: 11
                  }
                }

                CtlSwitch {
                  id: monitorSwitch
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  ink: cc.ink
                  knob: cc.ds.paper
                  checked: monitorRow.modelData.enabled
                  // The last screen that is on stays on.
                  locked: monitorRow.modelData.enabled && cc.sys.monitors.filter(function(m) { return m.enabled }).length <= 1
                  onToggled: cc.sys.setMonitorEnabled(monitorRow.modelData, !monitorRow.modelData.enabled)
                }
              }
            }

            SettingLabel { text: "Scale" }

            Segmented {
              options: [1, 1.25, 1.5, 1.75, 2]
              current: cc.sys.scale
              label: function(v) { return v + "×" }
              onPicked: function(v) { cc.sys.setScale(v) }
            }

            SettingLabel { text: "Text size" }

            Item {
              width: parent.width
              height: Style.space(34)

              Rectangle {
                anchors.fill: parent
                anchors.leftMargin: Style.space(2)
                anchors.rightMargin: Style.space(2)
                radius: cc.ds.rRow + 3
                color: cc.raised2
              }

              StepButton { x: Style.space(6); anchors.verticalCenter: parent.verticalCenter; glyph: "minus"; onClicked: cc.sys.stepTextSize(-1) }

              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: cc.sys.textSize + " px"
                color: cc.ink
                font.family: cc.ds.fontUi
                font.pixelSize: 13
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
              }

              StepButton { anchors.right: parent.right; anchors.rightMargin: Style.space(6); anchors.verticalCenter: parent.verticalCenter; glyph: "plus"; onClicked: cc.sys.stepTextSize(1) }
            }

            SettingLabel {
              visible: !!cc.nightlight && cc.nightlight.enabled
              text: "Night Light warmth · " + cc.sys.warmth + " K"
            }

            Item {
              visible: !!cc.nightlight && cc.nightlight.enabled
              width: parent.width
              height: Style.space(28)

              Rectangle {
                id: warmthTrack
                x: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(16)
                height: Style.space(6)
                radius: height / 2
                color: Qt.rgba(cc.ink.r, cc.ink.g, cc.ink.b, 0.10)

                Rectangle {
                  // Warmer to the right.
                  width: parent.width * (6500 - cc.sys.warmth) / 4000
                  height: parent.height
                  radius: parent.radius
                  color: cc.ink
                }
              }

              MouseArea {
                anchors.fill: warmthTrack
                anchors.topMargin: -Style.space(8)
                anchors.bottomMargin: -Style.space(8)
                cursorShape: Qt.PointingHandCursor
                function pick(x) { cc.sys.setWarmth(6500 - 4000 * Math.max(0, Math.min(1, x / width))) }
                onPressed: function(mouse) { pick(mouse.x) }
                onPositionChanged: function(mouse) { if (pressed) pick(mouse.x) }
              }
            }
          }
        }

        Fold {
          id: soundFold
          part: cc.partIn(["sound"])
          headHeight: Style.space(58)

          head: SliderTile {
            label: "Sound"
            detail: cc.sys.sinkName(cc.sys.sink)
            glyph: cc.sys.muted ? "mute" : "volume"
            value: cc.sys.muted ? 0 : cc.sys.volume
            expandable: true
            expanded: soundFold.open
            onMoved: function(v) { cc.sys.setVolume(v) }
            onOpened: cc.toggle("sound")
          }

          Section {
            shown: true
            title: "Output"

            Repeater {
              model: cc.sys.sinks

              ListRow {
                required property var modelData
                glyph: "volume"
                title: cc.sys.sinkName(modelData)
                checked: cc.sys.sink === modelData
                onClicked: cc.sys.setSink(modelData)
              }
            }
          }
        }


        // ---- now playing ----------------------------------------------------------
        // Only shown while some player is up; with none, the card is left out entirely.
        Rectangle {
          visible: !!cc.sys.player
          width: body.width
          height: Style.space(60)
          radius: cc.ds.rTile
          color: cc.raised

          // Clicking the card (not the transport) jumps to where the media is playing.
          HoverHandler { enabled: !!cc.sys.player; cursorShape: Qt.PointingHandCursor }
          TapHandler {
            enabled: !!cc.sys.player
            onTapped: function(point) {
              if (point.position.x >= transport.x - Style.space(5)) return
              var p = cc.sys.player
              cc.host.closeControlCenter()
              Util.execDetached(Util.shellQuote(Qt.resolvedUrl("focus-player.sh").toString().replace("file://", ""))
                + " " + Util.shellQuote(p.dbusName) + " " + Util.shellQuote(p.desktopEntry || "")
                + " " + Util.shellQuote(p.trackTitle || "")
                + (p.canRaise ? " || busctl --user call " + Util.shellQuote(p.dbusName)
                  + " /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2 Raise" : ""))
            }
          }

          ClippingRectangle {
            id: art
            x: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(40)
            height: width
            radius: cc.ds.rApp
            color: cc.raised2

            SumiIcon {
              anchors.centerIn: parent
              visible: artImage.status !== Image.Ready
              name: "music"
              size: 18
              color: cc.ink2
            }

            Image {
              id: artImage
              anchors.fill: parent
              source: cc.sys.player ? cc.sys.player.trackArtUrl : ""
              fillMode: Image.PreserveAspectCrop
              sourceSize.width: 96
              sourceSize.height: 96
            }
          }

          Column {
            anchors.left: art.right
            anchors.leftMargin: Style.space(12)
            anchors.right: transport.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: cc.sys.player ? (cc.sys.player.trackTitle || "Unknown") : "Nothing playing"
              elide: Text.ElideRight
              color: cc.ink
              font.family: cc.ds.fontUi
              font.pixelSize: 13
              font.weight: Font.Medium
            }

            Text {
              width: parent.width
              visible: text !== ""
              textFormat: Text.PlainText
              text: {
                var p = cc.sys.player
                if (!p) return ""
                return [p.trackArtist, p.trackAlbum].filter(function(x) { return x && String(x).length > 0 }).join(" · ")
              }
              elide: Text.ElideRight
              color: cc.ink2
              font.family: cc.ds.fontUi
              font.pixelSize: 12
            }
          }

          Row {
            id: transport
            anchors.right: parent.right
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(12)
            opacity: cc.sys.player ? 1 : 0.35

            IconButton { glyph: "prev"; size: 15; onClicked: if (cc.sys.player) cc.sys.player.previous() }
            IconButton { glyph: cc.sys.playing ? "pause" : "play"; size: 16; onClicked: if (cc.sys.player) cc.sys.player.togglePlaying() }
            IconButton { glyph: "next"; size: 15; onClicked: if (cc.sys.player) cc.sys.player.next() }
          }
        }

        // ---- system -------------------------------------------------------------
        Fold {
          id: systemFold
          part: cc.partIn(["system"])
          headHeight: Style.space(44)

          head: SummaryRow {
            glyph: "cpu"
            title: "System"
            summary: "CPU " + Math.round(cc.sys.cpu * 100) + "% · Memory " + Math.round(cc.sys.memory * 100) + "%"
              + (cc.sys.temperature > 0 ? " · " + Math.round(cc.sys.temperature) + "°" : "")
            expanded: systemFold.open
            onOpened: cc.toggle("system")
          }

          Section {
            shown: true
            title: "Activity"
            actionGlyph: "chart"
            actionLabel: "Activity Monitor"
            onAction: { cc.host.closeControlCenter(); Util.execDetached("omarchy-launch-or-focus-tui btop") }

            Meter { glyph: "cpu"; label: "CPU"; value: cc.sys.cpu; readout: Math.round(cc.sys.cpu * 100) + "%" }
            Meter { glyph: "grid"; label: "Memory"; value: cc.sys.memory; readout: cc.sys.memoryUsedGb.toFixed(1) + " / " + Math.round(cc.sys.memoryTotalGb) + " GB" }
            Meter { glyph: "thermo"; label: "Temperature"; value: Math.min(1, cc.sys.temperature / 100); readout: Math.round(cc.sys.temperature) + " °C" }
            Meter { glyph: "disk"; label: "Storage"; value: cc.sys.storage; readout: Math.round(cc.sys.storageUsedGb) + " / " + Math.round(cc.sys.storageTotalGb) + " GB" }
          }
        }

        // ---- agents: how close each AI agent is to its limits ---------------
        Fold {
          id: agentsFold
          part: cc.partIn(["agents"])
          headHeight: Style.space(44)
          visible: cc.sys.agents.length > 0

          head: SummaryRow {
            glyph: "sparkle"
            title: "Agents"
            summary: cc.sys.agents.filter(function(a) { return a.limits.length > 0 }).slice(0, 2).map(function(a) {
              return a.name.split(" ")[0] + " " + Math.round(Math.max.apply(null, a.limits.map(function(l) { return l.percent })) * 100) + "%"
            }).join(" · ")
            expanded: agentsFold.open
            onOpened: cc.toggle("agents")
          }

          Section {
            shown: true
            title: "Usage"
            actionGlyph: "refresh"
            onAction: cc.sys.updateAgents(true)

            Repeater {
              model: cc.sys.agents

              Column {
                id: agent
                required property var modelData
                width: parent.width
                bottomPadding: Style.space(6)

                Item {
                  width: parent.width
                  height: Style.space(26)

                  Text {
                    x: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: agent.modelData.name
                    color: cc.ink
                    font.family: cc.ds.fontUi
                    font.pixelSize: 13
                    font.weight: Font.Medium
                  }

                  Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: agent.modelData.prompts > 0
                      ? agent.modelData.prompts + " prompts today" + (agent.modelData.tier ? " · " + agent.modelData.tier : "")
                      : agent.modelData.tier
                    color: cc.ink3
                    font.family: cc.ds.fontUi
                    font.pixelSize: 11
                  }
                }

                Repeater {
                  model: agent.modelData.limits

                  Meter {
                    required property var modelData
                    glyph: "gauge"
                    label: modelData.label || "Limit"
                    value: Number(modelData.percent) || 0
                    readout: Math.round((Number(modelData.percent) || 0) * 100) + "%"
                    note: cc.resetsIn(modelData.resetsAt)
                  }
                }

                Text {
                  visible: agent.modelData.limits.length === 0
                  leftPadding: Style.space(8)
                  width: parent.width
                  textFormat: Text.PlainText
                  text: agent.modelData.status || "No limits reported"
                  elide: Text.ElideRight
                  color: cc.ink2
                  font.family: cc.ds.fontUi
                  font.pixelSize: 11
                }
              }
            }
          }
        }


        // ---- battery, lock, power ------------------------------------------------
        // The battery flows out over lock and power, then opens to its modes.
        Item {
          width: body.width
          height: batteryFold.visible ? batteryFold.height : Style.space(24)

          Fold {
            id: batteryFold
            z: 1
            visible: cc.sys.hasBattery
            part: cc.partIn(["battery"])
            restWidth: batteryRow.implicitWidth + Style.space(12)
            quietWhenClosed: true
            hovered: batteryHover.hovered
            headHeight: Style.space(24) + grow * Style.space(10)

            head: Item {
              width: batteryFold.width
              height: batteryFold.headHeight

              Row {
                id: batteryRow
                x: Style.space(6) + batteryFold.grow * Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)

                BatteryGlyph { anchors.verticalCenter: parent.verticalCenter; size: 15; sys: cc.sys; color: cc.ink2; lowColor: cc.ds.signal }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  textFormat: Text.PlainText
                  text: Math.round(cc.sys.batteryLevel * 100) + "%" + (cc.sys.batteryTime ? " · " + cc.sys.batteryTime : "")
                  color: cc.ink2
                  font.family: cc.ds.fontUi
                  font.pixelSize: 12
                  font.features: { "tnum": 1 }
                }

                SumiIcon {
                  anchors.verticalCenter: parent.verticalCenter
                  name: "chevron"
                  size: 12
                  color: cc.ink3
                  rotation: batteryFold.open ? 90 : 0
                  Behavior on rotation { NumberAnimation { duration: 140 } }
                }
              }

              HoverHandler { id: batteryHover; cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: cc.toggle("battery") }
            }

            Section {
              shown: true
              title: "Power mode"

              Rectangle {
                visible: cc.sys.profiles.length > 0
                width: parent.width
                height: Style.space(34)
                radius: cc.ds.rRow + 3
                color: cc.raised2

                Row {
                  anchors.fill: parent
                  anchors.margins: Style.space(3)

                  Repeater {
                    model: cc.sys.profiles

                    Rectangle {
                      id: mode
                      required property string modelData
                      readonly property bool current: modelData === cc.sys.profile
                      width: parent.width / Math.max(1, cc.sys.profiles.length)
                      height: parent.height
                      radius: cc.ds.rRow
                      color: current ? cc.ds.on : "transparent"
                      Behavior on color { ColorAnimation { duration: 140 } }

                      // Text only, as in the design, kept inside its segment.
                      Text {
                        anchors.centerIn: parent
                        width: parent.width - Style.space(8)
                        horizontalAlignment: Text.AlignHCenter
                        textFormat: Text.PlainText
                        text: mode.modelData === "power-saver" ? "Saver" : mode.modelData === "performance" ? "Performance" : "Balanced"
                        elide: Text.ElideRight
                        color: mode.current ? cc.ds.onInk : cc.ink2
                        font.family: cc.ds.fontUi
                        font.pixelSize: 12
                        font.weight: Font.Medium
                      }

                      HoverHandler { cursorShape: Qt.PointingHandCursor }
                      TapHandler { onTapped: cc.sys.setProfile(mode.modelData) }
                    }
                  }
                }
              }

              Grid {
                width: parent.width
                columns: 3
                topPadding: Style.space(10)
                bottomPadding: Style.space(4)
                leftPadding: Style.space(4)
                columnSpacing: Style.space(8)

                Stat { label: cc.sys.charging ? "Charge rate" : "Power draw"; value: cc.sys.powerDraw > 0 ? (cc.sys.powerDrawEstimated ? "≈ " : "") + cc.sys.powerDraw.toFixed(1) + " W" : "—" }
                Stat { label: "Health"; value: cc.sys.health > 0 ? Math.round(cc.sys.health) + "%" : "—" }
                Stat { label: "Capacity"; value: cc.sys.capacity > 0 ? Math.round(cc.sys.capacity) + " Wh" : "—" }
              }
            }
          }

          Row {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(4)
            y: (Style.space(24) - height) / 2
            spacing: Style.space(14)
            opacity: 1 - batteryFold.grow
            visible: opacity > 0

            IconButton {
              glyph: "lock"; size: 15; tint: cc.ink2
              onClicked: { cc.host.closeControlCenter(); Util.execDetached("omarchy-system-lock") }
            }
            IconButton {
              glyph: "power"; size: 15; tint: cc.ink2
              onClicked: { cc.host.closeControlCenter(); Util.execDetached("omarchy-shell shell summon omarchy.menu '{\"menu\":\"system\"}'") }
            }
          }
        }
      }
    }
  }

  // ---- pieces --------------------------------------------------------------------

  // A connection row: the badge switches it, the rest of the row opens it.
  component ConnectionRow: Item {
    id: crow
    property string glyph: ""
    property string label: ""
    property string value: ""
    property bool on: false
    property bool expanded: false
    signal toggled()
    signal opened()

    width: parent ? parent.width : 0
    height: Style.space(42)

    Rectangle {
      anchors.fill: parent
      radius: cc.ds.rRow
      color: crow.expanded || crowHover.hovered ? cc.raised : "transparent"
    }

    HoverHandler { id: crowHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: crow.opened() }

    Rectangle {
      id: badge
      x: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(30)
      height: width
      radius: width / 2
      color: crow.on ? cc.ds.on : cc.raised2
      Behavior on color { ColorAnimation { duration: 160 } }

      SumiIcon {
        anchors.centerIn: parent
        name: crow.glyph
        size: 15
        color: crow.on ? cc.ds.onInk : cc.ink
      }

      // Takes the click, so switching doesn't also open the row.
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: crow.toggled()
      }
    }

    Column {
      anchors.left: badge.right
      anchors.leftMargin: Style.space(10)
      anchors.right: crowChevron.left
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter

      Text {
        textFormat: Text.PlainText
        text: crow.label
        color: cc.ink
        font.family: cc.ds.fontUi
        font.pixelSize: 13
        font.weight: Font.Medium
      }

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: crow.value
        elide: Text.ElideRight
        color: cc.ink2
        font.family: cc.ds.fontUi
        font.pixelSize: 12
      }
    }

    SumiIcon {
      id: crowChevron
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      name: "chevron"
      size: 12
      color: cc.ink3
      rotation: crow.expanded ? 90 : 0
      Behavior on rotation { NumberAnimation { duration: 140 } }
    }
  }

  component QuickTile: Rectangle {
    id: tile
    property string glyph: ""
    property string label: ""
    property bool on: false
    signal toggled()

    width: parent ? parent.width : 0
    radius: cc.ds.rTile
    color: on ? cc.ds.on : tileHover.hovered ? cc.raised2 : cc.raised
    Behavior on color { ColorAnimation { duration: 160 } }

    // Glyph and label side by side, the label wrapping to a second line
    // rather than leaving the tile, so a short tile still holds it all.
    SumiIcon {
      id: tileGlyph
      x: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      name: tile.glyph
      size: 15
      color: tile.on ? cc.ds.onInk : cc.ink
    }

    Text {
      anchors.left: tileGlyph.right
      anchors.leftMargin: Style.space(8)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: tile.label
      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight
      lineHeight: 0.95
      color: tile.on ? cc.ds.onInk : cc.ink
      font.family: cc.ds.fontUi
      font.pixelSize: 11
      font.weight: Font.Medium
    }

    HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tile.toggled() }
  }

  // A tile that opens downward into more of itself. One sharing its row
  // (restWidth set) first flows out to the full width while its neighbours
  // give way, and opens only once it has the room; closing runs backwards.
  // The open part stays drawn while it folds away, so it doesn't blink out.
  component Fold: Rectangle {
    id: fold
    property string part: ""
    readonly property bool open: part !== ""
    property string shownPart: ""
    property real headHeight: 0
    property real restWidth: -1
    property bool quietWhenClosed: false
    property bool hovered: false
    property alias head: foldHead.data
    default property alias content: foldBody.data

    readonly property bool shares: restWidth >= 0
    readonly property real grow: growSpring.value
    readonly property real drop: dropSpring.value
    // Eased, so moving between parts of an open fold resizes smoothly.
    property real bodyHeight: foldBody.implicitHeight
    Behavior on bodyHeight {
      enabled: fold.drop === 1
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    onPartChanged: if (part !== "") shownPart = part
    // A part that shares its row widens first and its body drops a beat
    // later; closing lifts the body first, then narrows. Both on springs, so
    // a part opened and closed in quick succession turns around smoothly.
    onOpenChanged: {
      stagger.stop()
      if (open) {
        if (shares) { growSpring.target = 1; stagger.interval = 60; stagger.start() }
        else { growSpring.snap(1); dropSpring.target = 1 }
      } else {
        dropSpring.target = 0
        if (shares) { stagger.interval = 40; stagger.start() }
        else growSpring.snap(0)
      }
    }

    // The spring may overshoot a touch: let the height show it, never the
    // width, which would poke past the panel's edge.
    width: shares ? Math.min(body.width, restWidth + (body.width - restWidth) * grow) : body.width
    height: headHeight + drop * (bodyHeight + Style.space(1))
    // The corners swell a little mid-flow and settle, like a drop spreading.
    radius: cc.ds.rTile + (shares ? Math.sin(grow * Math.PI) * cc.ds.rTile * 0.5 : 0)
    clip: true
    color: !quietWhenClosed ? cc.raised
      : Qt.rgba(cc.raised.r, cc.raised.g, cc.raised.b, cc.raised.a * Math.max(grow, hovered ? 1 : 0))

    SumiSpring {
      id: growSpring
      animated: Style.duration(1) > 0
      response: fold.open ? 0.34 : 0.26
      dampingRatio: fold.open ? 0.84 : 1
    }
    SumiSpring {
      id: dropSpring
      animated: Style.duration(1) > 0
      response: fold.open ? 0.36 : cc.ds.closeResponse
      dampingRatio: fold.open ? 0.8 : cc.ds.closeDamping
      // Settled open: bring the part into view.
      onMovingChanged: if (!moving && fold.open) cc.reveal(fold)
    }
    Timer {
      id: stagger
      onTriggered: {
        if (fold.open) dropSpring.target = 1
        else growSpring.target = 0
      }
    }

    // Closed with the control center: start from rest next time, once it has
    // faded out.
    Connections {
      target: cc
      function onSettledClosedChanged() {
        if (!cc.settledClosed) return
        stagger.stop()
        growSpring.snap(0)
        dropSpring.snap(0)
      }
    }

    Item {
      id: foldHead
      width: parent.width
      height: fold.headHeight
    }

    Rectangle {
      x: Style.space(12)
      y: fold.headHeight
      width: parent.width - Style.space(24)
      height: 1
      color: cc.ds.line
      opacity: fold.drop
    }

    Column {
      id: foldBody
      y: fold.headHeight + Style.space(1)
      width: parent.width
      visible: fold.drop > 0
      opacity: Math.min(1, fold.drop * 1.5)
    }
  }

  // What a Fold opens to: a title, an optional action, and the content.
  component Section: Item {
    id: section
    property bool shown: false
    property string title: ""
    property string actionGlyph: ""
    property string actionLabel: ""
    default property alias content: sectionBody.data
    signal action()

    width: parent ? parent.width : 0
    visible: shown
    height: shown ? sectionColumn.implicitHeight + Style.space(10) : 0

    Column {
      id: sectionColumn
      x: Style.space(6)
      y: Style.space(4)
      width: parent.width - Style.space(12)

      Item {
        width: parent.width
        height: Style.space(26)

        Text {
          x: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: section.title
          color: cc.ink2
          font.family: cc.ds.fontUi
          font.pixelSize: 12
        }

        Rectangle {
          visible: section.actionGlyph !== ""
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: actionRow.implicitWidth + Style.space(12)
          height: Style.space(22)
          radius: cc.ds.rChip
          color: actionHover.hovered ? cc.raised2 : "transparent"

          Row {
            id: actionRow
            anchors.centerIn: parent
            spacing: Style.space(4)

            SumiIcon { anchors.verticalCenter: parent.verticalCenter; name: section.actionGlyph; size: 13; color: cc.ink2 }

            Text {
              visible: section.actionLabel !== ""
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: section.actionLabel
              color: cc.ink2
              font.family: cc.ds.fontUi
              font.pixelSize: 12
            }
          }

          HoverHandler { id: actionHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: section.action() }
        }
      }

      Column {
        id: sectionBody
        width: parent.width
      }
    }
  }

  // A row in a list: glyph, title, detail, and a check when it's the current one.
  component ListRow: Item {
    id: lrow
    property string glyph: ""
    property string title: ""
    property string detail: ""
    property bool checked: false
    signal clicked()

    width: parent ? parent.width : 0
    height: Style.space(38)

    Rectangle {
      anchors.fill: parent
      radius: cc.ds.rRow
      color: lrowHover.hovered ? cc.raised2 : "transparent"
    }

    SumiIcon {
      id: lrowGlyph
      x: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      name: lrow.glyph
      size: 15
      color: lrow.checked ? cc.ink : cc.ink2
    }

    Column {
      anchors.left: lrowGlyph.right
      anchors.leftMargin: Style.space(10)
      anchors.right: lrowCheck.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: lrow.title
        elide: Text.ElideRight
        color: cc.ink
        font.family: cc.ds.fontUi
        font.pixelSize: 13
      }

      Text {
        width: parent.width
        visible: lrow.detail !== ""
        textFormat: Text.PlainText
        text: lrow.detail
        elide: Text.ElideRight
        color: cc.ink2
        font.family: cc.ds.fontUi
        font.pixelSize: 11
      }
    }

    SumiIcon {
      id: lrowCheck
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      visible: lrow.checked
      name: "check"
      size: 14
      color: cc.ink
    }

    HoverHandler { id: lrowHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: lrow.clicked() }
  }

  // A Wi-Fi network. A secured one you haven't joined opens a password
  // field in place; the connected one offers to disconnect, a saved one to
  // be forgotten.
  component NetworkRow: Column {
    id: nrow
    property var net: ({})
    readonly property bool joining: cc.sys.joining === net.ssid
    readonly property bool failed: cc.sys.joinErrorSsid === net.ssid && cc.sys.joinError !== ""
    readonly property bool asking: cc.openNetwork === net.ssid && !net.inUse && !net.known && net.secure === true
    readonly property bool menuOpen: cc.openNetwork === net.ssid && (net.inUse === true || net.known === true)
    onAskingChanged: if (!asking) password.text = ""

    width: parent ? parent.width : 0

    Item {
      width: parent.width
      height: Style.space(38)

      Rectangle {
        anchors.fill: parent
        radius: cc.ds.rRow
        color: nrowHover.hovered || nrow.asking || nrow.menuOpen ? cc.raised2 : "transparent"
      }

      SumiIcon {
        id: nrowGlyph
        x: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        name: "wifi"
        size: 15
        color: nrow.net.inUse ? cc.ink : cc.ink2
        // Weaker signal, fainter glyph.
        opacity: 0.45 + 0.55 * Math.min(1, (nrow.net.signal || 0) / 70)
      }

      Column {
        anchors.left: nrowGlyph.right
        anchors.leftMargin: Style.space(10)
        anchors.right: nrowTrail.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: nrow.net.ssid
          elide: Text.ElideRight
          color: cc.ink
          font.family: cc.ds.fontUi
          font.pixelSize: 13
          font.weight: nrow.net.inUse ? Font.Medium : Font.Normal
        }

        Text {
          width: parent.width
          visible: text !== ""
          textFormat: Text.PlainText
          text: nrow.joining ? "Joining…" : nrow.net.inUse ? "Connected" : nrow.net.known ? "Saved" : ""
          color: cc.ink2
          font.family: cc.ds.fontUi
          font.pixelSize: 11
        }
      }

      Row {
        id: nrowTrail
        anchors.right: parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        SumiIcon { anchors.verticalCenter: parent.verticalCenter; visible: nrow.net.secure === true; name: "lock"; size: 13; color: cc.ink3 }
        SumiIcon { anchors.verticalCenter: parent.verticalCenter; visible: nrow.net.inUse === true; name: "check"; size: 14; color: cc.ink }
      }

      HoverHandler { id: nrowHover; cursorShape: Qt.PointingHandCursor }
      TapHandler {
        onTapped: {
          if (nrow.joining) return
          if (nrow.net.inUse || nrow.net.known || nrow.net.secure) {
            cc.openNetwork = nrow.asking || nrow.menuOpen ? "" : nrow.net.ssid
            if (nrow.asking) password.forceActiveFocus()
            return
          }
          cc.sys.join(nrow.net, "")
        }
      }
    }

    // Saved or connected: what can be done with it.
    Row {
      visible: nrow.menuOpen
      x: Style.space(33)
      height: Style.space(34)
      spacing: Style.space(6)

      TextButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: !nrow.net.inUse
        label: "Join"
        primary: true
        onClicked: { cc.openNetwork = ""; cc.sys.join(nrow.net, "") }
      }
      TextButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: nrow.net.inUse === true
        label: "Disconnect"
        onClicked: { cc.openNetwork = ""; cc.sys.leave(nrow.net) }
      }
      TextButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: nrow.net.known === true
        label: "Forget"
        onClicked: { cc.openNetwork = ""; cc.sys.forget(nrow.net) }
      }
    }

    // A new secured network: its password.
    Item {
      visible: nrow.asking
      width: parent.width
      height: Style.space(40)

      Rectangle {
        id: field
        // Both edges anchored: with only x and a right anchor the field has
        // no width, so it can't be seen or clicked.
        anchors.left: parent.left
        anchors.leftMargin: Style.space(33)
        anchors.right: joinButton.left
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        height: Style.space(30)
        radius: cc.ds.rRow
        color: cc.raised2
        border.width: 1
        border.color: password.activeFocus ? Qt.rgba(cc.ink.r, cc.ink.g, cc.ink.b, 0.25) : "transparent"

        TextInput {
          id: password
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          verticalAlignment: TextInput.AlignVCenter
          echoMode: TextInput.Password
          passwordCharacter: "•"
          clip: true
          color: cc.ink
          font.family: cc.ds.fontUi
          font.pixelSize: 13
          Keys.onReturnPressed: joinButton.clicked()
          Keys.onEscapePressed: { cc.openNetwork = ""; text = "" }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !password.text
            textFormat: Text.PlainText
            text: "Password"
            color: cc.ink3
            font: password.font
          }
        }
      }

      TextButton {
        id: joinButton
        anchors.right: parent.right
        anchors.rightMargin: Style.space(4)
        anchors.verticalCenter: parent.verticalCenter
        label: nrow.joining ? "Joining…" : "Join"
        primary: true
        onClicked: {
          if (nrow.joining) return
          if (password.text.length === 0) { password.forceActiveFocus(); return }
          cc.sys.join(nrow.net, password.text)
          password.text = ""
          cc.openNetwork = ""
        }
      }
    }

    Text {
      visible: nrow.failed
      x: Style.space(33)
      width: parent.width - x
      bottomPadding: Style.space(6)
      textFormat: Text.PlainText
      text: cc.sys.joinError
      wrapMode: Text.WordWrap
      color: cc.ds.signal
      font.family: cc.ds.fontUi
      font.pixelSize: 11
    }
  }

  // A group's one-line summary, opening to its detail.
  component SummaryRow: Rectangle {
    id: srow
    property string glyph: ""
    property string title: ""
    property string summary: ""
    property bool expanded: false
    signal opened()

    width: parent ? parent.width : 0
    height: Style.space(44)
    radius: cc.ds.rTile
    color: srowHover.hovered && !expanded ? cc.raised2 : cc.raised

    SumiIcon {
      id: srowGlyph
      x: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      name: srow.glyph
      size: 15
      color: cc.ink2
    }

    Text {
      id: srowTitle
      anchors.left: srowGlyph.right
      anchors.leftMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: srow.title
      color: cc.ink
      font.family: cc.ds.fontUi
      font.pixelSize: 13
      font.weight: Font.Medium
    }

    Text {
      anchors.left: srowTitle.right
      anchors.leftMargin: Style.space(12)
      anchors.right: srowChevron.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignRight
      textFormat: Text.PlainText
      text: srow.summary
      elide: Text.ElideRight
      color: cc.ink2
      font.family: cc.ds.fontUi
      font.pixelSize: 12
      font.features: { "tnum": 1 }
    }

    SumiIcon {
      id: srowChevron
      anchors.right: parent.right
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      name: "chevron"
      size: 12
      color: cc.ink3
      rotation: srow.expanded ? 90 : 0
      Behavior on rotation { NumberAnimation { duration: 140 } }
    }

    HoverHandler { id: srowHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: srow.opened() }
  }

  // A label and its value, stacked.
  component Fact: Column {
    id: fact
    property string label: ""
    property string value: ""

    Text {
      textFormat: Text.PlainText
      text: fact.label
      color: cc.ink3
      font.family: cc.ds.fontUi
      font.pixelSize: 11
    }

    Text {
      textFormat: Text.PlainText
      text: fact.value
      color: cc.ink
      font.family: cc.ds.fontUi
      font.pixelSize: 13
    }
  }

  // A labelled meter: glyph, name, bar, and its reading.
  component Meter: Item {
    id: meter
    property string glyph: ""
    property string label: ""
    property real value: 0
    property string readout: ""
    // A quiet line under the bar (when a limit resets).
    property string note: ""

    width: parent ? parent.width : 0
    height: note !== "" ? Style.space(56) : Style.space(42)

    SumiIcon {
      id: meterGlyph
      x: Style.space(8)
      y: Style.space(6)
      name: meter.glyph
      size: 14
      color: cc.ink2
    }

    Text {
      anchors.left: meterGlyph.right
      anchors.leftMargin: Style.space(8)
      anchors.right: meterReadout.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: meterGlyph.verticalCenter
      textFormat: Text.PlainText
      text: meter.label
      elide: Text.ElideRight
      color: cc.ink
      font.family: cc.ds.fontUi
      font.pixelSize: 12
    }

    Text {
      x: Style.space(8)
      y: Style.space(38)
      visible: meter.note !== ""
      textFormat: Text.PlainText
      text: meter.note
      color: cc.ink3
      font.family: cc.ds.fontUi
      font.pixelSize: 11
    }

    Text {
      id: meterReadout
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: meterGlyph.verticalCenter
      textFormat: Text.PlainText
      text: meter.readout
      color: cc.ink2
      font.family: cc.ds.fontMono
      font.pixelSize: 11
    }

    Rectangle {
      x: Style.space(8)
      y: Style.space(28)
      width: parent.width - Style.space(16)
      height: Style.space(4)
      radius: height / 2
      color: Qt.rgba(cc.ink.r, cc.ink.g, cc.ink.b, 0.10)

      Rectangle {
        width: parent.width * Math.max(0, Math.min(1, meter.value))
        height: parent.height
        radius: parent.radius
        // Shu red only when it matters.
        color: meter.value > 0.9 ? cc.ds.signal : cc.ink
        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
      }
    }
  }

  component SettingLabel: Text {
    leftPadding: Style.space(8)
    topPadding: Style.space(8)
    bottomPadding: Style.space(6)
    textFormat: Text.PlainText
    color: cc.ink2
    font.family: cc.ds.fontUi
    font.pixelSize: 11
  }

  // A row of mutually exclusive choices.
  component Segmented: Rectangle {
    id: seg
    property var options: []
    property var current: null
    property var label: function(v) { return String(v) }
    signal picked(var value)

    width: parent ? parent.width : 0
    height: Style.space(32)
    radius: cc.ds.rRow + 3
    color: cc.raised2

    Row {
      anchors.fill: parent
      anchors.margins: Style.space(3)

      Repeater {
        model: seg.options

        Rectangle {
          id: segItem
          required property var modelData
          readonly property bool on: Math.abs(Number(modelData) - Number(seg.current)) < 0.01
          width: parent.width / Math.max(1, seg.options.length)
          height: parent.height
          radius: cc.ds.rRow
          color: on ? cc.ds.on : "transparent"
          Behavior on color { ColorAnimation { duration: 140 } }

          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: seg.label(segItem.modelData)
            color: segItem.on ? cc.ds.onInk : cc.ink2
            font.family: cc.ds.fontUi
            font.pixelSize: 12
            font.weight: Font.Medium
          }

          HoverHandler { cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: seg.picked(segItem.modelData) }
        }
      }
    }
  }

  component StepButton: Rectangle {
    id: step
    property string glyph: ""
    signal clicked()

    width: Style.space(26)
    height: Style.space(26)
    radius: cc.ds.rRow
    color: stepHover.hovered ? Qt.rgba(cc.ink.r, cc.ink.g, cc.ink.b, 0.10) : "transparent"

    SumiIcon { anchors.centerIn: parent; name: step.glyph; size: 14; color: cc.ink }

    HoverHandler { id: stepHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: step.clicked() }
  }

  component TextButton: Rectangle {
    id: tb
    property string label: ""
    property bool primary: false
    signal clicked()

    width: tbText.implicitWidth + Style.space(20)
    height: Style.space(28)
    radius: cc.ds.rRow
    color: primary ? cc.ds.on : tbHover.hovered ? cc.raised2 : cc.raised

    Text {
      id: tbText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: tb.label
      color: tb.primary ? cc.ds.onInk : cc.ink
      font.family: cc.ds.fontUi
      font.pixelSize: 12
      font.weight: Font.Medium
    }

    HoverHandler { id: tbHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tb.clicked() }
  }

  component Stat: Column {
    id: stat
    property string label: ""
    property string value: ""
    width: (body.width - Style.space(40)) / 3

    Text {
      textFormat: Text.PlainText
      text: stat.value
      color: cc.ink
      font.family: cc.ds.fontUi
      font.pixelSize: 13
      font.weight: Font.Medium
      font.features: { "tnum": 1 }
    }

    Text {
      textFormat: Text.PlainText
      text: stat.label
      color: cc.ink2
      font.family: cc.ds.fontUi
      font.pixelSize: 11
    }
  }

  component SliderTile: Rectangle {
    id: slider
    property string label: ""
    property string detail: ""
    property string glyph: ""
    property real value: 0
    property bool expandable: false
    property bool expanded: false
    signal moved(real value)
    signal opened()

    width: parent ? parent.width : 0
    height: Style.space(58)
    radius: cc.ds.rTile
    color: cc.raised

    Row {
      x: Style.space(12)
      y: Style.space(9)
      width: parent.width - Style.space(24)
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText
        text: slider.label
        color: cc.ink2
        font.family: cc.ds.fontUi
        font.pixelSize: 11
      }

      Text {
        visible: slider.detail !== ""
        width: Math.min(implicitWidth, parent.width - Style.space(80))
        textFormat: Text.PlainText
        text: "· " + slider.detail
        elide: Text.ElideRight
        color: cc.ink3
        font.family: cc.ds.fontUi
        font.pixelSize: 11
      }
    }

    // The whole top row, label to chevron, opens the fold; the slider
    // below it stays a slider. A faint wash marks it on hover.
    Rectangle {
      visible: slider.expandable
      x: Style.space(4)
      y: Style.space(4)
      width: parent.width - Style.space(8)
      height: Style.space(22)
      radius: cc.ds.rRow
      color: Qt.rgba(cc.ink.r, cc.ink.g, cc.ink.b, moreHover.hovered ? 0.06 : 0)
      Behavior on color { ColorAnimation { duration: 120 } }

      SumiIcon {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(5)
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron"
        size: 12
        color: moreHover.hovered || slider.expanded ? cc.ink2 : cc.ink3
        rotation: slider.expanded ? 90 : 0
        Behavior on rotation { NumberAnimation { duration: 140 } }
      }

      HoverHandler { id: moreHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: slider.opened() }
    }

    SumiIcon {
      id: sliderIcon
      x: Style.space(12)
      y: Style.space(32)
      name: slider.glyph
      size: 15
      color: cc.ink2
    }

    Item {
      id: track
      anchors.left: sliderIcon.right
      anchors.leftMargin: Style.space(10)
      anchors.right: readout.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: sliderIcon.verticalCenter
      height: Style.space(18)

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Style.space(6)
        radius: height / 2
        color: Qt.rgba(cc.ink.r, cc.ink.g, cc.ink.b, 0.10)

        Rectangle {
          width: parent.width * Math.max(0, Math.min(1, slider.value))
          height: parent.height
          radius: parent.radius
          color: cc.ink
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function pick(x) { slider.moved(Math.max(0, Math.min(1, x / width))) }
        onPressed: function(mouse) { pick(mouse.x) }
        onPositionChanged: function(mouse) { if (pressed) pick(mouse.x) }
      }

      WheelHandler {
        onWheel: function(event) { slider.moved(Math.max(0, Math.min(1, slider.value + (event.angleDelta.y > 0 ? 0.05 : -0.05)))) }
      }
    }

    Text {
      id: readout
      anchors.right: parent.right
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: sliderIcon.verticalCenter
      width: Style.space(32)
      horizontalAlignment: Text.AlignRight
      textFormat: Text.PlainText
      text: Math.round(slider.value * 100) + "%"
      color: cc.ink2
      font.family: cc.ds.fontMono
      font.pixelSize: 11
    }
  }

  component IconButton: Item {
    id: button
    property string glyph: ""
    property real size: 15
    property color tint: cc.ink
    signal clicked()

    width: size + Style.space(6)
    height: size + Style.space(6)

    SumiIcon {
      anchors.centerIn: parent
      name: button.glyph
      size: button.size
      color: button.tint
      opacity: buttonHover.hovered ? 0.7 : 1
    }

    HoverHandler { id: buttonHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: button.clicked() }
  }
}
