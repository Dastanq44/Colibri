# Colibri Privacy Policy

_Last updated: 2026-07-08. Draft for closed beta — review before public
release, and host at a public URL for the store listings._

## Summary

Colibri is a reading app. Your books and reading activity stay on your
device unless you create an account and enable sync. We never sell data and
never read the contents of your books for any purpose other than showing
them to you.

## Data stored only on your device

- Imported book files (EPUB, TXT, PDF) and extracted covers
- Reading positions, notes, bookmarks, reading sessions, and settings

Deleting the app deletes all of this.

## Data stored in the cloud (only with an account)

When you sign in, the following syncs to our backend (Supabase):

- Account: email address and authentication data
- Profile: display name, locale, reading goals
- Library: which books are on your shelf and their statuses
- Reading positions, notes, and bookmarks (including the text you type in
  notes and short selected passages they attach to)
- Book files you imported, stored privately so only you can access them

Cloud data is protected by row-level security: each account can access only
its own records. Catalog metadata (public-domain titles) is public.

## Crash reporting and analytics

- Crash reports (Sentry): stack traces, app version, OS and device model.
  No book content, note text, or file contents are included.
- Product analytics (when enabled): anonymous usage events such as
  "book opened", "reading mode changed", "words-per-minute changed",
  screen views, and import success/failure. Events never include book
  text, note content, titles of your imported books, or file contents.

## Data deletion

You can delete your account from Profile → account settings. This removes
your authentication record and all cloud rows and private files associated
with your account. Local data is removed by deleting the app.

## Sharing

We do not sell or share personal data with third parties, except the
processors that operate the service: Supabase (database, auth, storage),
Sentry (crash reporting), and the analytics provider named in the app
listing. Each receives only the categories described above.

## Contact

Questions or deletion requests: <SUPPORT_EMAIL — fill in before release>.
