/**
 * Injected into the page through `WebviewController.runJavaScript`.
 *
 * Expands rowspan/colspan so the table becomes a plain grid, then returns every
 * table found in the document and in same-origin frames. The ArkTS side decides
 * which table is the timetable.
 */
export const GENERIC_TABLE_SCRIPT: string = `(function () {
  var tables = [];

  function expand(table) {
    var grid = [];
    var occupied = {};
    var rows = table.rows;
    for (var r = 0; r < rows.length; r++) {
      var cells = rows[r].cells;
      var column = 0;
      for (var c = 0; c < cells.length; c++) {
        while (occupied[r + ',' + column]) { column++; }
        var cell = cells[c];
        var rowspan = cell.rowSpan || 1;
        var colspan = cell.colSpan || 1;
        for (var dr = 0; dr < rowspan; dr++) {
          for (var dc = 0; dc < colspan; dc++) {
            occupied[(r + dr) + ',' + (column + dc)] = 1;
          }
        }
        if (!grid[r]) { grid[r] = []; }
        while (grid[r].length < column) { grid[r].push(''); }
        grid[r][column] = (cell.innerText || '')
          .replace(/[\\u0000-\\u001f\\u2028\\u2029]/g, ' ')
          .trim();
        column += colspan;
      }
    }
    var compact = [];
    for (var i = 0; i < grid.length; i++) {
      if (grid[i]) { compact.push(grid[i]); }
    }
    return compact;
  }

  function collect(doc) {
    try {
      var found = doc.querySelectorAll('table');
      for (var i = 0; i < found.length; i++) {
        var grid = expand(found[i]);
        if (grid.length > 0) { tables.push(grid); }
      }
    } catch (e) {}
  }

  collect(document);
  try {
    for (var f = 0; f < window.frames.length; f++) {
      collect(window.frames[f].document);
    }
  } catch (e) {}

  return JSON.stringify({ url: location.href, tables: tables });
})()`
