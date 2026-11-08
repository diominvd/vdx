import QtQuick
import QtTest
import "qs/kit/HubLayout.js" as HubLayout

TestCase {
  name: "HubLayout"

  readonly property var sizes: ({ XS: [1, 1], S: [1, 2], M: [2, 2], Chip: [2, 1], Strip: [4, 1], Card: [4, 2], Panel: [4, 6] })

  function pack(widgets, order) {
    return HubLayout.calculate(widgets, order, sizes, 4,
      widget => widget.fmt, widget => widget.rows ?? sizes[widget.fmt][1]);
  }

  function test_ordered_formats_pack_without_open_cells() {
    const widgets = [
      { id: "a", fmt: "M" }, { id: "b", fmt: "Chip" }, { id: "c", fmt: "S" },
      { id: "d", fmt: "XS" }, { id: "e", fmt: "Card" },
    ];
    const result = pack(widgets, ["a", "b", "c", "d", "e"]);
    compare(result.places, {
      a: { col: 0, row: 0, cols: 2, rows: 2 },
      b: { col: 2, row: 0, cols: 2, rows: 1 },
      c: { col: 2, row: 1, cols: 1, rows: 2 },
      d: { col: 3, row: 1, cols: 1, rows: 1 },
      e: { col: 0, row: 3, cols: 4, rows: 2 },
    });
    compare(result.rowCount, 5);
  }

  function test_reordering_and_content_height_repack_following_widgets() {
    const widgets = [
      { id: "week", fmt: "Card", rows: 3 },
      { id: "player", fmt: "Strip" },
      { id: "volume", fmt: "Chip" },
    ];
    const result = pack(widgets, ["week", "player", "volume"]);
    compare(result.places.player.row, 3);
    compare(result.places.volume.col, 0);
    compare(result.places.volume.row, 4);
    compare(result.places.volume.cols, 2);
    compare(result.places.volume.rows, 1);
    const moved = pack(widgets, ["volume", "week", "player"]);
    compare(moved.places.volume.col, 0);
    compare(moved.places.volume.row, 0);
    compare(moved.places.week.row, 1);
  }

  function test_narrow_hub_clamps_wide_formats() {
    const widgets = [{id: "wide", fmt: "Card"}, {id: "small", fmt: "XS"}];
    const packed = HubLayout.calculate(widgets, ["wide", "small"], sizes, 2, w => w.fmt, w => sizes[w.fmt][1]);
    compare(packed.places.wide.cols, 2);
    compare(packed.places.small.row, 2);
  }

  function test_content_heights_fit_spanning_cards_without_overlap() {
    const layout = {rowCount: 2, places: {
      machine: {col: 0, row: 0, cols: 2, rows: 2},
      volume: {col: 2, row: 0, cols: 2, rows: 1},
      brightness: {col: 2, row: 1, cols: 2, rows: 1}
    }};
    const needs = {machine: 140, volume: 40, brightness: 60};
    const result = HubLayout.geometry(layout, 400, 4, 10, id => needs[id]);
    for (const id of Object.keys(needs)) verify(result.rects[id].h >= needs[id]);
    compare(result.rects.brightness.y - result.rects.volume.y - result.rects.volume.h, 10);
    compare(result.rects.machine.h, result.height);
    verify(result.rects.volume.x >= result.rects.machine.x + result.rects.machine.w + 10);
  }

  function test_homogeneous_row_shares_width_and_keeps_gap() {
    const layout = {rowCount: 2, places: {
      bluetooth: {col: 0, row: 0, cols: 2, rows: 2},
      vpn: {col: 2, row: 0, cols: 2, rows: 2}
    }};
    const result = HubLayout.geometry(layout, 500, 6, 10, () => 76);
    compare(result.rects.bluetooth.w, 245);
    compare(result.rects.vpn.x, 255);
    compare(result.rects.vpn.x + result.rects.vpn.w, 500);
  }

  function test_empty_grid_has_no_height() {
    const result = HubLayout.geometry({rowCount: 0, places: {}}, 400, 4, 10, () => 40);
    compare(result.height, 0);
    compare(Object.keys(result.rects).length, 0);
  }

  function test_later_small_widgets_fill_available_holes() {
    const widgets = [
      {id: "ring", fmt: "XS"}, {id: "player", fmt: "Card"},
      {id: "chip", fmt: "Chip"}, {id: "add", fmt: "XS", tail: true}
    ];
    const result = pack(widgets, widgets.map(w => w.id));
    compare(result.places.chip.row, 0);
    compare(result.places.chip.col, 1);
    verify(result.places.add.row >= result.places.player.row);
  }

  function test_row_order_uses_columns_not_object_insertion_order() {
    const layout = {rowCount: 2, places: {
      vpn: {col: 2, row: 0, cols: 2, rows: 2},
      bluetooth: {col: 0, row: 0, cols: 2, rows: 2}
    }};
    const result = HubLayout.geometry(layout, 500, 6, 10, () => 76);
    compare(result.rects.bluetooth.x, 0);
    compare(result.rects.vpn.x, 255);
  }
}
