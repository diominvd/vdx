import QtQuick
import qs.config
import qs.kit

// Brightness: backlight and software dimming, then the night light with its
// colour temperature and presets.
KitFrame {
  id: root

  readonly property real temperatureSpan: BrightnessService.temperatureMax - BrightnessService.temperatureMin

  // three rows: narrower than the other popups
  implicitWidth: 300

  // ---- header ----
  KitHeader {
    icon: BrightnessService.nightActive ? "moon" : "sun"
    iconColor: BrightnessService.nightActive ? Theme.orange : Theme.foreground0
    title: "Brightness"
    subtitle: (BrightnessService.available ? "BRIGHTNESS " + BrightnessService.brightness + "%" : "NO BACKLIGHT")
      + (BrightnessService.nightActive ? " · NIGHT LIGHT" : "")
  }

  KitLine {}

  // ---- backlight / dimming ----
  Column {
    width: parent.width
    spacing: Theme.gapGroup

    KitSliderRow {
      visible: BrightnessService.available     // dimming and the night light work without one
      label: "BRIGHTNESS"
      value: BrightnessService.brightness / 100
      text: BrightnessService.brightness + "%"
      onMoved: value => BrightnessService.setBrightness(value * 100)
    }

    KitSliderRow {
      label: "DIMMING"
      value: (BrightnessService.gamma - BrightnessService.gammaMin) / (100 - BrightnessService.gammaMin)
      text: BrightnessService.gamma + "%"
      onMoved: value => BrightnessService.setGamma(BrightnessService.gammaMin + value * (100 - BrightnessService.gammaMin))
    }
  }

  KitLine {}

  // ---- night light ----
  Column {
    width: parent.width
    spacing: Theme.gapGroup

    KitRow {
      label: "Night light"
      hint: "Warmer colours for the evening"

      KitSwitch {
        accessibleName: "Night light"
        checked: BrightnessService.nightActive
        onToggled: BrightnessService.setNight(!BrightnessService.nightActive)
      }
    }

    KitSliderRow {
      visible: BrightnessService.nightActive
      label: "TEMPERATURE"
      value: (BrightnessService.temperature - BrightnessService.temperatureMin) / root.temperatureSpan
      text: BrightnessService.temperature + "K"
      tint: Theme.orange
      onMoved: value => BrightnessService.setTemperature(BrightnessService.temperatureMin + value * root.temperatureSpan)
    }

    KitChoices {
      width: parent.width
      stretch: true
      visible: BrightnessService.nightActive && BrightnessService.presets.length > 0
      model: BrightnessService.presets.map(p => ({ label: p.label, value: p.temperature }))
      current: BrightnessService.temperature
      onPicked: value => BrightnessService.setTemperature(value)
    }
  }
}
