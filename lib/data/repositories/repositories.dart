/// Barrel export for all repository interfaces.
///
/// These define the boundary between UI/state and data sources (Supabase,
/// Drift, file system). UI and state management depend on these abstractions
/// only — never on Supabase or Drift directly. Concrete implementations are
/// added in their respective phases.
library;

export 'analytics_repository.dart';
export 'auth_repository.dart';
export 'book_repository.dart';
export 'catalog_repository.dart';
export 'import_repository.dart';
export 'library_repository.dart';
export 'notes_repository.dart';
export 'profile_repository.dart';
export 'progress_repository.dart';
export 'reader_repository.dart';
export 'recommendation_repository.dart';
export 'review_repository.dart';
export 'settings_repository.dart';
export 'sync_repository.dart';
