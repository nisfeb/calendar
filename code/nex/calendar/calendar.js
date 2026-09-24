// calendar client: three projections (month / week / day) of one
// window.json contract, all display projected into the calendar's
// configured zone (UTC until one is set, the zone new events get).

var API = '/grubbery/api';
var CAL = '/apps/calendar';
var CFG = { zone: '', ball: '', title: 'Calendar' };

var WD = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
var WDS = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
var MN = ['January','February','March','April','May','June','July',
          'August','September','October','November','December'];
var MS_DAY = 864e5;

var state = { view: 'month', y: 0, m: 0, d: 0 };
var zfmt = null;
var nowTimer = null;

// ---- zone projection ----------------------------------------------

function mkfmt() { zfmt = zoneFmt(CFG.zone || 'UTC'); }

// one formatter per zone; an unknown zone falls back to UTC
var FMTS = {};
function zoneFmt(zone) {
  if (!FMTS[zone]) {
    var opts = { year: 'numeric', month: '2-digit', day: '2-digit',
                 hour: '2-digit', minute: '2-digit', hourCycle: 'h23' };
    try { FMTS[zone] = new Intl.DateTimeFormat('en-CA', Object.assign({ timeZone: zone }, opts)); }
    catch (e) { FMTS[zone] = new Intl.DateTimeFormat('en-CA', Object.assign({ timeZone: 'UTC' }, opts)); }
  }
  return FMTS[zone];
}

function parts(ms, fmt) {
  var p = {};
  (fmt || zfmt).formatToParts(ms).forEach(function(x) { p[x.type] = x.value; });
  return { y: +p.year, m: +p.month, d: +p.day,
           hh: +p.hour % 24, mm: +p.minute,
           ths: p.hour, tms: p.minute };
}

function serial(y, m, d) { return Date.UTC(y, m - 1, d) / MS_DAY; }
function unserial(s) {
  var dt = new Date(s * MS_DAY);
  return { y: dt.getUTCFullYear(), m: dt.getUTCMonth() + 1, d: dt.getUTCDate() };
}
function pserial(p) { return serial(p.y, p.m, p.d); }

// storage can be blocked; the clock format is only a convenience
var H12 = false;
try { H12 = localStorage.getItem('cal-h12') === '1'; } catch (e) {}
function fmtTime(p) {
  if (!H12) return p.ths + ':' + p.tms;
  var h = p.hh % 12 || 12;
  return h + ':' + p.tms + (p.hh < 12 ? 'a' : 'p');
}
function fmtTimeLong(p) {
  if (!H12) return p.ths + ':' + p.tms;
  var h = p.hh % 12 || 12;
  return h + ':' + p.tms + (p.hh < 12 ? ' AM' : ' PM');
}
function fmtHour(h) {
  if (!H12) return ('0' + h).slice(-2) + ':00';
  return (h % 12 || 12) + (h < 12 ? ' AM' : ' PM');
}
function fmtDate(p) {
  var dow = (new Date(pserial(p) * MS_DAY).getUTCDay() + 6) % 7;
  return WDS[dow] + ', ' + MN[p.m - 1].slice(0, 3) + ' ' + p.d;
}

// ISO 8601 week number: the week of its Thursday, weeks start Monday
function isoWeek(ser) {
  var dow = (new Date(ser * MS_DAY).getUTCDay() + 6) % 7;
  var thu = ser - dow + 3;
  var y = new Date(thu * MS_DAY).getUTCFullYear();
  var jan1 = Date.UTC(y, 0, 1) / MS_DAY;
  return Math.floor((thu - jan1) / 7) + 1;
}

// ---- data ---------------------------------------------------------

// per-event computation walls: [{id, name, stop}] where an event's
// occurrence walk was capped short of the requested range
var CAPS = [];
// the calendars, from calendars.json: id -> {name, color, readonly}
var CALS = {};
function calColor(id) { var c = CALS[id]; return (c && c.color) || ''; }
function calReadonly(id) { var c = CALS[id]; return !!(c && c.readonly); }
// a color from another ship or service goes into style: only a hex one
function safeColor(c) { return /^#[0-9a-f]{3,8}$/i.test(c || '') ? c : ''; }

// JSON from the ship; a refusal is an error, not an empty answer
function getJSON(path) {
  return fetch(CAL + path).then(function(r) {
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return r.json();
  });
}
function postJSON(path, body) {
  return fetch(CAL + path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body || {})
  });
}

function loadCals() {
  getJSON('/calendars.json')
    .then(function(list) {
      CALS = {};
      var sel = document.getElementById('f-cal'), tsel = document.getElementById('task-cal'), isel = document.getElementById('imp-cal');
      sel.innerHTML = ''; tsel.innerHTML = ''; isel.innerHTML = '';
      (list || []).forEach(function(c) {
        c.color = safeColor(c.color);
        CALS[c.id] = c;
        if (c.readonly) return;
        [sel, tsel, isel].forEach(function(el) {
          var o = document.createElement('option');
          o.value = c.id; o.textContent = c.name || c.id;
          el.appendChild(o);
        });
      });
      sel.value = 'default'; tsel.value = 'default'; isel.value = 'default';
    })
    .catch(function() {});
}

// a failed load says so in the header rather than drawing an empty
// calendar, which would look like every event was deleted
function loadFailed(e) {
  document.getElementById('load-err').textContent = 'Could not load (' + e.message + ')';
}

function fetchWindow(fromMs, toMs, cb) {
  getJSON('/window.json?from=' + fromMs + '&to=' + toMs + (state.tag ? '&tag=' + encodeURIComponent(state.tag) : ''))
    .then(function(res) {
      var rows = res.rows || [];
      CAPS = (res.caps || []).map(function(cp) {
        var m = cp.meta || {};
        return { id: cp.id, name: m.name || '', color: safeColor(m.color), stop: cp.stop };
      });
      // meta rides as an object; flatten the display keys onto the row
      rows.forEach(function(r) {
        var m = r.meta || {};
        r.name = m.name || '';
        r.note = m.note || '';
        r.color = safeColor(m.color) || calColor(r.cal) || '';
        r.tags = m.tags || [];
      });
      cb(rows);
    })
    .catch(function(e) { loadFailed(e); cb(null); });
}

function capsOn(ser) {
  return CAPS.filter(function(cp) {
    return pserial(msToUTC(cp.stop)) === ser;
  });
}

function capChip(cp) {
  var mk = document.createElement('div');
  mk.className = 'chip cap-chip';
  mk.textContent = '⇥ ' + cp.name + ' · computed to here';
  hoverTip(mk,
    '"' + cp.name + '" continues past this day, but only its first 10,000 ' +
    'occurrences have been computed — they end here. The series itself has no end.');
  return mk;
}

// fixed-position hover tooltip — unclippable by cell overflow
function hoverTip(el, text) {
  el.addEventListener('mouseenter', function() {
    var t = document.createElement('div');
    t.id = 'tipbox';
    t.textContent = text;
    document.body.appendChild(t);
    var r = el.getBoundingClientRect();
    t.style.left = Math.min(r.left, window.innerWidth - 260) + 'px';
    t.style.top = (r.top > 80 ? r.top - t.offsetHeight - 6 : r.bottom + 6) + 'px';
  });
  el.addEventListener('mouseleave', function() {
    var t = document.getElementById('tipbox');
    if (t) t.remove();
  });
}

function poke(body, cb) {
  fetch(API + '/poke/' + CFG.ball + '/calendar.calendar?blot=/json', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  }).then(function(r) { if (cb) cb(r.ok); },
          function() { if (cb) cb(false); });
}

// ---- layout helpers -----------------------------------------------

// a clickable element a keyboard can reach: focusable, a button to a
// screen reader, Enter and Space click it
function pressable(el, label) {
  el.tabIndex = 0;
  el.setAttribute('role', 'button');
  if (label) el.setAttribute('aria-label', label);
  el.addEventListener('keydown', function(e) {
    if (e.target !== el || (e.key !== 'Enter' && e.key !== ' ')) return;
    e.preventDefault();
    var r = el.getBoundingClientRect();
    el.dispatchEvent(new MouseEvent('click', { bubbles: true, clientX: r.left, clientY: r.bottom }));
  });
  return el;
}

// a button that stays off while its request is out, so a double click
// sends one
function busy(btn, promise) {
  btn.disabled = true;
  var done = function() { btn.disabled = false; };
  promise.then(done, done);
  return promise;
}

// a task's due moment as a day: a date (UTC midnight) is that date, a
// moment the day it falls on in the calendar's zone
function dueParts(ms) { return ms % MS_DAY === 0 ? msToUTC(ms) : parts(ms); }

function isAllDay(ev) { return ev.all || (ev.r - ev.l) >= MS_DAY; }
// all-day events live in date-space: UTC parts, no zone projection
function evParts(ev, ms) { return ev.all ? msToUTC(ms) : parts(ms); }

// overlap packing: greedy column assignment within collision clusters
function pack(items) {
  items.sort(function(a, b) { return a.s - b.s || b.e - a.e; });
  var cols = [], cluster = null, clusters = [], maxEnd = -1;
  items.forEach(function(it) {
    if (cluster === null || it.s >= maxEnd) {
      cluster = { items: [], n: 0 };
      clusters.push(cluster);
      cols = [];
      maxEnd = -1;
    }
    var c = 0;
    while (c < cols.length && cols[c] > it.s) c++;
    cols[c] = it.e;
    it.col = c;
    cluster.items.push(it);
    cluster.n = Math.max(cluster.n, cols.length);
    maxEnd = Math.max(maxEnd, it.e);
  });
  clusters.forEach(function(cl) {
    cl.items.forEach(function(it) { it.ncols = cl.n; });
  });
}

// ---- shared chrome ------------------------------------------------

var label = document.getElementById('month-label');
var pop = document.getElementById('pop');
var popTarget = null;

