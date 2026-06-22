import 'dart:io';

import 'package:crypto/crypto.dart';

/// Computes SHA-256 checksums for duplicate detection. UI-independent.
class ChecksumService {
  const ChecksumService();

  /// Streams [file] through SHA-256 (does not load it fully into memory).
  Future<String> sha256OfFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  /// Convenience for in-memory bytes (used by tests).
  String sha256OfBytes(List<int> bytes) => sha256.convert(bytes).toString();
}
