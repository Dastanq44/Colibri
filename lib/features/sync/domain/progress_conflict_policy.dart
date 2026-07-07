/// Conflict rule for reading positions (plan 12.4): prompt only when the
/// cloud position is *significantly ahead* of this device. Minor drift
/// resolves silently (local wins and the next save pushes it), and a cloud
/// position BEHIND local is never offered — jumping a reader backwards
/// silently loses progress.
bool isSignificantProgressConflict({
  required double localPercent,
  required double remotePercent,
  double thresholdPercent = 5,
}) {
  return remotePercent - localPercent > thresholdPercent;
}
