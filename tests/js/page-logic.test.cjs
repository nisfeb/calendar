// No browser needed: the page's pure helpers, run from calendar.js as
// shipped. The top of the file (before the shared chrome) touches no DOM.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require('node:path').join(__dirname, '../../code/nex/calendar/calendar.js'), 'utf8');
const context = vm.createContext({ Intl, Date, Math });
vm.runInContext(source.slice(0, source.indexOf('// ---- shared chrome')), context);
vm.runInContext(source.slice(source.indexOf('// quick-add:'), source.indexOf('window.parseQuickTask')), context);
const c = context;
const plain = x => JSON.parse(JSON.stringify(x));

test('only the ship\'s flag makes an event all-day', () => {
  assert.equal(c.isAllDay({ all: true, l: 0, r: 864e5 }), true);
  assert.equal(c.isAllDay({ all: false, l: 0, r: 25 * 36e5 }), false);
  assert.equal(c.isAllDay({ l: 0, r: 3 * 864e5 }), false);
});

test('guests keep only objects, from a list', () => {
  assert.deepEqual(plain(c.objs([null, { ship: '~zod' }, 'x', 3])), [{ ship: '~zod' }]);
  assert.deepEqual(plain(c.objs('~zod')), []);
  assert.deepEqual(plain(c.objs(undefined)), []);
});

test('quick-add leaves names and plain words alone', () => {
  const today = c.serial(2026, 10, 17);   // a Saturday
  const q = text => plain(c.parseQuickTask(text, today));
  assert.deepEqual(q('Call Tom'), { name: 'Call Tom', due: null, tags: [], priority: 0 });
  assert.equal(q('Call Tod').name, 'Call Tod');
  assert.equal(q('Go to the sun').due, null);
  assert.equal(q('Where we sat').due, null);
  assert.equal(q('Pay rent tomorrow').due, today + 1);
  assert.equal(q('Pay rent tmr').name, 'Pay rent');
  assert.equal(q('Pay rent today').due, today);
  assert.equal(q('Pay rent sunday').due, today + 1);
  assert.equal(q('Pay rent fri').due, today + 6);
  assert.deepEqual(q('Book flights oct 20 #travel !high'), { name: 'Book flights', due: c.serial(2026, 10, 20), tags: ['travel'], priority: 1 });
});

test('chip text is dark on a light color and white on a dark one', () => {
  assert.equal(c.ink('#fbd75b'), '#111');   // Google's banana
  assert.equal(c.ink('#ffffff'), '#111');
  assert.equal(c.ink('#fff'), '#111');
  assert.equal(c.ink('#4a6a8a'), '#fff');   // the default slate
  assert.equal(c.ink('#101541'), '#fff');
  assert.equal(c.ink('#7bd148cc'), '#111');
  assert.equal(c.ink('red; color: x'), '#fff');
});

test('a call taken off drops the join line the ship wrote, and only that', () => {
  const url = 'https://ship.example/apps/trunk/call/e-1a2b';
  const line = 'Join the call in any browser: ' + url;
  assert.equal(c.dropJoinLine(line), '');
  assert.equal(c.dropJoinLine('Agenda\n\n' + line), 'Agenda');
  assert.equal(c.dropJoinLine('Agenda\r\n\r\n' + line), 'Agenda');
  assert.equal(c.dropJoinLine('Agenda\n\n' + line + '\n\nBring notes'), 'Agenda\n\nBring notes');
  assert.equal(c.dropJoinLine(line + '\n\nBring notes'), 'Bring notes');
  assert.equal(c.dropJoinLine('Agenda\n\n' + line + '\n\n' + line.replace('1a2b', '9f')), 'Agenda');
  assert.equal(c.dropJoinLine('Join the call in any browser: soon'), 'Join the call in any browser: soon');
  assert.equal(c.dropJoinLine('See ' + line), 'See ' + line);
  assert.equal(c.dropJoinLine(undefined), '');
});

test('a link or address in angle brackets stays in a plain note', () => {
  assert.equal(c.noteText('Join Microsoft Teams Meeting<https://teams.microsoft.com/l/x>'), 'Join Microsoft Teams Meeting https://teams.microsoft.com/l/x');
  assert.equal(c.noteText('Ask Bo <bo@x.test>'), 'Ask Bo  bo@x.test');
  assert.equal(c.noteText('plain'), 'plain');
});

test('a word in angle brackets is not a tag', () => {
  assert.equal(c.noteText('Bring <snacks> and drinks'), 'Bring <snacks> and drinks');
});
