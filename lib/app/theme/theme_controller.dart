import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reader_theme.dart';

/// Current app-chrome theme mode (light / dark / follow system).
///
/// Persistence to local settings is wired up in Phase 2 / Phase 10; for the
/// foundation this is an in-memory provider defaulting to the system setting.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Current reading-surface theme (light / sepia / dark). Applies inside the
/// reader only. Persisted alongside reader settings in a later phase.
final readerThemeVariantProvider =
    StateProvider<ReaderThemeVariant>((ref) => ReaderThemeVariant.light);
