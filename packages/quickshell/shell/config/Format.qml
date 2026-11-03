pragma Singleton
import QtQuick
import Quickshell

// Numbers and names as text, shared by every module.
Singleton {
  // Bytes per second, human-readable.
  function humanRate(bytes) {
    if (bytes < 1024) return Math.round(bytes) + " B/s";
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB/s";
    if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB/s";
    return (bytes / 1073741824).toFixed(2) + " GB/s";
  }

  // A count with its noun: count(1, "DEVICE") is "1 DEVICE", count(3, "DEVICE") "3 DEVICES"
  // (an "s" in the noun's case); `many` for an irregular one: count(2, "PROCESS", "PROCESSES").
  function count(n, one, many) {
    if (n === 1) return n + " " + one;
    return n + " " + (many ?? one + (one === one.toUpperCase() ? "S" : "s"));
  }

  // Large counts: 812, 47.1k, 176.9M.
  function humanCount(n) {
    if (n < 1000) return String(Math.round(n));
    if (n < 1e6) return (n / 1e3).toFixed(1) + "k";
    if (n < 1e9) return (n / 1e6).toFixed(1) + "M";
    return (n / 1e9).toFixed(2) + "B";
  }

  // Sizes in lists, compact: 312 KB, 48 MB, 1.4 GB.
  function shortSize(bytes) {
    if (bytes < 1048576) return Math.round(bytes / 1024) + " KB";
    if (bytes < 1073741824) return Math.round(bytes / 1048576) + " MB";
    return (bytes / 1073741824).toFixed(1) + " GB";
  }

  // Cumulative byte counters, human-readable.
  function humanSize(bytes) {
    if (bytes < 1024) return Math.round(bytes) + " B";
    if (bytes < 1048576) return (bytes / 1024).toFixed(1) + " KB";
    if (bytes < 1073741824) return (bytes / 1048576).toFixed(1) + " MB";
    if (bytes < 1099511627776) return (bytes / 1073741824).toFixed(2) + " GB";
    return (bytes / 1099511627776).toFixed(2) + " TB";
  }

  // A keyboard layout's short name: "English (US)" -> US; "" when unknown.
  function layout(name) {
    const n = name.toLowerCase();
    if (n.includes("english")) return "US";
    if (n.includes("russian")) return "RU";
    return "";
  }
}
