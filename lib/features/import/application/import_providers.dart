import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../data/repositories/import_repository.dart';
import '../../../data/repositories/local_import_repository.dart';
import '../../sync/application/sync_providers.dart';
import '../data/book_file_validator.dart';
import '../data/book_metadata_service.dart';
import '../data/checksum_service.dart';
import '../data/file_storage_service.dart';

final checksumServiceProvider =
    Provider<ChecksumService>((ref) => const ChecksumService());

final bookFileValidatorProvider =
    Provider<BookFileValidator>((ref) => const BookFileValidator());

final bookMetadataServiceProvider =
    Provider<BookMetadataService>((ref) => const BookMetadataService());

/// Shared by import (copy) and library (delete-on-remove).
final fileStorageServiceProvider =
    Provider<FileStorageService>((ref) => FileStorageService());

final importRepositoryProvider = Provider<ImportRepository>((ref) {
  return LocalImportRepository(
    db: ref.watch(appDatabaseProvider),
    storage: ref.watch(fileStorageServiceProvider),
    checksum: ref.watch(checksumServiceProvider),
    validator: ref.watch(bookFileValidatorProvider),
    metadata: ref.watch(bookMetadataServiceProvider),
    deviceIdService: ref.watch(deviceIdServiceProvider),
    syncQueue: ref.watch(localSyncQueueRepositoryProvider),
  );
});
