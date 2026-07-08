import 'fast_token.dart';

/// Timing multipliers that make fast (RSVP) reading feel natural by holding a
/// word on screen a little longer when it ends a clause, sentence, paragraph or
/// chapter — instead of flashing every token for exactly the same time. No
/// blank "pause" tokens are inserted; the current word simply stays visible
/// longer.
///
/// The multiplier for a token is the strongest that applies: its trailing
/// punctuation vs. a structural boundary (paragraph/chapter end), whichever is
/// larger.
abstract final class NaturalPause {
  static const double word = 1.00;
  static const double comma = 1.15;
  static const double clause = 1.25; // colon / semicolon
  static const double sentence = 1.50; // . ? !
  static const double paragraph = 2.00;
  static const double chapter = 2.75;

  /// Closing marks that can trail the real terminal punctuation, e.g. the
  /// quote in `world."` or the bracket in `(aside.)` — skipped when deciding
  /// the sentence/clause weight.
  static const Set<String> _closers = <String>{
    '"', "'", ')', ']', '}', '»', '”', '’', '›',
  };

  /// Display-time multiplier for [current], given the [next] token (used to
  /// detect paragraph/chapter boundaries). Returns 1.0 when nothing applies.
  static double multiplierFor(FastToken? current, FastToken? next) {
    if (current == null) return word;
    var value = _punctuation(current.rawText);

    if (next == null) {
      // End of the book — treat like a chapter break.
      if (chapter > value) value = chapter;
    } else if (next.chapterIndex != current.chapterIndex) {
      if (chapter > value) value = chapter;
    } else if (next.paragraphIndex != current.paragraphIndex) {
      if (paragraph > value) value = paragraph;
    }
    return value;
  }

  static double _punctuation(String raw) {
    var i = raw.length - 1;
    while (i >= 0 && _closers.contains(raw[i])) {
      i--;
    }
    if (i < 0) return word;
    switch (raw[i]) {
      case ',':
        return comma;
      case ':':
      case ';':
        return clause;
      case '.':
      case '!':
      case '?':
      case '…':
        return sentence;
      default:
        return word;
    }
  }
}
