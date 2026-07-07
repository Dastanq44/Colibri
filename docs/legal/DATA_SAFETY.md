# Store data-safety declarations (draft)

Source of truth for Google Play's Data safety form and the App Store
privacy "nutrition label". Matches the code as of 2026-07-08 — re-audit
before each submission.

## Collected & linked to identity (account users only)

| Category | Data | Purpose | Optional? |
| --- | --- | --- | --- |
| Contact info | Email address | Account/auth | Yes (sign-in is optional) |
| User content | Notes, bookmarks, selected passages | App functionality (sync) | Yes |
| User content | Imported book files | App functionality (private sync) | Yes |
| App activity | Reading positions, shelf statuses, goals | App functionality (sync) | Yes |

## Collected, not linked to identity

| Category | Data | Purpose |
| --- | --- | --- |
| App info & performance | Crash logs, diagnostics (Sentry) | Stability |
| App activity | Anonymous usage events (screens, reader actions, imports) | Analytics |

## Not collected

Location, contacts, photos, financial data, browsing history, identifiers
for advertising. No ads, no data sold, no third-party marketing sharing.

## Security & deletion

- Data in transit: TLS. Cloud rows: per-user row-level security.
- In-app account deletion: Profile → delete account (server-side cascade,
  including private book files).

## Play form quick answers

- Does your app collect or share user data? **Collects** (see above); no sharing beyond processors.
- Is all user data encrypted in transit? **Yes.**
- Do you provide a way to request deletion? **Yes, in-app.**

## App Store quick answers

- Data Used to Track You: **None.**
- Data Linked to You: Contact Info (email), User Content, App Activity.
- Data Not Linked to You: Diagnostics, Usage Data.
