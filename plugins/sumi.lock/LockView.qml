import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// "Weeks": a sharp wallpaper under a dark wash, a giant clock and a prompt
// line bottom-left, and a whole life laid out as a grid of weeks on the
// right. The life grid reads birthYear / lifeExpectancy from the clock
// widget's entry in shell.json (the same memento mori the clock panel shows)
// and disappears when no birth year is set.
Item {
  id: root

  property string backgroundPath: ""
  property string videoPosterPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool fingerprintUnavailable: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  // A locked session blanks the displays after a few seconds. Nothing is
  // visible from then until the user wakes it, so a video must not keep
  // decoding through what is usually the longest part of a lock.
  property bool displaysBlank: false
  property bool powerSaverActive: false
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string placeholderText: Commons.I18n.t("lock.enterPassword")
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
  readonly property string hostName: String(hostnameFile.text() || "").trim()
  readonly property bool animating: root.loadBackground && !root.displaysBlank

  // Proportions follow the screen so the composition holds from a laptop
  // panel to a 4K monitor.
  readonly property real margin: Math.round(Math.max(48, Math.min(width, height) * 0.11))
  // Sumi: the interface typeface for every line of the lock screen.
  readonly property string uiFont: "Inter"
  readonly property int clockFontSize: Math.round(Math.min(height * 0.24, width * 0.15))
  readonly property int promptFontSize: Math.round(Style.font.heading * 1.25)
  readonly property int fieldWidth: Math.round(Math.max(320, Math.min(width * 0.3, clockMetrics.advanceWidth)))
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.1)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.35)
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property color lineColor: errorState
    ? Commons.Color.lock.borderError
    : (passwordInput.text.length > 0 ? Commons.Color.lock.borderActive : Util.alpha(Commons.Color.lock.text, 0.35))

  readonly property bool video: Util.isVideoPath(root.backgroundPath)
  readonly property bool feedActive: root.video && root.loadBackground && !root.displaysBlank && !root.powerSaverActive

  // --- Life in weeks -------------------------------------------------------
  property var clockSettings: ({})
  readonly property int birthYear: {
    var year = parseInt(clockSettings.birthYear, 10)
    var now = clock.date.getFullYear()
    return year > 1900 && year <= now ? year : 0
  }
  readonly property int lifeYears: {
    var years = parseInt(clockSettings.lifeExpectancy, 10)
    return years >= 10 && years <= 120 ? years : 80
  }
  readonly property bool showLife: birthYear > 0
  readonly property int totalWeeks: lifeYears * 52
  readonly property int livedWeeks: {
    if (!showLife) return 0
    var born = new Date(birthYear, 0, 1)
    var weeks = Math.floor((clock.date.getTime() - born.getTime()) / (7 * 86400000))
    return Math.max(0, Math.min(totalWeeks - 1, weeks))
  }

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  // Waking a DPMS-blanked display can stall the compositor for seconds while
  // the monitor modesets, so the wake key's release arrives late and client-side
  // key repeat floods the field with that character. A held key has no business
  // typing a password; only holding Backspace/Delete to clear stays useful.
  function dropsAutoRepeat(key) {
    return key !== Qt.Key_Backspace && key !== Qt.Key_Delete
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  function readClockSettings(raw) {
    var found = {}
    try {
      var layout = JSON.parse(raw || "{}").bar.layout
      for (var section in layout) {
        var widgets = layout[section] || []
        for (var i = 0; i < widgets.length; i++) {
          var id = String(widgets[i] && widgets[i].id || "")
          if (id === "omarchy.clock" || /\.clock$/.test(id)) found = widgets[i]
        }
      }
    } catch (e) {}
    clockSettings = found
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  onLoadBackgroundChanged: {
    if (loadBackground) intro.restart()
  }
  onFailedAttemptsChanged: {
    if (failedAttempts > 0) shake.restart()
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
    if (loadBackground) intro.restart()
  }

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  FileView {
    id: hostnameFile
    path: "/etc/hostname"
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.readClockSettings(text())
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: root.uiFont
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  TextMetrics {
    id: clockMetrics
    font: clockText.font
    text: clockText.text
  }

  ParallelAnimation {
    id: intro
    NumberAnimation { target: wallpaper; property: "scale"; from: 1.06; to: 1.0; duration: 1400; easing.type: Easing.OutCubic }
    NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }
    NumberAnimation { target: contentShift; property: "y"; from: 24; to: 0; duration: 700; easing.type: Easing.OutCubic }
    NumberAnimation { target: lifeGrid; property: "revealed"; from: 0; to: 1; duration: 1100; easing.type: Easing.OutQuart }
  }

  SequentialAnimation {
    id: shake
    NumberAnimation { target: promptShift; property: "x"; to: -14; duration: 50; easing.type: Easing.OutQuad }
    NumberAnimation { target: promptShift; property: "x"; to: 11; duration: 70; easing.type: Easing.InOutQuad }
    NumberAnimation { target: promptShift; property: "x"; to: -7; duration: 70; easing.type: Easing.InOutQuad }
    NumberAnimation { target: promptShift; property: "x"; to: 3; duration: 60; easing.type: Easing.InOutQuad }
    NumberAnimation { target: promptShift; property: "x"; to: 0; duration: 60; easing.type: Easing.OutQuad }
  }

  Rectangle {
    anchors.fill: parent
    color: Commons.Color.background
    clip: true

    BackgroundMedia {
      id: wallpaper
      objectName: "lockWallpaper"
      anchors.fill: parent
      path: root.loadBackground ? (root.video ? root.videoPosterPath : root.backgroundPath) : ""
      version: root.backgroundVersion
      // Decode only once sized, at the lock's own size: an unsized first
      // request decoded the file at its native resolution, then again once
      // sized. That size is what the lock service keeps decoded ahead of the
      // lock, so the first frame has the wallpaper.
      cached: true
      constrainDecode: true
      decodeSize: Qt.size(width, height)
    }

    // The cached poster stays behind the feed when policy pauses playback,
    // the module is unavailable, or a new connection has not received a frame.
    Loader {
      id: feedLoader
      objectName: "lockFeedLoader"
      anchors.fill: parent
      active: root.feedActive
      source: "LockFeedSurface.qml"
      visible: status === Loader.Ready
    }

    // An even wash keeps the grid legible over bright skies; the sideways
    // gradient deepens it under the clock.
    Rectangle {
      anchors.fill: parent
      color: Util.alpha(Commons.Color.background, 0.38)
    }

    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Util.alpha(Commons.Color.background, 0.92) }
        GradientStop { position: 0.45; color: Util.alpha(Commons.Color.background, 0.55) }
        GradientStop { position: 1.0; color: Util.alpha(Commons.Color.background, 0.45) }
      }
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: parent.height * 0.5
      gradient: Gradient {
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 1.0; color: Util.alpha(Commons.Color.background, 0.6) }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // --- Left column: identity, clock, date, prompt ------------------------
    Column {
      id: content
      anchors.left: parent.left
      anchors.leftMargin: root.margin
      anchors.bottom: parent.bottom
      anchors.bottomMargin: root.margin
      spacing: 0
      transform: Translate { id: contentShift }

      Row {
        spacing: Math.round(Style.font.heading * 0.6)

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: Math.round(Style.font.body * 0.6)
          height: width
          radius: width / 2
          color: Commons.Color.accent
        }

        Text {
          textFormat: Text.PlainText
          text: strings.t("lock.locked", "Locked").toUpperCase()
          color: Commons.Color.accent
          font.family: root.uiFont
          font.pixelSize: Style.font.body
          font.bold: true
          font.letterSpacing: Style.font.body * 0.3
        }

        Text {
          textFormat: Text.PlainText
          visible: root.userName.length > 0
          text: root.hostName.length > 0 ? root.userName + "@" + root.hostName : root.userName
          color: Util.alpha(Commons.Color.lock.text, 0.6)
          font.family: root.uiFont
          font.pixelSize: Style.font.body
          font.letterSpacing: Style.font.body * 0.1
        }
      }

      Text {
        id: clockText
        textFormat: Text.PlainText
        text: Qt.locale(Commons.I18n.formatLocale).toString(clock.date, "HH:mm")
        color: Commons.Color.lock.text
        font.family: root.uiFont
        font.pixelSize: root.clockFontSize
        // A light, tightly set clock with even-width figures.
        font.weight: Font.Light
        font.letterSpacing: -root.clockFontSize * 0.04
        font.features: { "tnum": 1 }
        // Pull the glyph box in so the digits sit tight against the label
        // above and the date below; the font's line box is far taller than
        // its numerals at this size.
        height: Math.round(root.clockFontSize * 1.02)
        verticalAlignment: Text.AlignVCenter
        leftPadding: -Math.round(root.clockFontSize * 0.04)
      }

      Text {
        textFormat: Text.PlainText
        text: Qt.locale(Commons.I18n.formatLocale).toString(clock.date, "dddd, d MMMM")
        color: Commons.Color.accent
        font.family: root.uiFont
        font.pixelSize: Math.round(root.clockFontSize * 0.14)
      }

      Item { width: 1; height: Math.round(root.clockFontSize * 0.32) }

      // Prompt line: a chevron, the masked input, and a hairline beneath that
      // takes the accent while typing and the urgent color on failure.
      Item {
        width: root.fieldWidth
        height: promptRow.height + Math.round(Style.font.heading * 0.7) + 2
        transform: Translate { id: promptShift }

        Item {
          id: promptRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: Math.round(root.promptFontSize * 1.9)

          Text {
            id: chevron
            textFormat: Text.PlainText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "›"
            color: root.errorState ? Commons.Color.lock.textError : Commons.Color.accent
            font.family: root.uiFont
            font.pixelSize: Math.round(root.promptFontSize * 1.4)
            font.bold: true
          }

          TextInput {
            id: passwordInput
            anchors.left: chevron.right
            anchors.leftMargin: Math.round(root.promptFontSize * 0.7)
            anchors.right: fingerprintIcon.visible ? fingerprintIcon.left : parent.right
            anchors.rightMargin: fingerprintIcon.visible ? Math.round(root.promptFontSize * 0.6) : 0
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignLeft
            activeFocusOnPress: true
            clip: true
            enabled: root.inputEnabled && !root.authenticatingPassword
            readOnly: root.authenticatingPassword
            echoMode: TextInput.Password
            passwordCharacter: "●"
            passwordMaskDelay: 0
            color: Commons.Color.lock.text
            selectionColor: Commons.Color.lock.selection
            selectedTextColor: Commons.Color.lock.text
            font.family: root.uiFont
            font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.promptFontSize
            font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
            cursorVisible: activeFocus && root.showPasswordCursor
            cursorDelegate: Rectangle {
              width: Math.max(2, Math.round(root.promptFontSize * 0.5))
              color: Commons.Color.accent
              visible: passwordInput.cursorVisible
              opacity: blink.on ? 1 : 0.15
              Behavior on opacity { NumberAnimation { duration: 180 } }
            }

            onTextChanged: {
              if (!root.syncingPasswordText) root.passwordTextEdited(text)
              if (text.length > 0) {
                root.wakeRequested()
              }
              if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
            }

            onAccepted: {
              var submitted = root.passwordText
              root.passwordTextEdited("")
              if (submitted.length > 0) root.submitPassword(submitted)
            }

            Keys.onPressed: function(event) {
              root.wakeRequested()
              if (event.isAutoRepeat && root.dropsAutoRepeat(event.key)) {
                event.accepted = true
                return
              }
              if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                root.passwordTextEdited("")
                event.accepted = true
              }
            }
          }

          Timer {
            id: blink
            property bool on: true
            interval: 530
            repeat: true
            running: root.animating && passwordInput.cursorVisible
            onRunningChanged: on = true
            onTriggered: on = !on
          }

          Text {
            textFormat: Text.PlainText
            anchors.fill: passwordInput
            // Leave room for the block cursor, which sits at the start of an
            // empty field.
            leftPadding: passwordInput.cursorVisible ? Math.round(root.promptFontSize * 0.9) : 0
            text: root.authenticatingPassword ? Commons.I18n.t("lock.checking") : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
            visible: passwordInput.text.length === 0
            color: root.authenticatingPassword ? Commons.Color.lock.text : (root.failureMessage.length > 0 ? Commons.Color.lock.textError : Commons.Color.lock.placeholder)
            font.family: root.uiFont
            font.pixelSize: root.promptFontSize
            font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }

          // Fingerprint hint at the end of the prompt when a sensor is
          // enrolled, so the user knows they can touch to unlock instead of
          // typing. A reader the shell cannot reach crosses out rather than
          // disappears, so it stops inviting touches that can never unlock.
          Text {
            id: fingerprintIcon
            objectName: "fingerprintIndicator"
            textFormat: Text.PlainText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.fingerprintConfigured
            text: root.fingerprintUnavailable ? "󰺱" : "󰈷"
            color: root.fingerprintUnavailable ? Commons.Color.lock.textError : Commons.Color.lock.placeholder
            font.family: root.uiFont
            font.pixelSize: Math.round(root.promptFontSize * 1.2)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
        }

        Rectangle {
          id: underline
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: 2
          clip: true
          color: root.lineColor
          Behavior on color { ColorAnimation { duration: 200 } }

          // Indeterminate sweep while PAM checks the password.
          Rectangle {
            id: sweep
            visible: root.authenticatingPassword
            width: parent.width * 0.28
            height: parent.height
            color: Commons.Color.accent
            NumberAnimation on x {
              running: root.authenticatingPassword && root.animating
              loops: Animation.Infinite
              from: -sweep.width
              to: underline.width
              duration: 900
              easing.type: Easing.InOutCubic
            }
          }
        }
      }

      // The crossed-out icon has no meaning to a user who has never seen it —
      // it is not intuitive that it signals a broken reader — so the words
      // carry the explanation and the icon only reinforces it.
      Text {
        objectName: "fingerprintUnavailableNotice"
        textFormat: Text.PlainText
        topPadding: 12
        visible: root.fingerprintConfigured && root.fingerprintUnavailable
        text: Commons.I18n.t("lock.fingerprintUnavailable")
        color: Commons.Color.lock.textError
        font.family: root.uiFont
        font.pixelSize: Style.font.body
        font.italic: true
      }
    }

    // --- Right: a life in weeks ---------------------------------------------
    Item {
      id: lifePanel
      visible: root.showLife
      anchors.right: parent.right
      anchors.rightMargin: root.margin
      // Shares the prompt's baseline so the two columns rest on one line.
      anchors.bottom: parent.bottom
      anchors.bottomMargin: root.margin
      width: lifeGrid.width
      height: lifeHeader.height + lifeGrid.height + lifeFooter.height + 2 * lifeGrid.gap

      Text {
        id: lifeHeader
        textFormat: Text.PlainText
        anchors.left: parent.left
        anchors.top: parent.top
        text: strings.t("lock.week", "Week %1 of %2")
          .arg(Commons.I18n.formatNumber(root.livedWeeks + 1))
          .arg(Commons.I18n.formatNumber(root.totalWeeks))
          .toUpperCase()
        color: Commons.Color.lock.text
        font.family: root.uiFont
        font.pixelSize: Style.font.body
        font.bold: true
        font.letterSpacing: Style.font.body * 0.2
      }

      Canvas {
        id: lifeGrid
        property real revealed: 1
        // Cell pitch fits 52 columns into a third of the screen and every
        // row of life into most of its height, with a wider gap each decade.
        readonly property int gap: Math.round(Style.font.body * 1.2)
        readonly property int decades: Math.ceil(root.lifeYears / 10)
        readonly property int cell: Math.max(4, Math.floor(Math.min(
          (root.width * 0.3) / 52,
          (root.height * 0.66 - (decades - 1) * 4) / root.lifeYears)))
        readonly property int decadeGap: Math.max(3, Math.round(cell * 0.6))
        readonly property int dot: Math.max(2, cell - Math.max(2, Math.round(cell * 0.35)))
        readonly property color livedColor: Util.alpha(Commons.Color.lock.text, 0.9)
        readonly property color futureColor: Util.alpha(Commons.Color.lock.text, 0.22)

        anchors.top: lifeHeader.bottom
        anchors.topMargin: gap
        anchors.right: parent.right
        width: 52 * cell
        height: root.lifeYears * cell + (decades - 1) * decadeGap

        function rowY(row) {
          return row * cell + Math.floor(row / 10) * decadeGap
        }

        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var lived = root.livedWeeks
          var shownLived = Math.floor(lived * revealed)
          for (var row = 0; row < root.lifeYears; row++) {
            var y = rowY(row)
            for (var col = 0; col < 52; col++) {
              var week = row * 52 + col
              if (week === lived) continue
              // Lived weeks are solid; the ones still ahead are only outlines.
              if (week < shownLived) {
                ctx.fillStyle = livedColor
                ctx.fillRect(col * cell, y, dot, dot)
              } else {
                ctx.strokeStyle = futureColor
                ctx.lineWidth = 1
                ctx.strokeRect(col * cell + 0.5, y + 0.5, dot - 1, dot - 1)
              }
            }
          }
        }

        onRevealedChanged: requestPaint()
        onCellChanged: requestPaint()
        onLivedColorChanged: requestPaint()
        onFutureColorChanged: requestPaint()
        Connections {
          target: root
          function onLivedWeeksChanged() { lifeGrid.requestPaint() }
          function onLifeYearsChanged() { lifeGrid.requestPaint() }
        }

        // This week: the only lit cell, breathing in the accent color.
        Rectangle {
          readonly property int row: Math.floor(root.livedWeeks / 52)
          readonly property int col: root.livedWeeks % 52
          x: col * lifeGrid.cell - (width - lifeGrid.dot) / 2
          y: lifeGrid.rowY(row) - (height - lifeGrid.dot) / 2
          width: lifeGrid.dot + 2
          height: width
          color: Commons.Color.accent
          opacity: lifeGrid.revealed

          Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: width
            color: "transparent"
            border.color: Commons.Color.accent
            border.width: 1
            SequentialAnimation on scale {
              running: root.animating && root.showLife
              loops: Animation.Infinite
              NumberAnimation { from: 1; to: 3.2; duration: 1600; easing.type: Easing.OutCubic }
              PauseAnimation { duration: 600 }
            }
            SequentialAnimation on opacity {
              running: root.animating && root.showLife
              loops: Animation.Infinite
              NumberAnimation { from: 0.9; to: 0; duration: 1600; easing.type: Easing.OutCubic }
              PauseAnimation { duration: 600 }
            }
          }
        }

        // Decade marks down the left edge: 10, 20, 30…
        Repeater {
          model: Math.max(0, lifeGrid.decades - 1)
          Text {
            required property int index
            textFormat: Text.PlainText
            x: -width - Math.round(Style.font.caption * 0.8)
            y: lifeGrid.rowY((index + 1) * 10) - lifeGrid.decadeGap / 2 - height / 2
            text: Commons.I18n.formatNumber((index + 1) * 10)
            color: Util.alpha(Commons.Color.lock.text, 0.4)
            font.family: root.uiFont
            font.pixelSize: Style.font.caption
          }
        }
      }

      Text {
        id: lifeFooter
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.top: lifeGrid.bottom
        anchors.topMargin: lifeGrid.gap
        text: strings.t("lock.lifeSpent", "%1% of %2 years")
          .arg(Commons.I18n.formatNumber(100 * root.livedWeeks / Math.max(1, root.totalWeeks), 1))
          .arg(Commons.I18n.formatNumber(root.lifeYears))
        color: Util.alpha(Commons.Color.lock.text, 0.55)
        font.family: root.uiFont
        font.pixelSize: Style.font.body
        font.letterSpacing: Style.font.body * 0.1
      }
    }
  }
}
