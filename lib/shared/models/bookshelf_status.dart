/// Reading status of a book on the user's shelf. [wire] matches the `status`
/// text column / Supabase check constraint.
enum BookShelfStatus {
  reading('reading'),
  finished('finished'),
  abandoned('abandoned'),
  wantToRead('want_to_read');

  const BookShelfStatus(this.wire);

  final String wire;

  static BookShelfStatus fromWire(String wire) => BookShelfStatus.values
      .firstWhere((s) => s.wire == wire, orElse: () => BookShelfStatus.reading);
}
