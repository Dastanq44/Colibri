import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../data/repositories/local_reader_repository.dart';
import '../../../data/repositories/reader_repository.dart';
import '../../sync/application/sync_providers.dart';
import '../data/text_pagination_service.dart';

final textPaginationServiceProvider =
    Provider<TextPaginationService>((ref) => const TextPaginationService());

final readerRepositoryProvider = Provider<ReaderRepository>((ref) {
  return LocalReaderRepository(
    db: ref.watch(appDatabaseProvider),
    deviceIdService: ref.watch(deviceIdServiceProvider),
    syncQueue: ref.watch(localSyncQueueRepositoryProvider),
  );
});
