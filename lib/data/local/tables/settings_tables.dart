import 'package:drift/drift.dart';

import '../db_time.dart';

/// Single-row table (id = 1) holding reader/display settings.
@DataClassName('LocalReaderSettingsRow')
class LocalReaderSettings extends Table {
  IntColumn get id => integer()();
  TextColumn get theme => text().withDefault(const Constant('light'))();
  TextColumn get fontFamily => text().withDefault(const Constant('system'))();
  IntColumn get fontSize => integer().withDefault(const Constant(18))();
  RealColumn get lineHeight => real().withDefault(const Constant(1.5))();
  RealColumn get letterSpacing => real().withDefault(const Constant(0.0))();
  TextColumn get pageAnimation => text().withDefault(const Constant('slide'))();
  BoolColumn get hapticsEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get modeLockEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get speedLockEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get autoFastModeEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get reducedMotion =>
      boolean().withDefault(const Constant(false))();
  TextColumn get locale => text().withDefault(const Constant('ru-RU'))();
  TextColumn get pageTurnDirection =>
      text().withDefault(const Constant('ltr'))();
  TextColumn get updatedAt => text().clientDefault(dbNow)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Single-row table (id = 1) holding fast-mode settings.
@DataClassName('LocalFastSettingsRow')
class LocalFastSettings extends Table {
  IntColumn get id => integer()();
  IntColumn get defaultWpm => integer().withDefault(const Constant(275))();
  IntColumn get minWpm => integer().withDefault(const Constant(150))();
  IntColumn get maxWpm => integer().withDefault(const Constant(700))();
  IntColumn get wpmStep => integer().withDefault(const Constant(25))();
  BoolColumn get showAdjacentContext =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get naturalPausesEnabled =>
      boolean().withDefault(const Constant(true))();
  TextColumn get chunkMode => text().withDefault(const Constant('word'))();
  TextColumn get updatedAt => text().clientDefault(dbNow)();

  @override
  Set<Column> get primaryKey => {id};
}
