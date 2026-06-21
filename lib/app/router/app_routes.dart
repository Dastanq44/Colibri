/// Centralized route paths and names for the app.
///
/// Tab roots (home/catalog/library/profile) live inside a bottom-navigation
/// shell; everything else is pushed on top.
abstract final class AppRoutes {
  const AppRoutes._();

  // Tab roots (inside the navigation shell).
  static const String home = '/home';
  static const String catalog = '/catalog';
  static const String library = '/library';
  static const String profile = '/profile';

  // Top-level / pushed routes.
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String settings = '/settings';
  static const String importBook = '/import';

  // Parameterized routes.
  static const String bookDetailPath = '/book/:bookId';
  static const String readerPath = '/reader/:bookId';

  // Route names (used with GoRouter.goNamed / pushNamed).
  static const String homeName = 'home';
  static const String catalogName = 'catalog';
  static const String libraryName = 'library';
  static const String profileName = 'profile';
  static const String onboardingName = 'onboarding';
  static const String authName = 'auth';
  static const String settingsName = 'settings';
  static const String importName = 'import';
  static const String bookDetailName = 'bookDetail';
  static const String readerName = 'reader';

  /// Builds the path for a specific book's detail screen.
  static String bookDetail(String bookId) => '/book/$bookId';

  /// Builds the path for opening a specific book in the reader.
  static String reader(String bookId) => '/reader/$bookId';
}
