import 'package:colibri/core/errors/failures.dart';
import 'package:colibri/features/import/data/book_file_validator.dart';
import 'package:colibri/features/import/domain/import_preview.dart';
import 'package:colibri/shared/models/book_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = BookFileValidator();

  ImportPreview preview(String name, {int size = 10}) => ImportPreview(
        path: '/tmp/$name',
        fileName: name,
        extension: name.split('.').last,
        sizeBytes: size,
      );

  test('accepts epub, txt and pdf (case-insensitive)', () {
    expect(validator.formatForFileName('book.epub'), BookFormat.epub);
    expect(validator.formatForFileName('book.txt'), BookFormat.txt);
    expect(validator.formatForFileName('book.PDF'), BookFormat.pdf);
    expect(validator.validatePreview(preview('book.txt')), isNull);
  });

  test('rejects unsupported extensions', () {
    expect(validator.formatForFileName('book.docx'), isNull);
    expect(validator.isSupported('book.docx'), isFalse);
    expect(
      validator.validatePreview(preview('book.docx')),
      isA<UnsupportedFormatFailure>(),
    );
  });

  test('rejects files larger than the max size', () {
    final tooBig =
        preview('book.txt', size: BookFileValidator.maxFileSizeBytes + 1);
    expect(validator.validatePreview(tooBig), isA<FileTooLargeFailure>());
  });

  test('rejects zero-byte files', () {
    expect(
      validator.validatePreview(preview('book.txt', size: 0)),
      isA<EmptyBookFailure>(),
    );
    expect(
      validator.validatePreview(preview('book.pdf', size: 0)),
      isA<EmptyBookFailure>(),
    );
  });
}
