/// Locator-type identifiers stored in `reading_progress.locator_type`.
///
/// TXT and extracted EPUB text both use a character offset into the document's
/// full text. New saves use [textOffset]; older saves may use
/// [legacyTxtOffset] and must keep resolving.
abstract final class ReaderLocatorTypes {
  const ReaderLocatorTypes._();

  static const String textOffset = 'text_offset';
  static const String legacyTxtOffset = 'txt_offset';

  /// 1-based page number in a PDF rendered by the native page viewer.
  static const String pdfPage = 'pdf_page';

  /// Whether [type] is a character-offset locator (current or legacy).
  static bool isOffset(String type) =>
      type == textOffset || type == legacyTxtOffset;
}
