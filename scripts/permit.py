#!/usr/bin/env python3
"""permit.py: the calendar instance's permits and health, for the shell gates.

usage: permit.py <base-url> <cookie-jar> grant|refuse <poke|peek|make> <road>
       permit.py <base-url> <cookie-jar> grant-all
       permit.py <base-url> <cookie-jar> reload
       permit.py <base-url> <cookie-jar> banged

grant and refuse change one road of the instance's weir. The kernel's
sand API reads every road back as a fold, so this goes through the
shell's consent instead: POST /apps/grubbery/permits approve-weir, with
`granted` the roads the weir holds now (GET /grubbery/api/peek/<data>?as=weirs,
spelled as in the app's weir.json), plus or minus the one. grant-all grants
the app's whole weir.json. reload is POST /apps/grubbery/permits/reload.
banged prints the paths banged under the instance (GET /grubbery/api/bang),
or "unreadable". Exits 1 when the ship does not take a step.
"""
import json, subprocess, sys
import kernel


def curl(base, jar, path, body=None):
    cmd = ['curl', '-s', '-m', '120', '-b', jar, '-w', '\n%{http_code}', base + path]
    if body is not None:
        cmd += ['-X', 'POST', '-H', 'content-type: application/json', '-d', json.dumps(body)]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    text, _, code = out.rpartition('\n')
    return int(code or 0), text


def main():
    base, jar, op = sys.argv[1].rstrip('/'), sys.argv[2], sys.argv[3]
    app = kernel.app(base, jar)
    if op == 'reload':
        st, _ = curl(base, jar, '/apps/grubbery/permits/reload', {'app': app})
        sys.exit(st != 200)
    if op == 'banged':
        st, out = curl(base, jar, '/grubbery/api/bang' + app + '/')
        try:
            print(' '.join(sorted(h['where'] for h in json.loads(out)['hits'])) if st == 200 else 'unreadable')
        except (ValueError, KeyError):
            print('unreadable')
        return
    st, ask = curl(base, jar, '/grubbery/api/peek' + app + '/weir.json')
    if st != 200:
        sys.exit(f'permit: no {app}/weir.json ({st})')
    ask = json.loads(ask)
    if op == 'grant-all':
        granted = ask
    else:
        kind, road = sys.argv[4], sys.argv[5]
        data, name = app.rsplit('/', 1)
        st, out = curl(base, jar, '/grubbery/api/peek' + data + '?as=weirs')
        held = json.loads(out)['dirs'].get(name, {}).get('weir', {}) if st == 200 else {}
        granted = {}
        for k in ('poke', 'peek', 'make'):
            have = {r.rstrip('/') for r in held.get(k, [])}
            granted[k] = [a for a in ask.get(k, []) if a['road'].rstrip('/') in have]
            if k == kind:
                granted[k] = [a for a in granted[k] if a['road'] != road]
                if op == 'grant':
                    granted[k] += [a for a in ask.get(k, []) if a['road'] == road] or [{'road': road}]
    body = {'action': 'approve-weir', 'app': app, 'picks': {}, 'granted': granted}
    st, out = curl(base, jar, '/apps/grubbery/permits', body)
    if st not in (200, 303):
        sys.exit(f'permit: approve-weir {st} {out[:200]}')


if __name__ == '__main__':
    main()
