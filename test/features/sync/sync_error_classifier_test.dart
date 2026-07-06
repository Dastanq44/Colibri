import 'dart:async';
import 'dart:io';

import 'package:colibri/features/sync/data/sync_error_classifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Same type name as package:http's ClientException — the classifier matches
/// it by name (http is only a transitive dependency).
class ClientException implements Exception {}

void main() {
  group('isTransientSyncError', () {
    test('plain connectivity errors are transient', () {
      expect(isTransientSyncError(const SocketException('offline')), isTrue);
      expect(isTransientSyncError(TimeoutException('slow')), isTrue);
      expect(isTransientSyncError(const HttpException('reset')), isTrue);
      expect(isTransientSyncError(ClientException()), isTrue);
    });

    test('Postgrest: 5xx/408/429 or unparseable responses are transient', () {
      expect(
        isTransientSyncError(const PostgrestException(message: 'down')),
        isTrue, // null code: response could not even be parsed
      );
      for (final code in ['500', '503', '408', '429']) {
        expect(
          isTransientSyncError(
              PostgrestException(message: 'x', code: code)),
          isTrue,
          reason: 'code $code should be transient',
        );
      }
    });

    test('Postgrest: 4xx and Postgres error codes are permanent', () {
      for (final code in ['400', '404', '409', '23505', 'PGRST301']) {
        expect(
          isTransientSyncError(
              PostgrestException(message: 'x', code: code)),
          isFalse,
          reason: 'code $code should be permanent',
        );
      }
    });

    test('Storage: 5xx and wrapped network errors are transient', () {
      expect(
        isTransientSyncError(
            const StorageException('down', statusCode: '503')),
        isTrue,
      );
      // storage_client stores the runtime type name of non-HTTP errors.
      expect(
        isTransientSyncError(
            const StorageException('x', statusCode: 'SocketException')),
        isTrue,
      );
      expect(
        isTransientSyncError(
            const StorageException('x', statusCode: 'ClientException')),
        isTrue,
      );
    });

    test('Storage: 4xx responses are permanent', () {
      expect(
        isTransientSyncError(
            const StorageException('nope', statusCode: '404')),
        isFalse,
      );
      expect(
        isTransientSyncError(
            const StorageException('denied', statusCode: '403')),
        isFalse,
      );
    });

    test('Auth: retryable fetch and 5xx are transient, 401/403 permanent', () {
      expect(isTransientSyncError(AuthRetryableFetchException()), isTrue);
      expect(
        isTransientSyncError(const AuthException('down', statusCode: '503')),
        isTrue,
      );
      expect(
        isTransientSyncError(const AuthException('no', statusCode: '401')),
        isFalse,
      );
    });

    test('payload/programming errors are permanent', () {
      expect(isTransientSyncError(const FormatException('bad json')), isFalse);
      expect(isTransientSyncError(StateError('missing file')), isFalse);
      expect(
        isTransientSyncError(UnsupportedError('unsupported item')),
        isFalse,
      );
    });
  });
}
