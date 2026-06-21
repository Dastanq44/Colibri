/// Returns the current UTC time as an ISO-8601 string.
///
/// All local timestamp columns are stored as text to match the cloud / sync
/// wire format (Postgres `timestamptz` serialized as ISO-8601). Using a single
/// helper keeps the format consistent across tables and DAOs.
String dbNow() => DateTime.now().toUtc().toIso8601String();
