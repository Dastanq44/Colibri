# Manual QA checklist (plan §15.5)

Run before each beta build. Automated coverage first — everything it already
protects is marked; the rest needs hands on devices.

## Automated (green as of 2026-07-08)

- [x] Unit suite: `flutter test` (237 tests — tokenizer, WPM, progress,
      sync, migrations, search, rails, sessions)
- [x] Core loop integration test on a simulator:
      `flutter test integration_test -d <device>` — open → page → rotate →
      fast mode → +25 WPM → rotate back → exit → resume
- [x] Live backend smoke: `flutter test test/e2e/live_sync_smoke_test.dart`
      (requires `.env.dev`; signs in and round-trips book/note/bookmark)
- [ ] Maestro flows: `maestro test maestro/flows` — **CLI not installed on
      this machine**; install with
      `curl -Ls https://get.maestro.mobile.dev | bash`, then see
      `maestro/README.md`

## Devices

Test on at least: small Android phone, mid-range Android phone, iPhone
SE-size, modern iPhone. Tablet if available.

## Reading loop (per device)

- [ ] Import an EPUB, a TXT, and a PDF via Home → Import book
- [ ] Unsupported file (e.g. .docx) shows a clear error, no crash
- [ ] Corrupted EPUB (rename a .zip) shows the malformed-book message
- [ ] Large file (>50 MB) imports or fails gracefully per the size limit
- [ ] Open each format; PDF opens in the page viewer
- [ ] Tap left/right pages backward/forward; progress bar updates
- [ ] Kill the app mid-book; reopen → resumes at the same position
- [ ] Rotate to landscape → fast mode from the same position (starts paused)
- [ ] Center tap = play/pause; right/left tap = ±25 WPM with feedback
- [ ] Set WPM to bounds (150 / 700); steps stop at the limits
- [ ] Rotate back → portrait position matches (± one page)
- [ ] Wiggle the phone near-horizontal: no rapid mode flapping
- [ ] Mode lock on → rotation does nothing, in both modes; persists relaunch
- [ ] PDF in landscape stays in the page viewer (no fast mode)

## Rotation edge cases

- [ ] Rotate while the reader menu / settings sheet / search sheet is open
- [ ] Rotate during page-turn animation
- [ ] System orientation lock ON: app respects it
- [ ] Rotate on Home/Catalog/Library: layout adapts, no mode switching

## Offline

- [ ] Airplane mode: import, read, annotate, change settings — all work
- [ ] Catalog shows the offline message with Retry
- [ ] Sign in later → queued changes sync (check pending counter in Profile)

## Accessibility & display

- [ ] System text at maximum: all screens usable, no clipped controls
- [ ] Dark mode + reader themes (light/sepia/dark) readable
- [ ] Reduce motion (system + in-app): page turns swap instantly
- [ ] VoiceOver/TalkBack: reader tap zones, WPM controls, progress announced
- [ ] Readability profiles apply and stay editable

## App lifecycle

- [ ] Background the app while fast mode plays → resumes paused
- [ ] Incoming call / notification interruption mid-reading: position kept
- [ ] Low-storage device: import fails with a message, no crash

## Sync & account

- [ ] Sign up, sign out, sign in on a second device/simulator: progress,
      notes, bookmarks appear; a farther cloud position offers the
      two-positions dialog
- [ ] Books added from Catalog appear in My Books after refresh
- [ ] Remove a local book: gone locally, cloud copy untouched