function showPop(ev, x, y) {
  popTarget = ev;
  document.getElementById('pop-name').textContent = ev.name;
  document.getElementById('pop-dot').style.background = ev.color || '#4a6a8a';
  var s = parts(ev.l), e = parts(ev.r);
  var sameDay = pserial(s) === pserial(e);
  var text;
  if (ev.cat === 'todo') {
    text = (ev.due_ms ? 'Due ' + fmtDate(dueParts(ev.due_ms)) : ev.l ? 'Due ' + fmtDate(msToUTC(ev.l)) : 'No due date') + (ev.done ? ' · done' : '');
  } else if (isAllDay(ev)) {
    var as = evParts(ev, ev.l);
    var last = evParts(ev, Math.max(ev.l, ev.r - 1));
    text = pserial(as) === pserial(last)
      ? fmtDate(as) + ' · All day'
      : fmtDate(as) + ' – ' + fmtDate(last) + ' · All day';
  } else if (ev.l === ev.r) {
    text = fmtDate(s) + ' · ' + fmtTimeLong(s);
  } else if (sameDay) {
    text = fmtDate(s) + ' · ' + fmtTimeLong(s) + ' – ' + fmtTimeLong(e);
  } else {
    text = fmtDate(s) + ' ' + fmtTimeLong(s) + ' – ' + fmtDate(e) + ' ' + fmtTimeLong(e);
  }
  document.getElementById('pop-time').textContent = text;
  var note = document.getElementById('pop-note');
  note.textContent = ev.note || '';
  note.style.display = ev.note ? '' : 'none';
  var pt = document.getElementById('pop-tags');
  pt.textContent = '';
  (ev.tags || []).forEach(function(t) { var sp = document.createElement('span'); sp.textContent = '#' + t; pt.appendChild(sp); });
  pt.style.display = (ev.tags || []).length ? '' : 'none';
  var series = isSeries(ev);
  // a calendar shared with us read-only takes no edits; offer none
  var ro = calReadonly(ev.cal);
  document.getElementById('pop-edit').style.display = ro ? 'none' : '';
  document.getElementById('pop-skip').style.display = series && !ro ? '' : 'none';
  var pd = document.getElementById('pop-done');
  pd.style.display = ev.cat === 'todo' && !ro ? '' : 'none';
  pd.textContent = ev.done ? 'Reopen' : 'Done';
  var pdel = document.getElementById('pop-del');
  pdel.style.display = ro ? 'none' : '';
  pdel.textContent = series ? 'Delete series' : 'Delete';
  pop.classList.remove('hidden');
  var pw = 290, ph = 170;
  pop.style.left = Math.min(x, window.innerWidth - pw - 8) + 'px';
  pop.style.top = Math.min(y, window.innerHeight - ph - 8) + 'px';
}
function hidePop() { pop.classList.add('hidden'); popTarget = null; }
// a recurring series: timed or all-day with a repeating kind
function isSeries(ev) { return (ev.cat === 'timed' || ev.cat === 'allday') && ev.kind !== 'once'; }
// after a change: the view and the tag list (a change may add a tag)
function refresh() { loadTags(); load(); }

document.getElementById('pop-done').onclick = function() {
  if (!popTarget) return;
  poke({ action: 'done-event', id: popTarget.id, home: popTarget.cal, done: !popTarget.done });
  hidePop();
  setTimeout(refresh, 400);
};

document.getElementById('pop-close').onclick = hidePop;
document.getElementById('pop-skip').onclick = function() {
  if (!popTarget) return;
  // by its start, not its index: the ship counts, so a stale view
  // cannot skip the wrong occurrence
  var t = popTarget;
  poke({ action: 'skip-at', id: t.id, home: t.cal, start_ms: t.l }, function(ok) {
    if (!ok) return;
    toast('Skipped "' + t.name + '" on ' + fmtDate(evParts(t, t.l)) + '.', function() {
      poke({ action: 'unskip-at', id: t.id, home: t.cal, start_ms: t.l }, function() { setTimeout(refresh, 400); });
    });
  });
  hidePop();
  setTimeout(refresh, 400);
};

// a note at the foot of the page, with an undo for the change it names
var toastTimer = null;
function toast(text, undo) {
  var el = document.getElementById('toast');
  document.getElementById('toast-text').textContent = text;
  var b = document.getElementById('toast-undo');
  b.style.display = undo ? '' : 'none';
  b.onclick = function() { el.classList.add('hidden'); if (undo) undo(); };
  el.classList.remove('hidden');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(function() { el.classList.add('hidden'); }, 8000);
}
document.getElementById('pop-del').onclick = function() {
  if (!popTarget) return;
  var q = !isSeries(popTarget)
    ? 'Delete "' + popTarget.name + '"?'
    : 'Delete "' + popTarget.name + '" and all its occurrences?';
  if (!confirm(q)) return;
  poke({ action: 'del-event', id: popTarget.id, home: popTarget.cal });
  hidePop();
  setTimeout(refresh, 400);
};
document.getElementById('pop-edit').onclick = function() {
  if (!popTarget) return;
  var t = popTarget;
  getJSON('/event.json?id=' + encodeURIComponent(t.id) + '&cal=' + encodeURIComponent(t.cal || '') + '&idx=' + (t.idx || 0))
    .then(function(d) { hidePop(); openEdit(d, t); })
    .catch(loadFailed);
};
document.addEventListener('click', function(e) {
  if (!pop.classList.contains('hidden') &&
      !pop.contains(e.target) && !e.target.closest('.chip') &&
      !e.target.closest('.blk')) hidePop();
});

function chipEl(ev, cont) {
  var chip = document.createElement('div');
  chip.className = 'chip' + (cont ? ' cont' : '') + (ev.cat === 'todo' && ev.done ? ' todo-done' : '');
  chip.style.background = ev.color || '#4a6a8a';
  var nm = ev.cat === 'todo' ? (ev.done ? '☑ ' : '☐ ') + ev.name : ev.name;
  chip.textContent = cont ? '· ' + nm
    : ev.all ? nm : fmtTime(parts(ev.l)) + ' ' + nm;
  chip.title = ev.name + (ev.note ? ' — ' + ev.note : '');
  chip.onclick = function(e) {
    e.stopPropagation();
    showPop(ev, e.clientX + 6, e.clientY + 6);
  };
  return pressable(chip);
}

// ---- month view ---------------------------------------------------

var grid = document.getElementById('grid');
document.getElementById('dow-row').innerHTML =
  '<div class="dow wk-stub"></div>' +
  WDS.map(function(d) { return '<div class="dow">' + d + '</div>'; }).join('');

function monthCells() {
  var first = serial(state.y, state.m, 1);
  var dow = (new Date(first * MS_DAY).getUTCDay() + 6) % 7;
  var out = [];
  for (var i = 0; i < 42; i++) out.push(unserial(first - dow + i));
  return out;
}

function renderMonth(rows) {
  var byDay = {};
  rows.forEach(function(ev) {
    var s = pserial(evParts(ev, ev.l));
    var e = pserial(evParts(ev, Math.max(ev.l, ev.r - 1)));
    for (var d = s, first = true; d <= e; d++, first = false) {
      (byDay[d] = byDay[d] || []).push({ ev: ev, cont: !first });
    }
  });
  var today = pserial(parts(Date.now()));
  grid.innerHTML = '';
  monthCells().forEach(function(c, i) {
    var ser = serial(c.y, c.m, c.d);
    if (i % 7 === 0) {
      var wk = document.createElement('div');
      wk.className = 'wknum';
      wk.textContent = isoWeek(ser);
      wk.title = 'Week ' + isoWeek(ser);
      wk.onclick = function() {
        state.view = 'week'; state.y = c.y; state.m = c.m; state.d = c.d; load();
      };
      grid.appendChild(pressable(wk));
    }
    var cell = document.createElement('div');
    cell.className = 'cell' + (c.m !== state.m ? ' other' : '') +
      (ser === today ? ' today' : '') +
      (ser === serial(state.y, state.m, state.d) ? ' axis' : '');
    var num = document.createElement('div');
    num.className = 'dnum';
    num.textContent = c.d;
    num.onclick = function(e) {
      e.stopPropagation();
      state.view = 'day'; state.y = c.y; state.m = c.m; state.d = c.d; load();
    };
    cell.appendChild(pressable(num, 'Open ' + fmtDate(c)));
    if (ser === today) cell.setAttribute('aria-current', 'date');
    cell.onclick = function(e) {
      if (e.target !== cell) return;
      openModal({ date: c, kind: 'once' });
    };
    pressable(cell, 'New event on ' + fmtDate(c));
    (byDay[ser] || [])
      .sort(function(a, b) { return (a.cont ? 0 : a.ev.l) - (b.cont ? 0 : b.ev.l); })
      .forEach(function(en) { cell.appendChild(chipEl(en.ev, en.cont)); });
    capsOn(ser).forEach(function(cp) { cell.appendChild(capChip(cp)); });
    grid.appendChild(cell);
  });
  clipCells();
}

// a day with more chips than fit hides the last ones behind "+N more",
// which opens the day
function clipCells() {
  grid.querySelectorAll('.cell').forEach(function(cell) {
    var chips = [].slice.call(cell.querySelectorAll('.chip'));
    if (!chips.length || cell.scrollHeight <= cell.clientHeight) return;
    var more = document.createElement('div');
    more.className = 'more';
    cell.appendChild(more);
    var hid = 0;
    while (cell.scrollHeight > cell.clientHeight && hid < chips.length) {
      chips[chips.length - 1 - hid].style.display = 'none';
      hid++;
      more.textContent = '+' + hid + ' more';
    }
    more.onclick = function(e) { e.stopPropagation(); cell.querySelector('.dnum').click(); };
    pressable(more);
  });
}
var monthRows = null;
window.addEventListener('resize', function() {
  if (state.view === 'month' && monthRows) renderMonth(monthRows);
});

// ---- week / day view ----------------------------------------------

var tgHead = document.getElementById('tg-head');
var tgAllday = document.getElementById('tg-allday');
var tgBody = document.getElementById('tg-body');
var tgScroll = document.getElementById('tg-scroll');

function gridDays(n) {
  var base = serial(state.y, state.m, state.d);
  if (n === 7) {
    var dow = (new Date(base * MS_DAY).getUTCDay() + 6) % 7;
    base -= dow;
  }
  var out = [];
  for (var i = 0; i < n; i++) out.push(unserial(base + i));
  return out;
}

