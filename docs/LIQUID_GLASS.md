# Liquid Glass variant

This branch (`liquid-glass`) reskins the app chrome to a warm-paper, Apple /
iOS-styled design: an off-white "paper" palette with a terracotta accent,
iOS-scale typography and large titles, plus a real native Liquid Glass tab
bar. It is a design variant of the same app — all features and logic are
identical to `main`.

## Official Apple Liquid Glass vs. Flutter (important)

Apple's real Liquid Glass (iOS 26) is applied in SwiftUI with the
`.glassEffect()` modifier (and the UIKit `UIGlassEffect` / updated
`UITabBar` etc.). These are **native, system-drawn materials**. Flutter draws
its own UI on a Skia/Impeller canvas, so:

- **`.glassEffect()` cannot be called on Flutter-drawn widgets.** It only
  exists inside SwiftUI/UIKit. The Flutter team has said they are **not**
  adding Liquid Glass to the Cupertino library
  (github.com/flutter/flutter/issues/170310) — Flutter reproduces Apple's look
  in its own paint code rather than calling the system material.
- The only way to get the **genuine** Apple Liquid Glass in a Flutter app is a
  **platform view** that embeds a native UIKit/SwiftUI control. The native
  control is drawn by iOS itself, so on iOS 26 it gets true Liquid Glass.

This branch therefore uses **two** layers:

1. **Real native glass where a native control exists** — the bottom tab bar is
   a native `UITabBar` embedded via the `cupertino_native` package
   (`CNTabBar`). On iOS 26 this renders Apple's actual Liquid Glass tab bar
   (the floating bar + capsule selection pill), which Flutter's canvas cannot
   reproduce. See `lib/app/router/app_shell.dart`.
2. **A Flutter approximation everywhere else** — cards, sheets, dialogs and
   app bars use `BackdropFilter` frost (`GlassSurface`) and a shader
   refraction (`GlassPanel`), because those surfaces are Flutter-drawn and have
   no native equivalent to embed.

## What changed (chrome only)

The chrome is a warm-paper, Apple-styled skin (an evolution of the earlier
neutral-grey Liquid Glass base):

- **Palette** (`lib/app/theme/app_colors.dart`): a warm off-white "paper"
  scale — light background `#EFE7D9` / surfaces `#FFFDF9`, warm ink `#2A2620`
  — with a single terracotta accent (`#B4703C`, lighter `#E0925C` on dark).
  A matching warm near-black dark scale (`#16130D` / `#211D16`).
- **Typography** (`lib/app/theme/app_text_styles.dart`): reshaped to the iOS /
  SF Pro hierarchy — heavy, slightly tightened large titles down to a calm
  17pt body.
- **Large titles** (`lib/app/widgets/large_title_scaffold.dart`): Home and
  Profile use an iOS large navigation title (big + left-aligned, collapsing to
  a small toolbar title on scroll).
- **Theme** (`lib/app/theme/app_theme.dart`): warm `ColorScheme`; flat app
  bars that blend with the grouped background; borderless rounded (18px) paper
  cards; filled rounded inputs; tonal quick-action tiles; terracotta switches,
  progress bars and segmented buttons; no ink ripple (iOS-style taps).
- **Native tab bar** (`lib/app/router/app_shell.dart`): on iOS the four-tab
  bar is a real native `CNTabBar` (Liquid Glass on iOS 26), driven by SF
  Symbols (`house`, `safari`, `books.vertical`, `person`); its `onTap` bridges
  to go_router's `navigationShell.goBranch`. Non-iOS platforms fall back to a
  Material `NavigationBar`. `extendBody` lets content flow behind the bar.
- **Glass components** (`lib/app/widgets/glass.dart`):
  - `GlassSurface` — frosted panel via Flutter's own `BackdropFilter`
    (cheap, everywhere). Used for broad chrome.
  - `GlassPanel` — a Liquid Glass shader (refraction/lensing) via the
    `liquid_glass_renderer` package, for Flutter-drawn hero chrome only. Note
    this is an *approximation*, not the system material.

The reading surface keeps its own light/sepia/dark `ReaderPalette` (glass
would hurt legibility).

## Dependencies

- `cupertino_native` (^0.1.1) — embeds native Cupertino controls (incl.
  `CNTabBar`) via platform views. This is the path to **real** Apple Liquid
  Glass. Requires **iOS 14+** (the app's deployment target was raised
  13.0 → 14.0 for it) and builds with a recent Xcode. It is an early
  (proof-of-concept) package, so the Material `NavigationBar` fallback is kept
  for safety and for non-iOS platforms.
- `liquid_glass_renderer` (pre-1.0, shader-based; needs Impeller — default on
  iOS) — the Flutter-side approximation for surfaces with no native control.

Verified building + rendering the native `CNTabBar` on the iOS 26 simulator.

## Known refinements (not yet done on this branch)

- Long lists (Catalog / My Books) may need extra bottom padding so their last
  item isn't covered by the floating tab bar (`extendBody`).
- App-bar backdrops are translucent but not yet blurred per-screen; a
  `GlassSurface` `flexibleSpace` could frost them fully.
- Reader bottom bars and in-reader sheets could adopt `GlassSurface`.
- More native controls (`CNButton`, `CNSlider`, native sheets) could replace
  their Flutter approximations for additional genuine Liquid Glass surfaces.

## Running

```sh
git checkout liquid-glass
flutter run --dart-define-from-file=.env.dev
```
