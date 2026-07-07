# Maestro E2E flows

End-to-end flows for the core reading loop (plan §15.4 / TASK-1604).

## Setup

1. Install Maestro (>= 1.36, needed for `setOrientation`):
   `curl -Ls https://get.maestro.mobile.dev | bash`
2. Boot a simulator/emulator and install a debug build:
   `flutter run` (or `flutter build ios --simulator` + install), then quit
   the `flutter run` session — Maestro drives the installed app itself.
3. **Locale**: flows match English UI strings. Set the device language to
   English before running.

## Preconditions

- `onboarding_first_launch.yaml` clears app state itself — run it first or
  standalone.
- The reader flows (`rotate_to_fast_mode`, `change_wpm`,
  `create_note_bookmark`, `change_book_status`) assume **at least one TXT or
  EPUB book has been imported and opened once** (so it appears under
  Continue Reading). Import automation is not scripted: the system file
  picker cannot be driven reliably across platforms, so import one book
  manually (Home → Import book) before running them.

## Running

```sh
maestro test maestro/flows/onboarding_first_launch.yaml   # single flow
maestro test maestro/flows                                # whole suite
```

## Flows

| Flow | Covers |
| --- | --- |
| `onboarding_first_launch.yaml` | fresh install → 3 onboarding pages → Home empty state |
| `rotate_to_fast_mode.yaml` | open book → rotate → fast mode → rotate back → reader |
| `change_wpm.yaml` | fast-mode tap zones change WPM (+25/−25) |
| `create_note_bookmark.yaml` | add bookmark + note from the reader menu, list them |
| `change_book_status.yaml` | My Books card menu → mark finished → Finished tab |

Flows from the plan that need not-yet-built features (reviews, offline
reconnect indicators) or account credentials (signup/delete) are added with
those phases.
