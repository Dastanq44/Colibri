import '../../reader/domain/reader_locator_types.dart';

/// A saved reading position with an optional label (TASK-1101).
class Bookmark {
  const Bookmark({
    required this.id,
    required this.bookId,
    required this.locatorType,
    required this.locatorValue,
    required this.createdAt,
    this.label,
  });

  final String id;
  final String bookId;
  final String locatorType;
  final String locatorValue;
  final DateTime? createdAt;
  final String? label;

  /// Character offset into the book text, when the locator is offset-based.
  int? get textOffset => ReaderLocatorTypes.isOffset(locatorType)
      ? int.tryParse(locatorValue)
      : null;
}

/// A user note anchored at a locator (TASK-1102).
class Note {
  const Note({
    required this.id,
    required this.bookId,
    required this.noteText,
    required this.locatorType,
    required this.locatorValue,
    required this.createdAt,
    this.selectedText,
  });

  final String id;
  final String bookId;
  final String noteText;
  final String locatorType;
  final String locatorValue;
  final DateTime? createdAt;
  final String? selectedText;

  /// Character offset into the book text, when the locator is offset-based.
  int? get textOffset => ReaderLocatorTypes.isOffset(locatorType)
      ? int.tryParse(locatorValue)
      : null;
}