function renderTimeGrid(rows, n) {
  var days = gridDays(n);
  var sers = days.map(function(c) { return serial(c.y, c.m, c.d); });
  var today = pserial(parts(Date.now()));

  // header
  tgHead.innerHTML = '';
  days.forEach(function(c) {
    var el = document.createElement('div');
    var ser = serial(c.y, c.m, c.d);
    el.className = 'tg-day' + (ser === today ? ' today' : '') +
      (n === 7 && ser === serial(state.y, state.m, state.d) ? ' axis' : '');
    el.textContent = WDS[(new Date(ser * MS_DAY).getUTCDay() + 6) % 7] + ' ' + c.d;
    el.onclick = function() { state.view = 'day'; state.y = c.y; state.m = c.m; state.d = c.d; load(); };
    if (ser === today) el.setAttribute('aria-current', 'date');
    tgHead.appendChild(pressable(el));
  });

  // all-day lane
  tgAllday.innerHTML = '';
  var lanes = days.map(function(c) {
    var el = document.createElement('div');
    el.className = 'ad-col';
    capsOn(serial(c.y, c.m, c.d)).forEach(function(cp) { el.appendChild(capChip(cp)); });
    tgAllday.appendChild(el);
    return el;
  });

  // body: axis + day columns
  tgBody.innerHTML = '';
  var axis = document.createElement('div');
  axis.id = 'tg-axis';
  for (var h = 1; h < 24; h++) {
    var lab = document.createElement('div');
    lab.className = 'hour-label';
    lab.style.top = (h * 60) + 'px';
    lab.textContent = fmtHour(h);
    axis.appendChild(lab);
  }
  tgBody.appendChild(axis);

  var cols = days.map(function(c) {
    var col = document.createElement('div');
    col.className = 'tg-col';
    for (var h = 1; h < 24; h++) {
      var line = document.createElement('div');
      line.className = 'hour-line';
      line.style.top = (h * 60) + 'px';
      col.appendChild(line);
    }
    col.onclick = function(e) {
      if (e.target !== col && !e.target.classList.contains('hour-line')) return;
      var rect = col.getBoundingClientRect();
      var min = Math.max(0, Math.min(1410,
        Math.floor((e.clientY - rect.top) / 30) * 30));
      openModal({
        date: c,
        time: pad2(Math.floor(min / 60)) + ':' + pad2(min % 60),
        kind: 'once'
      });
    };
    tgBody.appendChild(col);
    return col;
  });

  // place events
  var perDay = sers.map(function() { return []; });
  rows.forEach(function(ev) {
    if (isAllDay(ev)) {
      var s = pserial(evParts(ev, ev.l));
      var e = pserial(evParts(ev, Math.max(ev.l, ev.r - 1)));
      sers.forEach(function(ser, i) {
        if (ser >= s && ser <= e) lanes[i].appendChild(chipEl(ev, ser !== s));
      });
      return;
    }
    var sp = parts(ev.l);
    var rp = parts(ev.r);
    var sSer = pserial(sp);
    var eSer = pserial(parts(Math.max(ev.l, ev.r - 1)));
    sers.forEach(function(ser, i) {
      if (ser < sSer || ser > eSer) return;
      var sMin = (ser === sSer) ? sp.hh * 60 + sp.mm : 0;
      var eMin = (ser === pserial(rp)) ? rp.hh * 60 + rp.mm : 1440;
      if (ev.l === ev.r) eMin = sMin;
      perDay[i].push({ s: sMin, e: Math.max(eMin, sMin + 20), ev: ev });
    });
  });

  perDay.forEach(function(items, i) {
    pack(items);
    items.forEach(function(it) {
      var blk = document.createElement('div');
      blk.className = 'blk';
      blk.style.background = it.ev.color || '#4a6a8a';
      blk.style.top = it.s + 'px';
      blk.style.height = Math.max(18, it.e - it.s) + 'px';
      var w = 100 / it.ncols;
      blk.style.left = (it.col * w) + '%';
      blk.style.width = 'calc(' + w + '% - 3px)';
      var t = parts(it.ev.l);
      var bt = document.createElement('div'); bt.className = 'blk-time'; bt.textContent = fmtTime(t);
      blk.textContent = ''; blk.appendChild(bt); blk.appendChild(document.createTextNode(it.ev.name));
      blk.title = it.ev.name + (it.ev.note ? ' — ' + it.ev.note : '');
      blk.onclick = function(e) {
        e.stopPropagation();
        showPop(it.ev, e.clientX + 6, e.clientY + 6);
      };
      cols[i].appendChild(pressable(blk));
    });
  });

  // now-line
  function placeNow() {
    var np = parts(Date.now());
    var ser = pserial(np);
    var idx = sers.indexOf(ser);
    var old = tgBody.querySelector('.now-line');
    if (old) old.remove();
    if (idx < 0) return;
    var line = document.createElement('div');
    line.className = 'now-line';
    line.style.top = (np.hh * 60 + np.mm) + 'px';
    cols[idx].appendChild(line);
  }
  placeNow();
  if (nowTimer) clearInterval(nowTimer);
  nowTimer = setInterval(placeNow, 60000);

  // the rows above the scroller leave room for its scrollbar, so their
  // columns line up with the ones below
  var gutter = (tgScroll.offsetWidth - tgScroll.clientWidth) + 'px';
  tgHead.style.paddingRight = gutter; tgAllday.style.paddingRight = gutter;

  // scroll to ~8am on first paint only; a save keeps the user's place
  if (!tgScrolled) { tgScroll.scrollTop = 8 * 60 - 20; tgScrolled = true; }
}
var tgScrolled = false;

// ---- view routing -------------------------------------------------

function setLabel() {
  if (state.view === 'tasks') {
    label.textContent = 'Tasks';
  } else if (state.view === 'month') {
    label.textContent = MN[state.m - 1] + ' ' + state.y;
  } else if (state.view === 'week') {
    var ds = gridDays(7);
    var a = ds[0], b = ds[6];
    label.textContent = MN[a.m - 1].slice(0, 3) + ' ' + a.d + ' – ' +
      (a.m === b.m ? '' : MN[b.m - 1].slice(0, 3) + ' ') + b.d + ', ' + b.y;
    var sub = document.createElement('span');
    sub.className = 'wk-sub';
    sub.textContent = 'Week ' + isoWeek(serial(a.y, a.m, a.d));
    label.appendChild(sub);
  } else {
    var s = serial(state.y, state.m, state.d);
    label.textContent = WDS[(new Date(s * MS_DAY).getUTCDay() + 6) % 7] + ' ' +
      MN[state.m - 1].slice(0, 3) + ' ' + state.d + ', ' + state.y;
  }
}

function syncUrl() {
  var q = '?view=' + state.view + '&date=' +
    state.y + '-' + ('0' + state.m).slice(-2) + '-' + ('0' + state.d).slice(-2);
  history.replaceState(null, '', location.pathname + q);
}

var loader = document.getElementById('loader');
var loaderTimer = null;
var loadSeq = 0;

function load() {
  syncUrl();
  setLabel();
  if (loaderTimer) clearTimeout(loaderTimer);
  loaderTimer = setTimeout(function() { loader.classList.add('on'); }, 150);
  // only the latest load draws: a slow answer for the month just left
  // must not paint over the one now showing. A failed load (null)
  // leaves the grid as it was.
  var seq = ++loadSeq;
  // a tooltip over a chip that is about to be redrawn would stick
  var tip = document.getElementById('tipbox');
  if (tip) tip.remove();
  var settle = function(fn) {
    return function(rows) {
      if (seq !== loadSeq) return;
      clearTimeout(loaderTimer);
      loader.classList.remove('on');
      if (!rows) return;
      document.getElementById('load-err').textContent = '';
      fn(rows);
    };
  };
  ['month', 'week', 'day', 'tasks'].forEach(function(v) {
    document.getElementById('v-' + v).classList.toggle('on', state.view === v);
  });
  document.getElementById('month-view').style.display =
    state.view === 'month' ? 'flex' : 'none';
  document.getElementById('time-view').style.display =
    (state.view === 'week' || state.view === 'day') ? 'flex' : 'none';
  document.getElementById('tasks-view').style.display =
    state.view === 'tasks' ? 'flex' : 'none';
  var from, to;
  if (state.view === 'tasks') {
    loadTasks(settle(renderTasks));
  } else if (state.view === 'month') {
    var cs = monthCells();
    from = serial(cs[0].y, cs[0].m, cs[0].d) * MS_DAY - MS_DAY;
    to = serial(cs[41].y, cs[41].m, cs[41].d) * MS_DAY + 2 * MS_DAY;
    fetchWindow(from, to, settle(function(rows) { monthRows = rows; renderMonth(rows); }));
  } else {
    var n = state.view === 'week' ? 7 : 1;
    var ds = gridDays(n);
    from = serial(ds[0].y, ds[0].m, ds[0].d) * MS_DAY - MS_DAY;
    to = serial(ds[n - 1].y, ds[n - 1].m, ds[n - 1].d) * MS_DAY + 2 * MS_DAY;
    fetchWindow(from, to, settle(function(rows) { renderTimeGrid(rows, n); }));
  }
}

function step(dir) {
  if (state.view === 'tasks') return;
  if (state.view === 'month') {
    var m = state.m - 1 + dir;
    state.y += Math.floor(m / 12);
    state.m = ((m % 12) + 12) % 12 + 1;
    state.d = 1;
  } else {
    var days = state.view === 'week' ? 7 : 1;
    var c = unserial(serial(state.y, state.m, state.d) + dir * days);
    state.y = c.y; state.m = c.m; state.d = c.d;
  }
  load();
}

function goToday() {
  var p = parts(Date.now());
  state.y = p.y; state.m = p.m; state.d = p.d;
  load();
}

document.getElementById('prev').onclick = function() { step(-1); };
document.getElementById('next').onclick = function() { step(1); };
document.getElementById('today').onclick = goToday;
document.getElementById('v-month').onclick = function() { state.view = 'month'; load(); };
document.getElementById('v-week').onclick = function() { state.view = 'week'; load(); };
document.getElementById('v-day').onclick = function() { state.view = 'day'; load(); };
document.getElementById('v-tasks').onclick = function() { state.view = 'tasks'; load(); };

// ---- tasks view ---------------------------------------------------

function loadTasks(cb) {
  // only the tasks: the ship filters, so a big calendar is not sent whole
  getJSON('/events.json?cat=todo' + (state.tag ? '&tag=' + encodeURIComponent(state.tag) : ''))
    .then(function(rows) {
      cb((rows || []).filter(function(r) { return r.cat === 'todo'; }).map(function(r) {
        var m = r.meta || {};
        return { id: r.id, cal: r.cal, name: m.name || '', note: m.note || '', tags: m.tags || [],
                 color: safeColor(m.color) || calColor(r.cal) || '', due_ms: r.due_ms || 0, done: !!r.done, cat: 'todo' };
      }));
    })
    .catch(function(e) { loadFailed(e); cb(null); });
}

function taskRow(t) {
  var row = document.createElement('div');
  row.className = 'task-row' + (t.done ? ' done' : '');
  var cb = document.createElement('input'); cb.type = 'checkbox'; cb.checked = t.done;
  cb.disabled = calReadonly(t.cal);
  cb.onclick = function(e) { e.stopPropagation(); poke({ action: 'done-event', id: t.id, home: t.cal, done: cb.checked }); setTimeout(load, 400); };
  var dot = document.createElement('span'); dot.className = 't-dot'; dot.style.background = t.color || '#4a6a8a';
  var nm = document.createElement('span'); nm.className = 't-name'; nm.textContent = t.name; nm.title = t.note || t.name;
  var due = document.createElement('span'); due.className = 't-due';
  if (t.due_ms) {
    due.textContent = fmtDate(dueParts(t.due_ms));
    if (!t.done && pserial(dueParts(t.due_ms)) < pserial(parts(Date.now()))) { due.classList.add('late'); due.textContent += ' · overdue'; }
  }
  var tg = document.createElement('span'); tg.className = 't-tags'; tg.textContent = t.tags.map(function(x) { return '#' + x; }).join(' ');
  row.appendChild(cb); row.appendChild(dot); row.appendChild(nm); row.appendChild(due); row.appendChild(tg);
  row.onclick = function() {
    if (calReadonly(t.cal)) return;
    getJSON('/event.json?id=' + encodeURIComponent(t.id) + '&cal=' + encodeURIComponent(t.cal || ''))
      .then(function(d) { openEdit(d, { idx: 0, l: t.due_ms || Date.now() }); })
      .catch(loadFailed);
  };
  return pressable(row);
}

