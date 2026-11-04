import QtQuick
import qs.config
import qs.kit

// Package manager options in the Shell Manager (ModuleSettings "packages"):
// what opens and what is listed. Checking for updates, installing them (without
// asking, the notification when done) and the removal safety are the Updates page.
// The bar module's own rows are PackagesBarSettings (Bar modules › Packages).
Column {
  spacing: Theme.sectionGap

  KitLabel { text: "OPENING" }

  KitOptionRow {
    module: "packages"; key: "startTab"; fallback: "updates"
    label: "Opens on"; hint: "The tab shown first"
    model: [{ label: "Updates", value: "updates" }, { label: "Installed", value: "installed" }, { label: "Cache", value: "cache" }]
  }

  KitLine {}

  KitLabel { text: "LIST" }

  KitOptionRow {
    module: "packages"; key: "sortBy"; fallback: "name"
    label: "Sort installed by"; hint: "Name, size, or newest first"
    model: [{ label: "Name", value: "name" }, { label: "Size", value: "size" }, { label: "Newest", value: "date" }]
  }

  KitOptionRow {
    module: "packages"; key: "cacheView"; fallback: "old"
    label: "Cache shows"; hint: "Old versions, or all cached"
    model: [{ label: "Old", value: "old" }, { label: "All", value: "all" }]
  }

  KitGrouper {}
}
