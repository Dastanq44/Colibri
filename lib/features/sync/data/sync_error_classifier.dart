import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Classifies a per-item sync error as transient (connectivity problem or
/// backend hiccup — retry later WITHOUT consuming the attempt budget) versus
/// permanent (rejected request / bad payload — count the attempt and
/// eventually park the item as `failed`).
///
/// Kept free of queue/DB types so it is easily unit-tested.
bool isTransientSyncError(Object error) {
  // Plain connectivity errors (device offline, DNS, timeouts).
  if (error is SocketException ||
      error is HttpException ||
      error is TimeoutException) {
    return true;
  }
  // package:http's ClientException is how the underlying client surfaces
  // connection failures. Matched by type name so we don't import a package
  // that is only a transitive dependency.
  if (error.runtimeType.toString() == 'ClientException') return true;

  // Supabase-typed errors carry (string) status codes.
  if (error is AuthRetryableFetchException) return true;
  if (error is AuthException) return _isTransientHttpStatus(error.statusCode);
  if (error is PostgrestException) {
    // A null code means the response could not even be parsed (e.g. a proxy
    // error page) — treat as connectivity. Non-HTTP codes (Postgres error
    // codes like '23505') mean the server processed and rejected the request.
    if (error.code == null) return true;
    return _isTransientHttpStatus(error.code);
  }
  if (error is StorageException) {
    final status = error.statusCode;
    if (status == null) return false;
    // storage_client stores the runtime type name of non-HTTP errors
    // (e.g. 'SocketException') in statusCode.
    if (int.tryParse(status) == null) {
      return status.contains('SocketException') ||
          status.contains('ClientException') ||
          status.contains('TimeoutException') ||
          status.contains('HttpException');
    }
    return _isTransientHttpStatus(status);
  }
  return false;
}

/// True for HTTP statuses that indicate a retryable server/connectivity
/// condition: 5xx, 408 (request timeout) and 429 (rate limited).
bool _isTransientHttpStatus(String? code) {
  final status = int.tryParse(code ?? '');
  if (status == null || status < 100 || status > 599) return false;
  return status >= 500 || status == 408 || status == 429;
}