function renderTasks(tasks) {
  var open = document.getElementById('task-open'), done = document.getElementById('task-done');
  open.innerHTML = ''; done.innerHTML = '';
  var byDue = function(a, b) { return (a.due_ms || 9e15) - (b.due_ms || 9e15) || a.name.localeCompare(b.name); };
  var o = tasks.filter(function(t) { return !t.done; }).sort(byDue);
  var d = tasks.filter(function(t) { return t.done; }).sort(byDue);
  if (!o.length) open.innerHTML = '<div class="task-row" style="border:none;color:#666;cursor:default">Nothing to do.</div>';
  o.forEach(function(t) { open.appendChild(taskRow(t)); });
  d.forEach(function(t) { done.appendChild(taskRow(t)); });
  document.getElementById('task-done-sum').textContent = 'Done (' + d.length + ')';
  document.getElementById('task-done-wrap').style.display = d.length ? '' : 'none';
}

var taskSave = document.getElementById('task-save');
taskSave.onclick = function() {
  var name = document.getElementById('task-name').value.trim();
  if (!name || taskSave.disabled) return;
  var body = { action: 'add-event', cat: 'todo', meta: { name: name } };
  var dv = document.getElementById('task-due').value;
  if (dv) { var p = dv.split('-'); body.due_ms = Date.UTC(+p[0], +p[1] - 1, +p[2]); }
  var cs = document.getElementById('task-cal').value;
  if (cs) body.cal = cs;
  if (state.tag) body.meta.tags = [state.tag];
  taskSave.disabled = true;
  poke(body, function(ok) {
    taskSave.disabled = false;
    if (ok) document.getElementById('task-name').value = '';
    setTimeout(refresh, 400);
  });
};
document.getElementById('task-name').addEventListener('keydown', function(e) { if (e.key === 'Enter') taskSave.onclick(); });

// Escape closes whatever is open: the popover, then a modal
document.addEventListener('keydown', function(e) {
  if (e.key !== 'Escape') return;
  if (!pop.classList.contains('hidden')) { hidePop(); return; }
  if (back.classList.contains('open')) back.classList.remove('open');
  else if (settingsBack.classList.contains('open')) closeSettings();
});

document.addEventListener('keydown', function(e) {
  if (e.ctrlKey || e.metaKey || e.altKey) return;
  if (back.classList.contains('open') || settingsBack.classList.contains('open')) return;
  if (e.target.tagName === 'INPUT' || e.target.tagName === 'SELECT' ||
      e.target.tagName === 'TEXTAREA') return;
  if (e.key === 'm') { state.view = 'month'; load(); }
  if (e.key === 'w') { state.view = 'week'; load(); }
  if (e.key === 'd') { state.view = 'day'; load(); }
  if (e.key === 'k') { state.view = 'tasks'; load(); }
  if (e.key === 't') goToday();
  if (e.key === 'ArrowLeft') step(-1);
  if (e.key === 'ArrowRight') step(1);
});

// ---- add modal ----------------------------------------------------

var back = document.getElementById('modal-back');
var kindSel = document.getElementById('f-kind');
var dowSel = document.getElementById('f-dow');
var daysDiv = document.getElementById('f-days');
var WDF = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
WD.forEach(function(d, i) {
  var o = document.createElement('option');
  o.value = d; o.textContent = WDF[i];
  dowSel.appendChild(o);
  var t = document.createElement('button');
  t.type = 'button';
  t.className = 'day-tog';
  t.textContent = WDF[i];
  t.dataset.d = d;
  t.setAttribute('aria-pressed', 'false');
  t.onclick = function() { setTog(t, !t.classList.contains('on')); };
  daysDiv.appendChild(t);
});
function setTog(t, on) { t.classList.toggle('on', on); t.setAttribute('aria-pressed', on ? 'true' : 'false'); }
var monSel = document.getElementById('f-month');
var bmonSel = document.getElementById('f-bmonth');
MN.forEach(function(m, i) {
  [monSel, bmonSel].forEach(function(sel) {
    var o = document.createElement('option');
    o.value = i + 1; o.textContent = m;
    sel.appendChild(o);
  });
});

var KIND_HINT = {
  'once': 'Happens a single time.',
  'daily': 'Every day at the chosen time.',
  'weekly': 'Every week on the days you pick.',
  'monthly': 'On that day number each month. Short months are skipped.',
  'monthly-nth': 'On, say, the Second Tuesday of every month.',
  'yearly': 'Once a year on the same date, from the chosen year on.',
  'every': 'A fixed interval on the clock, regardless of timezone.'
};

var cat = 'timed';

function syncFields() {
  var k = kindSel.value;
  var rc = (cat === 'timed' || cat === 'allday');   // has a recurrence
  var show = {
    rc: rc,
    bf: cat === 'date',
    df: cat === 'todo',
    tf: cat === 'timed',
    af: cat === 'allday',
    wf: rc && k === 'weekly',
    mf: rc && k === 'monthly',
    nf: rc && k === 'monthly-nth',
    yf: rc && k === 'yearly',
    ef: rc && k === 'every'
  };
  Object.keys(show).forEach(function(c) {
    document.querySelectorAll('.' + c).forEach(function(el) {
      el.style.display = show[c] ? '' : 'none';
    });
  });
  document.getElementById('kind-hint').textContent = KIND_HINT[k] || '';
  document.getElementById('lbl-start').textContent =
    (k === 'once') ? 'Date & time' : 'Starting from';
}
kindSel.onchange = syncFields;

var seg = document.getElementById('cat-seg');
function setCat(c) {
  cat = c;
  seg.querySelectorAll('.seg-btn').forEach(function(b) {
    b.classList.toggle('on', b.dataset.cat === c);
  });
  syncFields();
}
seg.querySelectorAll('.seg-btn').forEach(function(b) {
  b.onclick = function() { setCat(b.dataset.cat); };
});

var zoneSel = document.getElementById('f-zone');
var dispSel = document.getElementById('zone-sel');

function fillZoneSelect(sel, zs, withDefault) {
  sel.innerHTML = '';
  if (withDefault) {
    var def = document.createElement('option');
    def.value = '';
    def.textContent = CFG.zone
      ? 'Calendar default (' + CFG.zone + ')'
      : 'Calendar default (UTC)';
    sel.appendChild(def);
  }
  var utc = document.createElement('option');
  utc.value = 'none';
  utc.textContent = 'UTC';
  sel.appendChild(utc);
  zs.forEach(function(z) {
    var o = document.createElement('option');
    o.value = z;
    o.textContent = z;
    sel.appendChild(o);
  });
}

function loadZones() {
  getJSON('/zones.json')
    .then(function(zs) {
      fillZoneSelect(zoneSel, zs, true);
      fillZoneSelect(dispSel, zs, false);
      dispSel.value = CFG.zone || 'none';
    })
    .catch(function() {});
}

// target: pick the axis date all views orient around
var axisBtn = document.getElementById('axis-btn');
var axisInput = document.getElementById('axis-input');
axisBtn.onclick = function() {
  axisInput.value = state.y + '-' + pad2(state.m) + '-' + pad2(state.d);
  if (axisInput.showPicker) axisInput.showPicker(); else axisInput.click();
};
axisInput.onchange = function() {
  if (!axisInput.value) return;
  var p = axisInput.value.split('-');
  state.y = +p[0]; state.m = +p[1]; state.d = +p[2];
  load();
};

// feeds modal: manage the named external ICS urls

function loadFeeds() {
  getJSON('/feeds.json')
    .then(function(fs) {
      var list = document.getElementById('feeds-list');
      list.innerHTML = '';
      var names = Object.keys(fs);
      if (!names.length) {
        list.innerHTML = '<div class="feed-row empty">No feeds yet. Paste your Google Calendar secret iCal address below.</div>';
        return;
      }
      names.forEach(function(n) {
        var row = document.createElement('div');
        row.className = 'feed-row';
        var nm = document.createElement('span');
        nm.className = 'fn';
        nm.textContent = n;
        var u = document.createElement('span');
        u.className = 'fu';
        u.textContent = fs[n];
        var x = document.createElement('button');
        x.className = 'fx';
        x.textContent = '✕';
        x.title = 'Remove feed';
        x.onclick = function() {
          poke({ action: 'del-feed', name: n }, function() { setTimeout(loadFeeds, 300); });
        };
        row.appendChild(nm); row.appendChild(u); row.appendChild(x);
        list.appendChild(row);
      });
    })
    .catch(function() {});
}

document.getElementById('feed-add').onclick = function() {
  var st = document.getElementById('feeds-status');
  var n = document.getElementById('feed-name').value.trim();
  var u = document.getElementById('feed-url').value.trim();
  if (!n || !u) { st.textContent = 'name and url required'; return; }
  st.textContent = '';
  poke({ action: 'add-feed', name: n, url: u }, function(ok) {
    if (!ok) { st.textContent = 'save failed'; return; }
    document.getElementById('feed-name').value = '';
    document.getElementById('feed-url').value = '';
    setTimeout(loadFeeds, 300);
  });
};

// Google: the user's own OAuth client, connect, link calendars

function loadGoogle() {
  var st = document.getElementById('google-status');
  getJSON('/google.json')
    .then(function(g) {
      document.getElementById('google-cid').value = g.client_id || '';
      document.getElementById('google-csec').value = '';
      document.getElementById('google-csec').placeholder = g.client_secret ? g.client_secret + ' (saved)' : 'GOCSPX-…';
      var linked = g.linked || {};
      var n = Object.keys(linked).length;
      st.textContent = g.connected ? ('Connected. ' + n + ' calendar' + (n === 1 ? '' : 's') + ' linked.') : 'Not connected.';
      document.getElementById('google-setup').open = !g.client_id;
      if (g.connected) loadGoogleCalendars(linked);
      else document.getElementById('google-list').innerHTML = '';
    })
    .catch(function() { st.textContent = 'could not read the Google settings'; });
}

