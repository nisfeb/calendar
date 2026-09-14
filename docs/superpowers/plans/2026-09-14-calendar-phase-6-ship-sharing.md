# Calendar phase 6: sharing a calendar with a ship

**Goal:** "Share this calendar with ~sampel-palnet", read or edit, using the ship's identity and the weir — no password, no nginx, between any two ships that run the calendar desk.

**Architecture:** The host keeps a derived, per-calendar share file `shares/<id>.json` (`{seq, objects: {uid: {etag, ics}}}`), rebuilt by the sync fiber whenever that calendar's seq moves. Sharing with a ship puts the ship in a usergroup `cal-<id>` whose weir grants peek on that file and, for edit, poke on `calendar.calendar`; the host's poke handler takes the sender from the transport and lets a foreign ship act only on calendars shared with it in edit mode, through `share-put` / `share-del` actions carrying ICS. The host tells the other ship with a remote poke to its calendar's `shares.sig` inbox (a poke road any ship holds through `/public`, as lattice does for share notices); the offer waits in `share-offers.json` until the owner accepts it. Accepting makes a calendar of kind `%ship` and a row in `ship-remotes.json` with the same watermark and suppression machinery the CalDAV follow uses. The sync fiber's pass pulls the host's share file with a remote peek and diffs etags, and pushes local changes as remote pokes. The host wins conflicts, as every remote does.

**Spec:** an addition to section 5; this plan is its argument.

## Global Constraints
- No model change beyond `cal-props.kind` growing `%ship`.
- New roads in the ask: poke `/sys/gall/` (remote pokes), poke `/sys/ames/registry`, make+poke `/sys/ames/usergroups/`, peek `/sys/ames/usergroups/` and `/sys/ames/ships/`. All refusable; refusing them disables sharing only.
- A foreign ship's poke is trusted for its identity only; its payload is data.
- Rehearsed wex ↔ feb over ames before commit. Version 10 at the end.

### Task 1: host side — share files, groups, offers, the inbox
### Task 2: peer side — offers, accept, the `%ship` pull and push
### Task 3: settings screen — Share…, shared-with lists, Shared with you
### Task 4: gate `scripts/ship-share-matrix.py` (wex shares with feb, both modes, both directions, revoke), docs, version 10
