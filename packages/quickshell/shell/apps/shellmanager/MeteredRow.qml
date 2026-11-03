import QtQuick
import qs.kit

// Whether a saved connection (Wi-Fi, Ethernet) counts as metered: Auto lets
// NetworkManager guess. `connection`: its saved entry ({uuid, metered}); `service`: the
// network service that saves it (setSaved, savedBusy).
KitRow {
  id: root

  property var connection: null
  property var service: null

  visible: connection !== null
  wide: true
  label: "Metered"
  hint: "Yes: apps save data"

  KitSegments {
    disabled: root.service?.savedBusy ?? true
    model: [{ label: "Auto", value: "unknown" }, { label: "Yes", value: "yes" }, { label: "No", value: "no" }]
    current: root.connection?.metered ?? "unknown"
    onPicked: value => root.service.setSaved(root.connection.uuid, "metered", value)
  }
}