// the conflict log (every backend writes it): what the other side won
// over, each local copy downloadable, and a way to clear it
function loadConflicts() {
  getJSON('/google/conflicts.json').then(function(cs) {
    var gl = document.getElementById('google-conflicts');
    gl.textContent = cs.length ? (cs.length + ' conflict' + (cs.length === 1 ? '' : 's') + ' logged') : '';
    gl.onclick = function(e) { e.preventDefault(); var sect = document.getElementById('conflicts-sect'); sect.open = true; sect.scrollIntoView(); };
    var list = document.getElementById('conflicts-list');
    list.innerHTML = '';
    if (!cs.length) { list.innerHTML = '<div class="feed-row empty">No conflicts.</div>'; return; }
    cs.slice().reverse().forEach(function(c) {
      var row = document.createElement('div'); row.className = 'feed-row';
      var nm = document.createElement('span'); nm.className = 'fn';
      nm.textContent = (CALS[c.cal] ? CALS[c.cal].name : c.cal) + ': ' + c.why;
      var u = document.createElement('span'); u.className = 'fu';
      u.textContent = new Date(c.at_ms).toLocaleString() + ' · ' + c.uid;
      row.appendChild(nm); row.appendChild(u);
      if (c.local) {
        var a = document.createElement('a'); a.className = 'fx'; a.style.fontSize = '12px';
        a.textContent = 'Your copy';
        a.href = URL.createObjectURL(new Blob([c.local], { type: 'text/calendar' }));
        a.download = 'conflict.ics';
        row.appendChild(a);
      }
      list.appendChild(row);
    });
  }).catch(function() {});
}
document.getElementById('conflicts-clear').onclick = function() {
  if (!confirm('Clear the conflict log? The kept local copies go with it.')) return;
  busy(this, postJSON('/google/conflicts/clear')).then(loadConflicts);
};

// import: an .ics file into a calendar, each object replacing one with
// its UID
document.getElementById('imp-go').onclick = function() {
  var st = document.getElementById('imp-status');
  var f = document.getElementById('imp-file').files[0];
  var cal = document.getElementById('imp-cal').value;
  if (!f) { st.textContent = 'pick a file'; return; }
  st.textContent = 'importing…';
  var btn = this;
  busy(btn, f.text().then(function(body) {
    return fetch(CAL + '/import?cal=' + encodeURIComponent(cal), { method: 'POST', headers: { 'content-type': 'text/calendar' }, body: body });
  }).then(function(r) { if (!r.ok) return r.text().then(function(t) { throw new Error(t || r.status); }); return r.json(); })
    .then(function(d) {
      st.textContent = d.imported + ' imported' + (d.skipped ? ', ' + d.skipped + ' could not be read' : '');
      document.getElementById('imp-file').value = '';
      loadCalsList(); refresh();
    })
    .catch(function(e) { st.textContent = 'import failed: ' + e.message; }));
};

function loadGoogleCalendars(linked) {
  var list = document.getElementById('google-list');
  list.innerHTML = '<div class="feed-row empty">Loading…</div>';
  getJSON('/google/calendars.json')
    .then(function(cs) {
      list.innerHTML = '';
      cs.forEach(function(c) {
        var row = document.createElement('div');
        row.className = 'feed-row';
        var dot = document.createElement('span');
        dot.style.cssText = 'width:10px;height:10px;border-radius:50%;display:inline-block;background:' + (safeColor(c.color) || '#888');
        var nm = document.createElement('span'); nm.className = 'fn'; nm.textContent = c.name + (c.primary ? ' (primary)' : '');
        var u = document.createElement('span'); u.className = 'fu';
        var linkedId = c.linked;
        u.textContent = linkedId ? ('linked' + (linked[linkedId] && linked[linkedId].last_ms ? ', synced ' + new Date(linked[linkedId].last_ms).toLocaleString() : ', not synced yet')) : '';
        var b = document.createElement('button'); b.className = 'fx'; b.style.fontSize = '12px';
        b.textContent = linkedId ? 'Unlink' : 'Link';
        b.onclick = function() {
          // unlinking deletes the ship's copy, tasks and unpushed edits
          // with it; Make local is the way to keep them
          if (linkedId && !confirm('Unlink "' + c.name + '"? Its copy on this ship is deleted, including tasks, which Google does not keep. Use Make local under Calendars to keep them.')) return;
          var body = linkedId ? { id: linkedId } : { google_id: c.id, name: c.name, color: safeColor(c.color) };
          postJSON('/google/' + (linkedId ? 'unlink' : 'link'), body)
            .then(function() { loadGoogle(); loadCals(); });
        };
        row.appendChild(dot); row.appendChild(nm); row.appendChild(u); row.appendChild(b);
        list.appendChild(row);
      });
      if (!cs.length) list.innerHTML = '<div class="feed-row empty">No calendars on this account.</div>';
    })
    .catch(function(e) {
      list.innerHTML = '<div class="feed-row empty err"></div>';
      list.firstChild.textContent = 'Google answered ' + e.message;
    });
}

document.getElementById('google-save').onclick = function() {
  var body = { client_id: document.getElementById('google-cid').value.trim(), client_secret: document.getElementById('google-csec').value.trim() };
  busy(this, postJSON('/google/config', body))
    .then(function(r) { document.getElementById('google-msg').textContent = r.ok ? 'saved' : 'not saved (' + r.status + ')'; loadGoogle(); });
};
// connect saves a client id typed and not saved yet, so the consent
// screen is asked for the client on the page
document.getElementById('google-connect').onclick = function() {
  var msg = document.getElementById('google-msg');
  var cid = document.getElementById('google-cid').value.trim();
  var sec = document.getElementById('google-csec').value.trim();
  if (!cid) { msg.textContent = 'paste the client id and secret first'; return; }
  busy(this, postJSON('/google/config', { client_id: cid, client_secret: sec }))
    .then(function(r) { if (!r.ok) throw new Error(r.status); location.href = CAL + '/google/connect'; })
    .catch(function(e) { msg.textContent = 'could not save the client (' + e.message + ')'; });
};
document.getElementById('google-disconnect').onclick = function() {
  postJSON('/google/disconnect').then(function() { loadGoogle(); });
};
document.getElementById('google-sync-now').onclick = function() {
  postJSON('/google/sync').then(function() { setTimeout(function() { loadGoogle(); refresh(); }, 3000); });
};
if (new URLSearchParams(location.search).get('google') === 'connected') { setTimeout(function() { openSettings(); document.getElementById('google-sect').open = true; }, 500); }

// the settings screen: calendars, sharing, following, Google, feeds
var settingsBack = document.getElementById('settings-back');
function openSettings() {
  document.getElementById('dav-url').textContent = location.origin + CAL + '/dav/';
  document.getElementById('dav-new').classList.add('hidden');
  document.getElementById('google-redirect').textContent = location.origin + CAL + '/google/callback';
  loadCalsList(); loadShares(); loadDav(); loadCdav(); loadGoogle(); loadFeeds(); loadConflicts();
  settingsBack.classList.add('open');
}
function closeSettings() {
  // a field still focused has not fired its change yet
  if (document.activeElement && settingsBack.contains(document.activeElement)) document.activeElement.blur();
  settingsBack.classList.remove('open'); loadCals(); refresh();
}
document.getElementById('settings-btn').onclick = openSettings;
document.getElementById('settings-close').onclick = closeSettings;
backdropClose(settingsBack, closeSettings);

// a click on the backdrop closes a modal, but not the end of a drag
// that started inside it (a text selection, say)
function backdropClose(el, close) {
  var down = null;
  el.addEventListener('mousedown', function(e) { down = e.target; });
  el.addEventListener('click', function(e) { if (e.target === el && down === el) close(); });
}

function loadCalsList() {
  getJSON('/calendars.json').then(function(cs) {
    var list = document.getElementById('cals-list');
    list.innerHTML = '';
    cs.forEach(function(c) {
      var row = document.createElement('div'); row.className = 'feed-row cal-row';
      var color = document.createElement('input'); color.type = 'color'; color.value = c.color || '#101541';
      color.setAttribute('aria-label', 'Color of ' + c.name);
      var nm = document.createElement('input'); nm.value = c.name; nm.style.flex = '1';
      nm.setAttribute('aria-label', 'Name of ' + c.name);
      var badge = document.createElement('span'); badge.className = 'kind-badge';
      badge.textContent = c.kind === 'google' ? 'google' : c.kind === 'caldav' ? 'followed' : c.kind === 'ship' ? 'shared with you' : 'local';
      var n = document.createElement('span'); n.className = 'fu'; n.style.flex = '0 0 auto'; n.textContent = c.count + (c.count === 1 ? ' event' : ' events');
      // a name or color saves when it is changed (on Enter, leaving the
      // field, or closing the picker), so closing Settings loses nothing
      var saveRow = function() {
        if (!nm.value.trim()) { nm.value = c.name; return; }
        poke({ action: 'edit-calendar', id: c.id, name: nm.value.trim(), color: color.value }, function() { loadCals(); });
      };
      nm.onchange = saveRow; color.onchange = saveRow;
      var del = document.createElement('button'); del.className = 'fx'; del.textContent = '✕'; del.title = 'Delete this calendar and its events';
      if (c.id === 'default' || c.kind !== 'local') del.style.visibility = 'hidden';
      var sh = document.createElement('button'); sh.className = 'fx'; sh.style.fontSize = '12px'; sh.textContent = 'Share…'; sh.title = 'Share this calendar with another ship';
      if (c.kind === 'ship') sh.style.display = 'none';
      sh.onclick = function() {
        var ship = prompt('Share "' + c.name + '" with which ship? (e.g. ~sampel-palnet)');
        if (!ship) return;
        ship = ship.trim(); if (ship[0] !== '~') ship = '~' + ship;
        // Cancel here backs out; it does not mean "read only"
        var mode = prompt('May ' + ship + ' edit it, or only read it? Type edit or read.', 'read');
        if (mode === null) return;
        mode = mode.trim().toLowerCase();
        if (mode !== 'edit' && mode !== 'read') { alert('Type edit or read. Nothing was shared.'); return; }
        var edit = mode === 'edit';
        if (c.kind !== 'local') {
          var src = c.kind === 'google' ? 'Google' : 'its source';
          if (!confirm('"' + c.name + '" syncs with ' + src + '. ' + (edit ? ship + "'s edits will reach " + src + ' through this ship, as if you made them. ' : '') + 'A sync hiccup on either side could show ' + ship + ' a stale copy for a while. Share anyway?')) return;
        }
        postJSON('/share/share', { id: c.id, ship: ship, mode: mode })
          .then(function(r) { if (!r.ok) return r.text().then(function(t) { throw new Error(t); }); return r.json(); })
          .then(function(d) { loadShares(); if (!d.notified) alert(ship + ' could not be reached right now (down, or it has no calendar app yet). The share is recorded here; share again once it is up to send the offer.'); })
          .catch(function(e) { alert('could not share: ' + e.message); });
      };
      var mig = document.createElement('button'); mig.className = 'fx'; mig.style.fontSize = '12px'; mig.textContent = 'Make local'; mig.title = 'Copy everything once and stop syncing; the source is left as it is';
      if (c.kind === 'local') mig.style.display = 'none';
      mig.onclick = function() {
        if (!confirm('Make "' + c.name + '" a local calendar? It pulls once more, then stops syncing and keeps its ' + c.count + ' events here. The ' + (c.kind === 'google' ? 'Google' : 'source') + ' calendar is not changed; delete it there yourself if you no longer want it.')) return;
        mig.textContent = 'working…';
        postJSON('/migrate', { id: c.id })
          .then(function(r) { if (!r.ok) throw new Error(r.status); return r.json(); })
          .then(function() { loadCalsList(); loadCdav(); loadGoogle(); })
          .catch(function() { mig.textContent = 'failed'; });
      };
      del.onclick = function() { if (!confirm('Delete "' + c.name + '" and its ' + c.count + ' events?')) return; poke({ action: 'del-calendar', id: c.id }, function() { setTimeout(loadCalsList, 300); }); };
      row.appendChild(color); row.appendChild(nm); row.appendChild(badge); row.appendChild(n); row.appendChild(sh); row.appendChild(mig); row.appendChild(del);
      list.appendChild(row);
    });
  }).catch(function() {});
}
document.getElementById('cal-new-add').onclick = function() {
  var st = document.getElementById('cals-status');
  var name = document.getElementById('cal-new-name').value.trim();
  if (!name) { st.textContent = 'name required'; return; }
  st.textContent = '';
  var base = name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || ('cal-' + Date.now());
  // the ship refuses an id it has, silently; pick a free one here
  var id = base;
  for (var n = 2; CALS[id]; n++) id = base + '-' + n;
  var btn = this;
  btn.disabled = true;
  poke({ action: 'add-calendar', id: id, name: name, color: document.getElementById('cal-new-color').value }, function(ok) {
    btn.disabled = false;
    if (!ok) { st.textContent = 'could not add'; return; }
    document.getElementById('cal-new-name').value = '';
    setTimeout(loadCalsList, 300);
  });
};

