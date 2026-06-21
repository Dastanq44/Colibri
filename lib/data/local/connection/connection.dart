import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Opens the on-device SQLite database file under the app documents directory.
///
/// Uses a [LazyDatabase] so the (async) path lookup happens on first use, and
/// runs the native database on a background isolate to keep the UI smooth.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'colibri.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
