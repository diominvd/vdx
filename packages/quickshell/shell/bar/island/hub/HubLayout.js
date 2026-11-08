.pragma library

// Pack an ordered list of rectangular widgets into the first available cells.
// The model stays independent of Qt items so both the live grid and its tests
// use the same placement rules.
function calculate(widgets, order, sizes, columns, formatOf, rowsOf) {
  const byId = {};
  for (const widget of widgets) byId[widget.id] = widget;

  const occupied = [];
  const taken = (row, col) => (occupied[row] ?? [])[col] === true;
  const fits = (row, col, width, height) => {
    for (let y = 0; y < height; y++)
      for (let x = 0; x < width; x++)
        if (taken(row + y, col + x)) return false;
    return true;
  };

  const places = {};
  for (const id of order) {
    const widget = byId[id];
    if (!widget) continue;
    const size = sizes[formatOf(widget)];
    if (!size) continue;
    const width = Math.max(1, Math.min(columns, size[0])), height = Math.max(1, rowsOf(widget));
    // Editor controls occupy a new row so they cannot stretch the last widget row.
    let r = widget.tail ? occupied.length : 0, c = 0;
    while (c + width > columns || !fits(r, c, width, height)) {
      c++;
      if (c + width > columns) { r++; c = 0; }
    }
    for (let y = 0; y < height; y++) {
      occupied[r + y] = occupied[r + y] ?? [];
      for (let x = 0; x < width; x++) occupied[r + y][c + x] = true;
    }
    places[id] = { col: c, row: r, cols: width, rows: height };
  }

  const rowCount = widgets.reduce((max, widget) =>
    Math.max(max, (places[widget.id]?.row ?? 0) + (places[widget.id]?.rows ?? 0)), 0);
  return { places: places, rowCount: rowCount };
}

// Content sets the row heights. Single-row controls keep their natural size;
// spanning cards distribute only the height they still need across their rows.
function geometry(layout, width, columns, gap, heightOf) {
  if (width <= 0 || columns < 1 || layout.rowCount === 0) return {rects: {}, height: 0};
  const heights = Array(layout.rowCount).fill(0);
  const ids = Object.keys(layout.places).sort((a, b) => {
    const p = layout.places[a], q = layout.places[b];
    return p.rows - q.rows || p.row - q.row || p.col - q.col;
  });
  for (const id of ids) {
    const p = layout.places[id];
    const need = Math.max(1, heightOf(id));
    let have = (p.rows - 1) * gap;
    for (let r = p.row; r < p.row + p.rows; r++) have += heights[r];
    if (need > have) for (let r = p.row; r < p.row + p.rows; r++) heights[r] += (need - have) / p.rows;
  }
  const offsets = [0];
  for (const h of heights) offsets.push(offsets[offsets.length - 1] + h + gap);
  const cell = (width - (columns - 1) * gap) / columns;
  const rects = {};
  for (const id of ids) {
    const p = layout.places[id];
    rects[id] = { x: p.col * (cell + gap), y: offsets[p.row], w: p.cols * cell + (p.cols - 1) * gap,
      h: offsets[p.row + p.rows] - offsets[p.row] - gap };
  }
  // A homogeneous row shares its spare width. Spans describe the preferred
  // proportions; a pair of tiles need not leave an unused strip at the edge.
  const starts = {};
  for (const id of ids) {
    const row = layout.places[id].row;
    starts[row] = (starts[row] ?? []).concat([id]);
  }
  for (const key of Object.keys(starts)) {
    const peers = starts[key], first = layout.places[peers[0]];
    if (peers.length < 2 || peers.some(id => layout.places[id].cols === 1 && layout.places[id].rows === 1)
      || peers.some(id => layout.places[id].rows !== first.rows)) continue;
    const crossing = ids.some(id => !peers.includes(id) && layout.places[id].row < first.row + first.rows
      && layout.places[id].row + layout.places[id].rows > first.row);
    if (crossing) continue;
    const total = peers.reduce((sum, id) => sum + layout.places[id].cols, 0);
    if (total >= columns) continue;
    const available = width - (peers.length - 1) * gap;
    let x = 0;
    for (const id of peers) {
      const r = rects[id];
      r.x = x; r.w = available * layout.places[id].cols / total;
      x += r.w + gap;
    }
  }
  return { rects: rects, height: Math.max(0, offsets[offsets.length - 1] - gap) };
}