// sharing with ships: what we share, and what was shared with us
function loadShares() {
  getJSON('/share/shares.json').then(function(d) {
    var list = document.getElementById('shares-list');
    list.innerHTML = '';
    var shares = d.shares || {}, any = false;
    Object.keys(shares).forEach(function(cid) {
      Object.keys(shares[cid]).forEach(function(ship) {
        any = true;
        var row = document.createElement('div'); row.className = 'feed-row';
        var nm = document.createElement('span'); nm.className = 'fn'; nm.textContent = (CALS[cid] ? CALS[cid].name : cid);
        var u = document.createElement('span'); u.className = 'fu'; u.textContent = ship + ' · ' + (shares[cid][ship] === 'edit' ? 'can edit' : 'read only');
        var x = document.createElement('button'); x.className = 'fx'; x.textContent = 'Revoke'; x.style.fontSize = '12px';
        x.onclick = function() {
          if (!confirm('Stop sharing "' + nm.textContent + '" with ' + ship + '? Their copy stays with them as a calendar of their own; it just stops syncing.')) return;
          postJSON('/share/revoke', { id: cid, ship: ship }).then(loadShares);
        };
        row.appendChild(nm); row.appendChild(u); row.appendChild(x); list.appendChild(row);
      });
    });
    if (!any) list.innerHTML = '<div class="feed-row empty">Nothing shared yet. Use Share… on a calendar above.</div>';
    var ol = document.getElementById('offers-list');
    ol.innerHTML = '';
    var offers = d.offers || {}, accepted = d.accepted || {}, anyO = false;
    Object.keys(offers).forEach(function(key) {
      anyO = true; var o = offers[key];
      var row = document.createElement('div'); row.className = 'feed-row';
      var nm = document.createElement('span'); nm.className = 'fn'; nm.textContent = (o.name || o.cal) + ' from ' + o.host;
      var u = document.createElement('span'); u.className = 'fu'; u.textContent = o.mode === 'edit' ? 'read and edit' : 'read only';
      var a = document.createElement('button'); a.className = 'fx'; a.style.fontSize = '12px'; a.textContent = 'Accept';
      a.onclick = function() { postJSON('/share/accept', { key: key }).then(function() { setTimeout(function() { loadShares(); loadCalsList(); loadCals(); }, 1500); }); };
      var dcl = document.createElement('button'); dcl.className = 'fx'; dcl.textContent = '✕'; dcl.title = 'Decline';
      dcl.onclick = function() { postJSON('/share/decline', { key: key }).then(loadShares); };
      row.appendChild(nm); row.appendChild(u); row.appendChild(a); row.appendChild(dcl); ol.appendChild(row);
    });
    Object.keys(accepted).forEach(function(id) {
      anyO = true; var r = accepted[id];
      var row = document.createElement('div'); row.className = 'feed-row';
      var nm = document.createElement('span'); nm.className = 'fn'; nm.textContent = (CALS[id] ? CALS[id].name : id) + ' (' + r.key.split('/')[0] + ')';
      var u = document.createElement('span'); u.className = 'fu'; u.textContent = r.error ? r.error : ((r.mode === 'edit' ? 'read and edit' : 'read only') + (r.last_ms ? ', synced ' + new Date(r.last_ms).toLocaleString() : ', not synced yet'));
      if (r.error) u.style.color = '#f87171';
      row.appendChild(nm); row.appendChild(u); ol.appendChild(row);
    });
    if (!anyO) ol.innerHTML = '<div class="feed-row empty">No calendar has been shared with you.</div>';
  }).catch(function() {});
}

// following: a remote CalDAV calendar
function loadCdav() {
  getJSON('/caldav/subscriptions.json').then(function(subs) {
    var list = document.getElementById('cdav-list');
    list.innerHTML = '';
    if (!subs.length) { list.innerHTML = '<div class="feed-row empty">Not following any calendar.</div>'; return; }
    subs.forEach(function(sub) {
      var row = document.createElement('div'); row.className = 'feed-row';
      var nm = document.createElement('span'); nm.className = 'fn'; nm.textContent = sub.user + ' @ ' + sub.url;
      var u = document.createElement('span'); u.className = 'fu'; u.textContent = sub.error ? sub.error : (sub.last_ms ? 'synced ' + new Date(sub.last_ms).toLocaleString() : 'not synced yet');
      if (sub.error) u.style.color = '#f87171';
      var x = document.createElement('button'); x.className = 'fx'; x.textContent = 'Unfollow'; x.style.fontSize = '12px';
      x.onclick = function() {
        // unfollowing deletes the ship's copy; Make local keeps it
        if (!confirm('Unfollow ' + sub.url + '? Its copy on this ship is deleted, with any edits not yet sent. Use Make local under Calendars to keep it.')) return;
        postJSON('/caldav/unsubscribe', { id: sub.id })
          .then(function() { loadCdav(); loadCalsList(); });
      };
      row.appendChild(nm); row.appendChild(u); row.appendChild(x);
      list.appendChild(row);
    });
  }).catch(function() {});
}
document.getElementById('cdav-add').onclick = function() {
  var st = document.getElementById('cdav-status');
  var body = { url: document.getElementById('cdav-url').value.trim(), user: document.getElementById('cdav-user').value.trim(), password: document.getElementById('cdav-pass').value, name: document.getElementById('cdav-name').value.trim(), color: document.getElementById('cdav-color').value };
  if (!body.url) { st.textContent = 'url required'; return; }
  st.textContent = 'following…';
  busy(this, postJSON('/caldav/subscribe', body))
    .then(function(r) { if (!r.ok) throw new Error(r.status); return r.json(); })
    .then(function() { st.textContent = ''; document.getElementById('cdav-url').value = ''; document.getElementById('cdav-pass').value = ''; setTimeout(function() { loadCdav(); loadCalsList(); }, 2000); })
    .catch(function(e) { st.textContent = 'could not follow (' + e.message + ')'; });
};
document.getElementById('cdav-sync').onclick = function() {
  postJSON('/caldav/sync').then(function() { setTimeout(loadCdav, 3000); });
};

// tags: the filter in the header, from tags.json
var tagFilter = document.getElementById('tag-filter');
function loadTags() {
  getJSON('/tags.json').then(function(ts) {
    var cur = tagFilter.value;
    tagFilter.innerHTML = '';
    var all = document.createElement('option'); all.value = ''; all.textContent = 'All tags'; tagFilter.appendChild(all);
    ts.forEach(function(t) {
      var o = document.createElement('option'); o.value = t.tag; o.textContent = t.tag + ' (' + t.count + ')'; tagFilter.appendChild(o);
    });
    tagFilter.value = cur;
    tagFilter.style.display = ts.length ? '' : 'none';
    // the filtered tag is gone: stop filtering by it
    if (state.tag && tagFilter.value !== state.tag) { state.tag = ''; load(); }
  }).catch(function() {});
}
tagFilter.onchange = function() { state.tag = tagFilter.value; load(); };
function parseTags(text) {
  return text.split(',').map(function(t) { return t.trim(); }).filter(function(t, i, a) { return t && a.indexOf(t) === i; });
}

// CalDAV clients: list, mint (the password shows once), revoke

function loadDav() {
  getJSON('/dav-clients.json')
    .then(function(cs) {
      var list = document.getElementById('dav-list');
      list.innerHTML = '';
      if (!cs.length) {
        list.innerHTML = '<div class="feed-row empty">No clients yet.</div>';
        return;
      }
      cs.forEach(function(c) {
        var row = document.createElement('div');
        row.className = 'feed-row';
        var nm = document.createElement('span');
        nm.className = 'fn';
        nm.textContent = c.name;
        var u = document.createElement('span');
        u.className = 'fu';
        u.textContent = 'since ' + new Date(c.made_ms).toLocaleDateString();
        var x = document.createElement('button');
        x.className = 'fx';
        x.textContent = '✕';
        x.title = 'Revoke';
        x.onclick = function() {
          postJSON('/dav-clients/revoke', { id: c.id })
            .then(function() { loadDav(); });
        };
        row.appendChild(nm); row.appendChild(u); row.appendChild(x);
        list.appendChild(row);
      });
    })
    .catch(function() {});
}

