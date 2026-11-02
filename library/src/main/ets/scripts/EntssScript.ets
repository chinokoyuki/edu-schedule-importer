/**
 * Injected into the page through `WebviewController.runJavaScript`.
 *
 * Entss (乘方) timetable pages render the grid from an API, so reading the DOM
 * gives nothing useful. This asks the same two endpoints the page asks:
 * the timetable rows for the term, and the dates of week 1.
 *
 * Both requests are synchronous on purpose. ArkWeb starts returning the
 * pending promise before the page finishes its own request, and the caller
 * would have to poll; a synchronous XHR is the shorter path here.
 */
export const ENTSS_SCRIPT: string = `(function () {
  function findDoc(win) {
    try {
      if (win.document && win.document.querySelector('#xnxqdm')) {
        return win.document;
      }
    } catch (e) {}
    try {
      for (var i = 0; i < win.frames.length; i++) {
        var found = findDoc(win.frames[i]);
        if (found) { return found; }
      }
    } catch (e) {}
    return null;
  }

  function field(doc, id) {
    var el = doc.querySelector('#' + id);
    return el && el.value ? String(el.value) : '';
  }

  function post(url, body) {
    try {
      var xhr = new XMLHttpRequest();
      xhr.open('POST', url, false);
      xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded;charset=UTF-8');
      xhr.send(body);
      return xhr.responseText || '';
    } catch (e) {
      return '';
    }
  }

  // Some backends put raw newlines inside string values, which JSON.parse
  // rejects. Escape them and try once more before giving up.
  function parse(text) {
    if (!text) { return null; }
    try { return JSON.parse(text); } catch (e) {}
    try { return JSON.parse(text.replace(/\\r?\\n/g, '\\\\n').replace(/\\t/g, '\\\\t')); } catch (e) {}
    return null;
  }

  var doc = findDoc(window);
  if (!doc) { return JSON.stringify({ error: 'no_schedule_page' }); }

  var sem = field(doc, 'xnxqdm');
  if (!sem) {
    var select = doc.querySelector('#xnxqdm');
    if (select && select.options && select.options.length > 0) {
      sem = select.options[select.options.length > 1 ? 1 : 0].value;
    }
  }
  if (!sem) { return JSON.stringify({ error: 'no_semester' }); }

  var year = parseInt(sem.substring(0, 4), 10);
  var term = (sem.substring(4) === '2' || sem.substring(4) === '02') ? 2 : 1;
  var from = term === 1 ? year + '-08-01 00:00:00' : (year + 1) + '-02-01 00:00:00';
  var to = term === 1 ? (year + 1) + '-03-01 00:00:00' : (year + 1) + '-08-01 00:00:00';

  var body = 'szxqdm=' + encodeURIComponent(field(doc, 'szxqdm')) +
    '&xnxqdm=' + encodeURIComponent(sem) +
    '&yxdm=' + encodeURIComponent(field(doc, 'yxdm')) +
    '&zc=&d1=' + encodeURIComponent(from) +
    '&d2=' + encodeURIComponent(to);

  var table = parse(post('/new/student/xsgrkb/getCalendarWeekDatas', body));
  if (!table) { return JSON.stringify({ error: 'request_failed' }); }
  if (table.code !== undefined && table.code < 0) {
    return JSON.stringify({ error: 'request_failed' });
  }

  var week = '';
  var dates = parse(post('/new/xlxx/getDatesOfWeek', 'xnxqdm=' + encodeURIComponent(sem) + '&zc=1'));
  if (dates && dates.length) {
    for (var i = 0; i < dates.length; i++) {
      if (String(dates[i].xqmc) === '1' && dates[i].rq) {
        week = String(dates[i].rq);
        break;
      }
    }
  }

  return JSON.stringify({
    system: 'entss',
    sem: sem,
    week1: week,
    records: table.data || []
  });
})()`
