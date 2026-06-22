/// Reading mode. [wire] matches the `mode` column / Supabase check.
enum ReaderMode {
  normal('normal'),
  fast('fast');

  const ReaderMode(this.wire);

  final String wire;
}