document.getElementById('dav-add').onclick = function() {
  var st = document.getElementById('dav-status');
  var n = document.getElementById('dav-name').value.trim();
  if (!n) { st.textContent = 'name required'; return; }
  st.textContent = '';
  busy(this, postJSON('/dav-clients', { name: n }))
    .then(function(r) { if (!r.ok) throw new Error(r.status); return r.json(); })
    .then(function(d) {
      var box = document.getElementById('dav-new');
      box.innerHTML = '';
      var t = document.createElement('div');
      t.textContent = 'Password for ' + d.name + ' (shown once):';
      var pw = document.createElement('div');
      pw.className = 'pw';
      pw.textContent = d.password;
      var url = document.createElement('div');
      url.textContent = 'URL: ' + location.origin + d.url + '   Username: ' + (CFG.ship || 'your ship name');
      box.appendChild(t); box.appendChild(pw); box.appendChild(url);
      box.classList.remove('hidden');
      document.getElementById('dav-name').value = '';
      loadDav();
    })
    .catch(function() { st.textContent = 'mint failed'; });
};

// sync: wake the sync pass (Google, followed, shared) and refetch the
// ICS feeds
var syncBtn = document.getElementById('sync-btn');
syncBtn.onclick = function() {
  syncBtn.disabled = true;
  syncBtn.style.opacity = '0.4';
  postJSON('/google/sync').catch(function() {});
  poke({ action: 'sync-feeds' }, function() {
    setTimeout(function() {
      syncBtn.disabled = false;
      syncBtn.style.opacity = '';
      refresh();
    }, 1500);
  });
};

var clockBtn = document.getElementById('clock-btn');
function syncClockBtn() { clockBtn.textContent = H12 ? '12h' : '24h'; }
syncClockBtn();
clockBtn.onclick = function() {
  H12 = !H12;
  try { localStorage.setItem('cal-h12', H12 ? '1' : '0'); } catch (e) {}
  syncClockBtn();
  load();
};

dispSel.onchange = function() {
  var z = dispSel.value;
  poke({ action: 'config', zone: z }, function(ok) {
    if (!ok) { dispSel.value = CFG.zone || 'none'; return; }
    CFG.zone = (z === 'none') ? '' : z;
    mkfmt();
    if (zoneSel.options.length) zoneSel.options[0].textContent = 'Calendar default (' + (CFG.zone || 'UTC') + ')';
    load();
  });
};

// globe: one click to adopt the browser's timezone as the calendar zone
var globeBtn = document.getElementById('globe-btn');
var browserZone = '';
try { browserZone = Intl.DateTimeFormat().resolvedOptions().timeZone || ''; } catch (e) {}
if (browserZone) {
  globeBtn.title = 'Set calendar timezone to your browser timezone (' + browserZone + ')';
}
globeBtn.onclick = function() {
  if (!browserZone) return;
  var known = [].some.call(dispSel.options, function(o) { return o.value === browserZone; });
  if (!known) { alert('The ship does not know the zone ' + browserZone); return; }
  if (dispSel.value === browserZone) return;
  dispSel.value = browserZone;
  dispSel.onchange();
};

function pad2(x) { return ('0' + x).slice(-2); }

var editCtx = null;

