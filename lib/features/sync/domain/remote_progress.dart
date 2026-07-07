import '../../reader/domain/reader_locator_types.dart';

/// The cloud copy of a book's reading position (TASK-1203).
class RemoteProgress {
  const RemoteProgress({
    required this.locatorType,
    required this.locatorValue,
    required this.percent,
    this.pageNumber,
    this.updatedAt,
  });

  factory RemoteProgress.fromRow(Map<String, dynamic> row) => RemoteProgress(
        locatorType: (row['locator_type'] as String?) ?? '',
        locatorValue: (row['locator_value'] as String?) ?? '',
        percent: ((row['percent'] as num?) ?? 0).toDouble(),
        pageNumber: row['page_number'] as int?,
        updatedAt: row['updated_at'] == null
            ? null
            : DateTime.tryParse(row['updated_at'] as String),
      );

  final String locatorType;
  final String locatorValue;

  /// 0–100.
  final double percent;
  final int? pageNumber;
  final DateTime? updatedAt;

  /// Character offset when the locator is offset-based (text books).
  int? get textOffset => ReaderLocatorTypes.isOffset(locatorType)
      ? int.tryParse(locatorValue)
      : null;
}
