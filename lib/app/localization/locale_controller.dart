import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Locales the app ships with. `ru` is the primary locale and the default
/// fallback (it is listed first); `en` is the secondary fallback.
const List<Locale> kSupportedLocales = <Locale>[
  Locale('ru'),
  Locale('en'),
];

/// The user-selected app locale.
///
/// `null` means "follow the system locale" (resolved against
/// [kSupportedLocales], falling back to `ru`). Persistence to local settings
/// is added in a later phase.
final localeProvider = StateProvider<Locale?>((ref) => null);
