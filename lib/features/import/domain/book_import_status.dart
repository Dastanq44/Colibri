/// Coarse status of the local import pipeline, surfaced to the UI.
enum BookImportStatus {
  selected,
  validating,
  copying,
  extractingMetadata,
  savingLocal,
  ready,
  failed,
  duplicate,
}
