/**
 * Injected into the page through `WebviewController.runJavaScript`.
 *
 * Reads a Qiangzhi (强智) timetable. The page usually renders the table with
 * `.kbcontent` cells and `font[title]` hints for teacher, weeks and room.
 * When the current document has no timetable, the script fetches the timetable
 * page again with the session cookies the browser already holds, then parses
 * the response.
 */
export const QIANGZHI_SCRIPT: string = `(function () {
  var WEEKDAYS = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日', '周日'];

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
        while (grid[r].length < column) { grid[r].push(null); }
        grid[r][column] = cell;
        column += colspan;
      }
    }
    return grid;
  }

  function findHeader(grid) {
    for (var r = 0; r < grid.length; r++) {
      var row = grid[r];
      if (!row) { continue; }
      var columns = {};
      var count = 0;
      for (var c = 0; c < row.length; c++) {
        var cell = row[c];
        if (!cell) { continue; }
        var text = (cell.textContent || '').trim();
        for (var d = 0; d < WEEKDAYS.length; d++) {
          if (text.indexOf(WEEKDAYS[d]) >= 0) {
            columns[c] = d < 7 ? d + 1 : 7;
            count++;
            break;
          }
        }
      }
      if (count >= 3) { return { row: r, columns: columns }; }
    }
    return null;
  }

  function readCell(cell) {
    var items = [];
    var blocks = cell.querySelectorAll('.kbcontent');
    for (var i = 0; i < blocks.length; i++) {
      var block = blocks[i];
      var fonts = block.querySelectorAll('font');
      var teacher = '';
      var weeks = '';
      var room = '';
      for (var f = 0; f < fonts.length; f++) {
        var title = fonts[f].getAttribute('title') || '';
        var text = (fonts[f].textContent || '').trim();
        if (title.indexOf('老师') >= 0) { teacher = text; }
        else if (title.indexOf('周次') >= 0) { weeks = text; }
        else if (title.indexOf('教室') >= 0) { room = text; }
      }
      var clone = block.cloneNode(true);
      var cloned = clone.querySelectorAll('font');
      for (var k = cloned.length - 1; k >= 0; k--) {
        cloned[k].parentNode.removeChild(cloned[k]);
      }
      var name = (clone.textContent || '')
        .replace(/[\\u0000-\\u001f\\u2028\\u2029]+/g, '|')
        .split('|')
        .map(function (part) { return part.trim(); })
        .filter(function (part) { return part.length > 0; })
        .join('');
      if (!name || name.indexOf('无课') >= 0) { continue; }
      items.push({ n: name, t: teacher, w: weeks, r: room });
    }
    return items;
  }

  function extract(doc) {
    var tables = doc.querySelectorAll('table');
    var best = null;
    var bestCount = 0;
    for (var i = 0; i < tables.length; i++) {
      var count = tables[i].querySelectorAll('.kbcontent').length;
      if (count > bestCount) { best = tables[i]; bestCount = count; }
    }
    if (!best || bestCount === 0) { return null; }

    var grid = expand(best);
    var header = findHeader(grid);
    if (!header) { return null; }

    var cells = [];
    for (var r = header.row + 1; r < grid.length; r++) {
      var row = grid[r];
      if (!row) { continue; }
      for (var key in header.columns) {
        var column = parseInt(key, 10);
        var day = header.columns[key];
        var cell = row[column];
        if (!cell) { continue; }
        var items = readCell(cell);
        for (var m = 0; m < items.length; m++) {
          cells.push({ d: day, n: items[m].n, t: items[m].t, w: items[m].w, r: items[m].r });
        }
      }
    }
    return cells.length > 0 ? cells : null;
  }

  var html = '';
  var cells = null;
  try { cells = extract(document); } catch (e) {}

  if (!cells) {
    var urls = [
      '/jsxsd/xskb/xskb_list.do?Ves632DSdyV=NEW_XSD_PYGL',
      '/jsxsd/kbcx/xskb_list.do?Ves632DSdyV=NEW_XSD_PYGL'
    ];
    for (var u = 0; u < urls.length && !cells; u++) {
      try {
        var xhr = new XMLHttpRequest();
        xhr.open('GET', urls[u], false);
        xhr.send();
        var response = xhr.responseText;
        if (response && response.indexOf('kbcontent') >= 0) {
          html = response;
          var holder = document.createElement('div');
          holder.style.display = 'none';
          holder.innerHTML = response;
          document.body.appendChild(holder);
          try { cells = extract(holder); } catch (e) {}
          holder.parentNode.removeChild(holder);
        }
      } catch (e) {}
    }
  }

  var pageHtml = html || document.documentElement.innerHTML;
  var semester = '';
  var term = pageHtml.match(/20\\d\\d-20\\d\\d-[12]/);
  if (term) { semester = term[0]; }

  if (!cells) {
    return JSON.stringify({ error: 'no_schedule_page' });
  }
  return JSON.stringify({ system: 'qiangzhi', sem: semester, cells: cells });
})()`
