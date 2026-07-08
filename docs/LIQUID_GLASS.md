# Liquid Glass variant

This branch (`liquid-glass`) reskins the app chrome to a neutral, Apple
**Liquid Glass**-inspired design: a white / dark-grey monochrome palette with
frosted, refractive glass surfaces. It is a design variant of the same app —
all features and logic are identical to `main`.

## What changed (chrome only)

- **Palette** (`lib/app/theme/app_colors.dart`): brand blue replaced by a
  neutral Apple-grey scale — light `#F2F2F7` / white surfaces, dark
  `#000`/`#1C1C1E`, graphite accent. Glass takes its colour from content, so
  the base is monochrome by design.
- **Theme** (`lib/app/theme/app_theme.dart`): hand-built neutral
  `ColorScheme`; translucent app bars, rounded (22–28px) translucent cards,
  sheets, and dialogs; softer buttons.
- **Glass components** (`lib/app/widgets/glass.dart`):
  - `GlassSurface` — frosted panel via Flutter's own `BackdropFilter`
    (cheap, everywhere). Used for broad chrome.
  - `GlassPanel` — the real Liquid Glass shader (refraction/lensing) via the
    `liquid_glass_renderer` package. Used for hero chrome only.
- **Floating glass tab bar** (`lib/app/router/app_shell.dart`): the four-tab
  bar is now a floating `GlassPanel`; `extendBody` lets content flow behind so
  the bar refracts it.

The reading surface keeps its own light/sepia/dark `ReaderPalette` (glass
would hurt legibility).

## Dependency

- `liquid_glass_renderer` (pre-1.0, shader-based; needs Impeller — default on
  iOS). Verified rendering + building on the iOS simulator.

## Known refinements (not yet done on this branch)

- Long lists (Catalog / My Books) may need extra bottom padding so their last
  item isn't covered by the floating tab bar (`extendBody`).
- App-bar backdrops are translucent but not yet blurred per-screen; a
  `GlassSurface` `flexibleSpace` could frost them fully.
- Reader bottom bars and in-reader sheets could adopt `GlassSurface`.

## Running

```sh
git checkout liquid-glass
flutter run --dart-define-from-file=.env.dev
```
