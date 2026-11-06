import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The Sumi lock: the wallpaper under an even ink wash, the date and time set
// quietly in the middle, and a hairline password field near the foot. Inter
// throughout, the ink scale for hierarchy, and shu red only when something is
// wrong: the same rules as the bar and the control center.
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
  readonly property bool animating: root.loadBackground && !root.displaysBlank

  // --- Sumi tokens, for this surface ----------------------------------------
  readonly property string uiFont: "Inter"
  readonly property color ink: Commons.Color.lock.text
  readonly property color ink2: Util.alpha(ink, 0.64)
  readonly property color ink3: Util.alpha(ink, 0.56)
  readonly property color signal: Commons.Color.lock.textError
  readonly property real rTile: 12

  // Proportions follow the screen, so the composition holds from a laptop
  // panel to a 4K monitor.
  readonly property int timeSize: Math.round(Math.min(height * 0.14, width * 0.1))
  readonly property int dateSize: Math.max(15, Math.round(timeSize * 0.13))
  readonly property int fieldText: 14
  readonly property int fieldWidth: Math.round(Math.max(260, Math.min(300, width * 0.2)))
  readonly property int fieldHeight: 40
  readonly property int passwordDotFontSize: 10
  readonly property int passwordDotLetterSpacing: 3
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible; otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool errorState: failureMessage.length > 0
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && !errorState
  // The field's hairline: faint at rest, firmer while typing, shu red on a
  // wrong password.
  readonly property color fieldLine: errorState
    ? Util.alpha(signal, 0.7)
    : Util.alpha(ink, passwordInput.text.length > 0 || authenticatingPassword ? 0.22 : 0.12)

  readonly property bool video: Util.isVideoPath(root.backgroundPath)
  readonly property bool feedActive: root.video && root.loadBackground && !root.displaysBlank && !root.powerSaverActive

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

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
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

  // Gentle in: the wallpaper settles, the type fades up a few pixels.
  ParallelAnimation {
    id: intro
    NumberAnimation { target: wallpaper; property: "scale"; from: 1.03; to: 1.0; duration: 1200; easing.type: Easing.OutCubic }
    NumberAnimation { target: timeBlock; property: "opacity"; from: 0; to: 1; duration: 700; easing.type: Easing.OutCubic }
    NumberAnimation { target: timeShift; property: "y"; from: 10; to: 0; duration: 800; easing.type: Easing.OutCubic }
    SequentialAnimation {
      PauseAnimation { duration: 120 }
      NumberAnimation { target: entry; property: "opacity"; from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }
    }
  }

  // A wrong password: a short, damped shake of the field.
  SequentialAnimation {
    id: shake
    NumberAnimation { target: entryShift; property: "x"; to: -9; duration: 50; easing.type: Easing.OutQuad }
    NumberAnimation { target: entryShift; property: "x"; to: 7; duration: 70; easing.type: Easing.InOutQuad }
    NumberAnimation { target: entryShift; property: "x"; to: -4; duration: 70; easing.type: Easing.InOutQuad }
    NumberAnimation { target: entryShift; property: "x"; to: 0; duration: 60; easing.type: Easing.OutQuad }
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

      // Soft and a little muted, so any wallpaper reads as a ground for the
      // type rather than a picture behind it. A still only: a video plays
      // sharp above it, as blurring every frame costs the GPU.
      layer.enabled: root.loadBackground
      layer.smooth: true
      layer.effect: MultiEffect {
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 48
        blur: 0.8
        saturation: -0.25
      }
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

    // One even ink wash, so any wallpaper reads as a quiet ground, and a
    // little more at the foot, under the field.
    Rectangle {
      anchors.fill: parent
      color: Util.alpha(Commons.Color.background, 0.5)
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: parent.height * 0.4
      gradient: Gradient {
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 1.0; color: Util.alpha(Commons.Color.background, 0.35) }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    // --- The date and time ---------------------------------------------------
    Column {
      id: timeBlock
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -Math.round(parent.height * 0.1)
      spacing: Math.round(root.timeSize * 0.02)
      transform: Translate { id: timeShift }

      // Quiet, as on the bar: the date in the second ink.
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: Qt.locale(Commons.I18n.formatLocale).toString(clock.date, "dddd d MMMM")
        color: root.ink2
        font.family: root.uiFont
        font.pixelSize: root.dateSize
        font.weight: Font.Medium
        font.letterSpacing: root.dateSize * 0.01
      }

      // The time: light and tightly set. Proportional figures, as Inter's
      // tabular one wears a foot serif that reads as a terminal; centred, the
      // width changing by the minute doesn't show.
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: Qt.locale(Commons.I18n.formatLocale).toString(clock.date, "HH:mm")
        color: root.ink
        font.family: root.uiFont
        font.pixelSize: root.timeSize
        font.weight: Font.Light
        font.letterSpacing: -root.timeSize * 0.03
        // The line box is far taller than the numerals at this size; pull it
        // in so the date sits close above them.
        height: Math.round(root.timeSize * 1.05)
        verticalAlignment: Text.AlignVCenter
      }
    }

    // --- Who, and the password ---------------------------------------------
    Column {
      id: entry
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Math.round(parent.height * 0.13)
      spacing: 12
      transform: Translate { id: entryShift }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        visible: root.userName.length > 0
        text: root.userName
        color: root.ink2
        font.family: root.uiFont
        font.pixelSize: 13
        font.weight: Font.Medium
      }

      Rectangle {
        id: field
        width: root.fieldWidth
        height: root.fieldHeight
        radius: root.rTile
        color: Util.alpha(root.ink, 0.06)
        border.width: 1
        border.color: root.fieldLine
        Behavior on border.color { ColorAnimation { duration: 200 } }

        TextInput {
          id: passwordInput
          anchors.left: parent.left
          anchors.leftMargin: 14
          anchors.right: fingerprintIcon.visible ? fingerprintIcon.left : parent.right
          anchors.rightMargin: fingerprintIcon.visible ? 8 : 14
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
          color: root.ink
          selectionColor: Commons.Color.lock.selection
          selectedTextColor: root.ink
          font.family: root.uiFont
          font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldText
          font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
          cursorVisible: activeFocus && root.showPasswordCursor
          // A thin caret in the first ink, blinking softly.
          cursorDelegate: Rectangle {
            width: 1.5
            color: root.ink
            visible: passwordInput.cursorVisible
            opacity: blink.on ? 0.9 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
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
          interval: 560
          repeat: true
          running: root.animating && passwordInput.cursorVisible
          onRunningChanged: on = true
          onTriggered: on = !on
        }

        // Placeholder, "Checking…" while PAM works, or what went wrong.
        Text {
          textFormat: Text.PlainText
          anchors.fill: passwordInput
          // Clear of the caret at the start of an empty field.
          leftPadding: passwordInput.cursorVisible ? 6 : 0
          text: root.authenticatingPassword ? Commons.I18n.t("lock.checking") : (root.errorState ? root.failureMessage : root.placeholderText)
          visible: passwordInput.text.length === 0
          color: root.errorState && !root.authenticatingPassword ? root.signal : root.ink3
          font.family: root.uiFont
          font.pixelSize: root.fieldText
          horizontalAlignment: Text.AlignLeft
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }

        // Fingerprint hint at the end of the field when a sensor is enrolled,
        // so the user knows they can touch to unlock instead of typing. A
        // reader the shell cannot reach crosses out rather than disappears,
        // so it stops inviting touches that can never unlock.
        Text {
          id: fingerprintIcon
          objectName: "fingerprintIndicator"
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.rightMargin: 12
          anchors.verticalCenter: parent.verticalCenter
          visible: root.fingerprintConfigured
          text: root.fingerprintUnavailable ? "󰺱" : "󰈷"
          color: root.fingerprintUnavailable ? root.signal : root.ink3
          font.family: root.uiFont
          font.pixelSize: 16
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }

      // The crossed-out icon means nothing to someone who has never seen it,
      // so the words carry the explanation and the icon only reinforces it.
      Text {
        objectName: "fingerprintUnavailableNotice"
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        visible: root.fingerprintConfigured && root.fingerprintUnavailable
        text: Commons.I18n.t("lock.fingerprintUnavailable")
        color: root.signal
        font.family: root.uiFont
        font.pixelSize: 12
      }
    }
  }
}
