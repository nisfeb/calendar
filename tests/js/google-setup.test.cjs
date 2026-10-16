// No browser or Google account needed: exercise the exact setup helpers
// and click handlers shipped in calendar.js with an in-memory page/API.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require('node:path').join(__dirname, '../../code/nex/calendar/calendar.js'), 'utf8');
const origin = 'https://ship.example';
const callback = origin + '/apps/calendar/google/callback';
const id = '123-example.apps.googleusercontent.com';
const secret = 'example-secret-for-tests';
const file = (overrides = {}) => JSON.stringify({ web: {
  client_id: id, client_secret: secret, redirect_uris: [callback], ...overrides,
} });

function harness(status = 200) {
  const elements = new Map();
  const requests = [];
  const context = vm.createContext({
    URL, URLSearchParams, Promise, console,
    location: { origin, search: '', hash: '', href: origin + '/apps/calendar' },
    document: { getElementById: key => {
      if (!elements.has(key)) elements.set(key, { value: '', textContent: '', disabled: false });
      return elements.get(key);
    } },
    window: { addEventListener() {} },
    confirm: () => true,
    CAL: '/apps/calendar',
    postJSON: async (path, body) => { requests.push({path, body}); return {ok: status === 200, status}; },
    busy: (button, promise) => { button.disabled = true; promise.then(() => { button.disabled = false; }, () => { button.disabled = false; }); return promise; },
    loadGoogle() {},
  });
  vm.runInContext(source.slice(source.indexOf('var GoogleSetup ='), source.indexOf('function loadGoogle()')), context);
  vm.runInContext(source.slice(source.indexOf("document.getElementById('google-save').onclick"), source.indexOf('// the settings screen:')), context);
  return { context, requests, element: key => context.document.getElementById(key), setup: context.GoogleSetup };
}

test('imports a Web client only with the exact callback and discards endpoints', () => {
  const {setup} = harness();
  const result = setup.importClient(file({token_uri: 'https://untrusted.example/token', auth_uri: 'https://untrusted.example/auth'}), origin);
  assert.deepEqual(JSON.parse(JSON.stringify(result)), {client_id: id, client_secret: secret});
  for (const uri of [callback + '/', callback.replace('https:', 'http:'), origin, callback.replace('ship.example', 'other.example')]) {
    assert.throws(() => setup.importClient(file({redirect_uris: [uri]}), origin), /exact redirect URI/);
  }
});

test('rejects malformed, desktop, service-account and incomplete files without echoing secrets', () => {
  const {setup} = harness();
  for (const text of ['{ secret-token', 'null', '[]', JSON.stringify({installed: {client_id: id}}), JSON.stringify({type: 'service_account'}), file({client_secret: null}), file({client_secret: ''}), file({client_id: 'bad-id'}), file({redirect_uris: callback})]) {
    assert.throws(() => setup.importClient(text, origin), error => !error.message.includes('secret-token') && !error.message.includes(secret));
  }
});

test('requires public HTTPS, with HTTP exceptions only for literal loopback hosts', () => {
  const {setup} = harness();
  for (const host of ['http://localhost:8080', 'http://127.0.0.1:8121', 'http://[::1]:8080', origin]) {
    assert.equal(setup.redirect(host), host + '/apps/calendar/google/callback');
  }
  for (const host of ['http://ship.example', 'http://localhost.example', 'https://ship.example/', 'https://ship.example/path', 'https://user:pass@ship.example', 'file:///tmp/calendar.html']) {
    assert.throws(() => setup.redirect(host), /HTTPS/);
  }
});

test('a masked saved secret is usable only for the same client', () => {
  const {setup} = harness();
  const saved = {client_id: id, client_secret: '••••••••'};
  assert.doesNotThrow(() => setup.validate(id, '', saved));
  assert.doesNotThrow(() => setup.validate('456-other.apps.googleusercontent.com', secret, saved));
  assert.throws(() => setup.validate('456-other.apps.googleusercontent.com', '', saved), /same client ID/);
  assert.throws(() => setup.validate(id, '', null), /secret/);
});

const settled = () => new Promise(resolve => setImmediate(resolve));
function prepare(h) {
  h.context.googleSettings = {client_id: id, client_secret: '••••••••', connected: false};
  h.element('google-cid').value = id;
}

test('Connect refuses an unknown configuration or mismatched saved secret before sending', async () => {
  const h = harness();
  h.element('google-connect').onclick();
  assert.equal(h.requests.length, 0);
  assert.match(h.element('google-msg').textContent, /not loaded/);
  prepare(h);
  h.element('google-cid').value = '456-other.apps.googleusercontent.com';
  h.element('google-connect').onclick();
  assert.equal(h.requests.length, 0);
});

test('failed Save never navigates to OAuth or reports success', async () => {
  const h = harness(403);
  prepare(h);
  const before = h.context.location.href;
  h.element('google-connect').onclick();
  await settled();
  assert.equal(h.context.location.href, before);
  assert.match(h.element('google-msg').textContent, /Could not save.*403/);
  assert.equal(h.element('google-connect').disabled, false);
});

test('Connect saves the displayed origin before navigation and clears typed secret', async () => {
  const h = harness();
  prepare(h);
  h.element('google-csec').value = secret;
  h.element('google-connect').onclick();
  assert.equal(h.element('google-connect').disabled, true);
  await settled();
  assert.equal(h.requests[0].path, '/google/config');
  assert.equal(h.requests[0].body.origin, origin);
  assert.equal(h.context.location.href, '/apps/calendar/google/connect');
  assert.equal(h.element('google-csec').value, '');
});

test('cancelling replacement of a connected account sends nothing', () => {
  const h = harness();
  prepare(h);
  h.context.googleSettings.connected = true;
  h.context.confirm = () => false;
  h.element('google-connect').onclick();
  assert.equal(h.requests.length, 0);
});

test('refresh retries a connected calendar list without saving credentials or starting OAuth', () => {
  const h = harness();
  prepare(h);
  h.context.googleSettings.connected = true;
  h.context.googleSettings.linked = {example: {last_ms: 123}};
  const before = h.context.location.href;
  let refreshed;
  h.context.loadGoogleCalendars = linked => { refreshed = linked; };
  h.element('google-csec').value = 'unsaved-secret';
  h.element('google-refresh').onclick();
  assert.equal(refreshed, h.context.googleSettings.linked);
  assert.equal(h.requests.length, 0);
  assert.equal(h.context.location.href, before);
  assert.equal(h.element('google-csec').value, 'unsaved-secret');
});

test('refresh waits for an existing authorization', () => {
  const h = harness();
  h.context.loadGoogleCalendars = () => { assert.fail('must not list without authorization'); };
  h.element('google-refresh').onclick();
  prepare(h);
  h.element('google-refresh').onclick();
  assert.equal(h.requests.length, 0);
  assert.match(h.element('google-msg').textContent, /Connect to Google/);
});
