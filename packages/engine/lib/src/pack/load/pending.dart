/// How a pack marks a value as pending D: the single place that decides it.
///
/// A pending value means "D has not ruled yet". The validator reports it as a
/// warning, never an error, and the feature that needs it stays off (R's
/// setup decision 1, 2026-10-21).
///
/// Today the marker is JSON `null`. How the annotation stripper writes the
/// provisional pack's `{placeholder, gap, note}` marker objects is still open
/// with R; if the ruling keeps a different marker, only [isPendingMarker]
/// changes.
library;

/// Whether [value], as read from a stripped pack file, means "pending D".
bool isPendingMarker(Object? value) => value == null;
