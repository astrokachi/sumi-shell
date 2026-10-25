import QtQuick

// An icon named the way the panels first named them (Material Symbols
// ligatures), drawn from the Sumi set.
Item {
  id: root

  property string text: ""
  property real size: 18
  property color color: "white"

  readonly property var names: ({
    "search": "search", "nightlight": "moon", "do_not_disturb_on": "silent",
    "coffee": "coffee", "dock_to_bottom": "dock", "palette": "palette",
    "wallpaper": "image", "airwave": "monitor", "lock": "lock",
    "refresh": "refresh", "restart_alt": "restart", "power_settings_new": "power",
    "add": "plus", "remove": "minus", "check": "check", "apps": "grid",
    "drag_indicator": "drag", "arrow_back": "back", "arrow_forward": "chevron",
    "visibility_off": "hidden", "widgets": "widgets", "extension": "extension"
  })

  implicitWidth: size
  implicitHeight: size

  SumiIcon {
    anchors.centerIn: parent
    name: root.names[root.text] || root.text
    size: root.size
    color: root.color
  }
}