// the kinds the form builds; an event of another kind (rrule from an
// import or Google, cron from a raw poke) keeps its rule as it came
var FORM_KINDS = ['once', 'daily', 'weekly', 'monthly', 'monthly-nth', 'yearly', 'every'];
// the kinds whose start carries the time of day; the rest day-floor
// it and take the time from their args
function timedStart(k) { return k === 'once' || k === 'every' || k === 'rrule'; }
function ymd(p) { return p.y + '-' + pad2(p.m) + '-' + pad2(p.d); }
// input type=color takes #rrggbb only
function hex6(c) { return /^#[0-9a-f]{6}$/i.test(c || '') ? c : '#4a6a8a'; }

// a kind the form cannot build gets an option of its own, so an edit
// that leaves the repeat alone keeps it
function keptKindOption(k) {
  var o = kindSel.querySelector('option[data-kept]');
  if (o) o.remove();
  if (!k || FORM_KINDS.indexOf(k) >= 0) return;
  o = document.createElement('option');
  o.value = k; o.dataset.kept = '1';
  o.textContent = k === 'rrule' ? 'As imported (its own rule)' : 'As made (' + k + ')';
  kindSel.appendChild(o);
}

// the color follows the calendar until the user picks one
var colorTouched = false;
var fColor = document.getElementById('f-color');
var fCal = document.getElementById('f-cal');
fColor.addEventListener('input', function() { colorTouched = true; });
fCal.addEventListener('change', function() {
  if (!colorTouched && !(editCtx && editCtx.meta.color)) fColor.value = hex6(calColor(fCal.value));
});

function openModal(opts) {
  opts = opts || {};
  editCtx = null;
  keptKindOption('');
  document.getElementById('modal-title').textContent = 'New Event';
  document.getElementById('edit-scope').classList.remove('on');
  var p = opts.date || parts(Date.now());
  document.getElementById('f-date').value = ymd(p);
  document.getElementById('f-name').value = '';
  document.getElementById('f-note').value = '';
  document.getElementById('f-tags').value = '';
  document.getElementById('f-count').value = 0;
  document.getElementById('f-until').value = '';
  document.getElementById('f-days-n').value = 1;
  document.getElementById('f-dur').value = 60;
  document.getElementById('f-bmonth').value = p.m;
  document.getElementById('f-bday').value = p.d;
  document.getElementById('f-time').value = opts.time || '09:00';
  kindSel.value = opts.kind || 'once';
  document.getElementById('f-period').value = 60;
  document.getElementById('f-day').value = p.d;
  document.getElementById('f-ord').value = 'first';
  document.getElementById('f-month').value = p.m;
  document.getElementById('f-yday').value = p.d;
  var w = WD[(new Date(pserial(p) * MS_DAY).getUTCDay() + 6) % 7];
  daysDiv.querySelectorAll('.day-tog').forEach(function(t) { setTog(t, t.dataset.d === w); });
  dowSel.value = w;
  zoneSel.value = '';
  if (!calReadonly('default')) fCal.value = 'default';
  fColor.value = hex6(calColor(fCal.value));
  colorTouched = false;
  document.getElementById('f-due').value = '';
  document.getElementById('f-done').checked = false;
  document.getElementById('f-status').textContent = '';
  setCat(opts.cat || 'timed');
  back.classList.add('open');
}

function msToUTC(ms) {
  var d = new Date(ms);
  return { y: d.getUTCFullYear(), m: d.getUTCMonth() + 1, d: d.getUTCDate(),
           hh: d.getUTCHours(), mm: d.getUTCMinutes() };
}

function openEdit(d, target) {
  var dm = d.meta || {};
  // what the form does not show rides along untouched: location, the
  // feed a row came from, a rule the form cannot build
  editCtx = { id: d.id, home: d.cal, idx: target.idx, l: target.l, series: isSeries(d), meta: dm,
              args: d.args || {}, count: d.count || 0, before: d.before || 0,
              due_ms: d.due_ms || 0, done_ms: d.done_ms || 0 };
  // the occurrence's wall clock in the event's own frame: all-day in
  // date space, timed in its zone (UTC when it has none)
  editCtx.occ = d.cat === 'allday' ? msToUTC(target.l)
    : parts(target.l, zoneFmt(d.zone && d.zone !== 'none' ? d.zone : 'UTC'));
  document.getElementById('modal-title').textContent = 'Edit Event';
  document.getElementById('f-status').textContent = '';
  document.getElementById('f-name').value = dm.name || '';
  document.getElementById('f-note').value = dm.note || '';
  document.getElementById('f-tags').value = (dm.tags || []).join(', ');
  if (d.cal) fCal.value = d.cal;
  fColor.value = hex6(safeColor(dm.color) || calColor(d.cal));
  colorTouched = false;
  document.getElementById('f-due').value = '';
  document.getElementById('f-done').checked = false;

  // edit scope only for a recurring series, always back on "all"
  document.getElementById('edit-scope').classList.toggle('on', editCtx.series);
  document.querySelector('input[name="scope"][value="all"]').checked = true;

  if (d.cat === 'todo') {
    document.getElementById('modal-title').textContent = 'Edit Task';
    var du = d.due_ms ? dueParts(d.due_ms) : null;
    editCtx.dueDate = du ? ymd(du) : '';
    document.getElementById('f-due').value = editCtx.dueDate;
    document.getElementById('f-done').checked = !!d.done;
    // sane defaults underneath, should the kind be switched to an event
    keptKindOption('');
    kindSel.value = 'once';
    document.getElementById('f-date').value = du ? editCtx.dueDate : ymd(parts(Date.now()));
    document.getElementById('f-time').value = '09:00';
    document.getElementById('f-dur').value = 60;
    document.getElementById('f-days-n').value = 1;
    document.getElementById('f-count').value = 0;
    setCat('todo');
    back.classList.add('open');
    return;
  }
  if (d.cat === 'date') {
    document.getElementById('f-bmonth').value = d.month || 1;
    document.getElementById('f-bday').value = d.day || 1;
    setCat('date');
    back.classList.add('open');
    return;
  }
  // a rule the form can build shows in its fields; any other rides as is
  var shown = d.kind === 'rrule' ? formFromRrule((d.args || {}).rrule) : null;
  var kind = shown ? shown.kind : d.kind;
  keptKindOption(kind);
  kindSel.value = kind;
  var a = shown ? shown.args : (d.args || {});
  var sp = msToUTC(d.start_ms);
  document.getElementById('f-date').value = ymd(sp);
  var atMin = (a.at !== undefined) ? a.at : (sp.hh * 60 + sp.mm);
  document.getElementById('f-time').value = pad2(Math.floor(atMin / 60)) + ':' + pad2(atMin % 60);
  // an event with a fixed end (every single one from Google, CalDAV or
  // an import) shows its length; both ends are wall clock in one zone
  document.getElementById('f-dur').value = d.fin === 'to'
    ? Math.max(0, Math.round((d.end_ms - d.start_ms) / 6e4)) : (d.dur_min || 0);
  document.getElementById('f-days-n').value = d.span_days || 1;
  document.getElementById('f-count').value = d.count || 0;
  document.getElementById('f-until').value = '';
  document.getElementById('f-period').value = a.period || 60;
  document.getElementById('f-day').value = kind === 'monthly' ? (a.day || 1) : 1;
  if (kind === 'monthly-nth') {
    document.getElementById('f-ord').value = a.ord || 'first';
    dowSel.value = a.day || 'mon';
  }
  if (kind === 'yearly') {
    document.getElementById('f-month').value = a.month || 1;
    document.getElementById('f-yday').value = a.day || 1;
  }
  daysDiv.querySelectorAll('.day-tog').forEach(function(t) { setTog(t, (a.days || []).indexOf(t.dataset.d) >= 0); });
  zoneSel.value = d.zone === 'none' ? 'none' : (d.zone || '');
  setCat(d.cat);
  back.classList.add('open');
}

document.getElementById('add-btn').onclick = function() { openModal(); };
// a repeat ends after a count or by a date, not both: setting one clears
// the other
document.getElementById('f-until').addEventListener('input', function(e) { if (e.target.value) document.getElementById('f-count').value = 0; });
document.getElementById('f-count').addEventListener('input', function(e) { if (+e.target.value) document.getElementById('f-until').value = ''; });
document.getElementById('modal-close').onclick = function() { back.classList.remove('open'); };
backdropClose(back, function() { back.classList.remove('open'); });

// an RRULE as the form's own repeat, when it is one the form builds:
// daily, weekly on days, monthly on a day or an nth weekday, yearly on a
// date; COUNT is the count field. ~ (null) for anything else.
var RR_DAY = { MO: 'mon', TU: 'tue', WE: 'wed', TH: 'thu', FR: 'fri', SA: 'sat', SU: 'sun' };
var RR_ORD = { '1': 'first', '2': 'second', '3': 'third', '4': 'fourth', '-1': 'last' };
function formFromRrule(text) {
  var p = {};
  (text || '').split(';').forEach(function(kv) {
    var i = kv.indexOf('='); if (i > 0) p[kv.slice(0, i).toUpperCase()] = kv.slice(i + 1).toUpperCase();
  });
  delete p.COUNT;
  if (p.INTERVAL === '1') delete p.INTERVAL;
  if (p.WKST === 'MO') delete p.WKST;
  var keys = Object.keys(p).sort().join(',');
  if (keys === 'FREQ' && p.FREQ === 'DAILY') return { kind: 'daily', args: {} };
  if (keys === 'BYDAY,FREQ' && p.FREQ === 'WEEKLY') {
    var days = p.BYDAY.split(',').map(function(d) { return RR_DAY[d]; });
    return days.every(Boolean) ? { kind: 'weekly', args: { days: days } } : null;
  }
  if (keys === 'BYMONTHDAY,FREQ' && p.FREQ === 'MONTHLY' && /^([1-9]|[12][0-9]|3[01])$/.test(p.BYMONTHDAY)) {
    return { kind: 'monthly', args: { day: +p.BYMONTHDAY } };
  }
  if (keys === 'BYDAY,FREQ' && p.FREQ === 'MONTHLY') {
    var m = /^(-1|[1-4])(MO|TU|WE|TH|FR|SA|SU)$/.exec(p.BYDAY);
    return m ? { kind: 'monthly-nth', args: { ord: RR_ORD[m[1]], day: RR_DAY[m[2]] } } : null;
  }
  if (keys === 'BYMONTH,BYMONTHDAY,FREQ' && p.FREQ === 'YEARLY' && /^\d+$/.test(p.BYMONTH) && /^\d+$/.test(p.BYMONTHDAY)) {
    return { kind: 'yearly', args: { month: +p.BYMONTH, day: +p.BYMONTHDAY } };
  }
  return null;
}

// the kind-specific args object, keyed the way the kind file reads them
function kindArgs(k, tv) {
  if (FORM_KINDS.indexOf(k) < 0) return (editCtx && editCtx.args) || {};
  var a = {};
  if (k === 'weekly') {
    a.days = [].slice.call(daysDiv.querySelectorAll('.on')).map(function(t) { return t.dataset.d; });
  }
  if (k === 'monthly') a.day = +document.getElementById('f-day').value;
  if (k === 'monthly-nth') {
    a.ord = document.getElementById('f-ord').value;
    a.day = dowSel.value;
  }
  if (k === 'yearly') {
    a.month = +document.getElementById('f-month').value;
    a.day = +document.getElementById('f-yday').value;
  }
  if (k === 'every') a.period = +document.getElementById('f-period').value || 60;
  if (k !== 'once' && k !== 'every') a.at = (+tv[0]) * 60 + (+tv[1]);
  return a;
}

// a number field as a whole number in its min..max, or null with the
// reason in the status line (the ship reads only whole numbers; "2.5"
// or "-1" would quietly be none)
function whole(id) {
  var el = document.getElementById(id);
  var n = Number(el.value);
  var lo = el.min === '' ? 0 : +el.min, hi = el.max === '' ? Infinity : +el.max;
  if (el.value.trim() !== '' && Number.isInteger(n) && n >= lo && n <= hi) return n;
  var lab = document.querySelector('label[for="' + id + '"]');
  document.getElementById('f-status').textContent =
    (lab ? lab.textContent : id) + ': a whole number' + (hi < Infinity ? ' from ' + lo + ' to ' + hi : ' from ' + lo + ' up');
  el.focus();
  return null;
}

var fSave = document.getElementById('f-save');
fSave.onclick = function() {
  if (fSave.disabled) return;
  var st = document.getElementById('f-status');
  var name = document.getElementById('f-name').value.trim();
  if (!name) { st.textContent = 'name required'; return; }
  // the event's meta as it was, with what the form shows written over
  var meta = Object.assign({}, editCtx ? editCtx.meta : {},
    { name: name, note: document.getElementById('f-note').value });
  if (!meta.note) delete meta.note;
  var tags = parseTags(document.getElementById('f-tags').value);
  if (tags.length) meta.tags = tags; else delete meta.tags;
  if (colorTouched) meta.color = fColor.value;
  var body = { action: 'add-event', cat: cat, meta: meta };
  if (fCal.value) body.cal = fCal.value;

  if (cat === 'todo') {
    var duv = document.getElementById('f-due').value;
    // an untouched date keeps the due moment it came with, time and all
    if (editCtx && editCtx.due_ms && duv === editCtx.dueDate) body.due_ms = editCtx.due_ms;
    else if (duv) { var dp = duv.split('-'); body.due_ms = Date.UTC(+dp[0], +dp[1] - 1, +dp[2]); }
    if (document.getElementById('f-done').checked) body.done_ms = (editCtx && editCtx.done_ms) || Date.now();
  } else if (cat === 'date') {
    body.month = +document.getElementById('f-bmonth').value;
    body.day = whole('f-bday');
    if (body.day === null) return;
  } else {
    var k = kindSel.value;
    var dv = document.getElementById('f-date').value;
    if (!dv) { st.textContent = 'date required'; return; }
    var p = dv.split('-');
    var tv = (document.getElementById('f-time').value || '00:00').split(':');
    body.kind = k;
    body.start_ms = (cat === 'timed' && timedStart(k))
      ? Date.UTC(+p[0], +p[1] - 1, +p[2], +tv[0], +tv[1])
      : Date.UTC(+p[0], +p[1] - 1, +p[2]);
    var need = { monthly: 'f-day', yearly: 'f-yday', every: 'f-period' }[k];
    if (need && whole(need) === null) return;
    body.args = kindArgs(k, tv);
    if (k === 'weekly' && !body.args.days.length) { st.textContent = 'pick weekdays'; return; }
    if (cat === 'timed') {
      var zone = zoneSel.value;
      if (zone) body.zone = zone;
      body.fin = 'dur';
      body.dur_min = whole('f-dur');
      if (body.dur_min === null) return;
    } else {
      body.span_days = whole('f-days-n');
      if (body.span_days === null) return;
    }
    if (k !== 'once') {
      var cnt = whole('f-count');
      if (cnt === null) return;
      var uv = document.getElementById('f-until').value;
      if (cnt > 0 && !uv) body.count = cnt;
      if (uv) {
        var up = uv.split('-');
        // the last moment of that day: the server keeps what starts on
        // or before it
        body.until_ms = Date.UTC(+up[0], +up[1] - 1, +up[2] + 1) - 1;
      }
    }
  }

  fSave.disabled = true;
  var finish = function(ok) {
    fSave.disabled = false;
    if (!ok) { st.textContent = 'save failed'; return; }
    st.textContent = '';
    back.classList.remove('open');
    setTimeout(refresh, 400);
  };

  if (!editCtx) { poke(body, finish); return; }

  var scopeEl = document.querySelector('input[name="scope"]:checked');
  var scope = (editCtx.series && scopeEl) ? scopeEl.value : 'all';
  // the first occurrence and all that follow is the whole series
  if (scope === 'following' && !editCtx.idx) scope = 'all';
  var o = editCtx.occ;

  if (scope === 'all') {
    body.action = 'edit-event';
    body.id = editCtx.id;
    body.home = editCtx.home;
    poke(body, finish);
  } else if (scope === 'following') {
    // one action on the ship: the old series ends before this occurrence
    // and a new one starts on it, keeping the skips that fall after. An
    // unchanged count is the old one's rest.
    body.action = 'split-event';
    body.id = editCtx.id;
    body.home = editCtx.home;
    body.idx = editCtx.idx;
    body.start_ms = (cat === 'timed' && timedStart(k))
      ? Date.UTC(o.y, o.m - 1, o.d, +tv[0], +tv[1])
      : Date.UTC(o.y, o.m - 1, o.d);
    if (body.count && body.count === editCtx.count) body.count = Math.max(1, body.count - editCtx.before);
    poke(body, finish);
  } else {
    // only this one: a one-off on this occurrence's day, at the form's
    // time, then the occurrence skipped by its start
    var only = { action: 'add-event', cat: cat, meta: body.meta, kind: 'once' };
    if (body.cal) only.cal = body.cal;
    if (cat === 'timed') {
      only.start_ms = Date.UTC(o.y, o.m - 1, o.d, +tv[0], +tv[1]);
      if (body.zone) only.zone = body.zone;
      only.fin = 'dur'; only.dur_min = body.dur_min;
    } else {
      only.start_ms = Date.UTC(o.y, o.m - 1, o.d);
      only.span_days = body.span_days || 1;
    }
    var skip = { action: 'skip-at', id: editCtx.id, home: editCtx.home, start_ms: editCtx.l };
    poke(only, function(ok) {
      if (!ok) { finish(false); return; }
      poke(skip, finish);
    });
  }
};

// ---- boot ---------------------------------------------------------

function boot() {
  mkfmt();
  var q = new URLSearchParams(location.search);
  var v = q.get('view');
  var dt = (q.get('date') || '').split('-');
  if (v === 'month' || v === 'week' || v === 'day' || v === 'tasks') state.view = v;
  loadTags();
  if (dt.length === 3 && +dt[0] > 1970 && +dt[1] >= 1 && +dt[1] <= 12 && +dt[2] >= 1 && +dt[2] <= 31) {
    state.y = +dt[0]; state.m = +dt[1]; state.d = +dt[2];
    load();
    return;
  }
  goToday();
}

getJSON('/config.json')
  .then(function(cfg) {
    CFG.zone = cfg.zone || '';
    CFG.ball = cfg.ball || '';
    CFG.ship = cfg.ship || '';
    CFG.title = cfg.title || 'Calendar';
    document.title = CFG.title;
    loadZones();
    loadCals();
    boot();
  })
  .catch(boot);
