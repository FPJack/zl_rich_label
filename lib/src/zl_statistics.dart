/// Render / layout counters, useful to observe the caches of the labels.
///
/// Values only grow; call [reset] to start a new measurement.
class ZLLabelStatistics {
  /// Number of times the display content was composed.
  int renders = 0;

  /// Rule handlers executed (cache misses).
  int handlerCalls = 0;

  /// Matches whose cached render result was reused (no handler call, inline
  /// widgets kept).
  int reusedMatches = 0;

  /// Text layouts performed by the render object (each one shapes the
  /// paragraph, including truncation and font fitting passes).
  int textLayouts = 0;

  /// Layout requests answered from the layout cache (same content and
  /// constraints, e.g. repeated `getDryLayout` calls).
  int layoutCacheHits = 0;

  void reset() {
    renders = 0;
    handlerCalls = 0;
    reusedMatches = 0;
    textLayouts = 0;
    layoutCacheHits = 0;
  }

  @override
  String toString() =>
      'renders: $renders, handlerCalls: $handlerCalls, reusedMatches: $reusedMatches, '
      'textLayouts: $textLayouts, layoutCacheHits: $layoutCacheHits';
}
