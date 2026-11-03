import 'package:flutter/material.dart';

import 'zl_attributed_text.dart';
import 'zl_label_core.dart';
import 'zl_rule.dart';
import 'zl_statistics.dart';
import 'zl_tag_parser.dart';
import 'zl_text_layout.dart';
import 'zl_text_style.dart';

/// Position information of a long press / double tap on a [ZLRichLabel].
@immutable
class ZLRichGestureInfo {
  const ZLRichGestureInfo({
    required this.location,
    required this.globalLocation,
    required this.characterIndex,
    required this.match,
    required this.matchDisplayText,
    required this.rawText,
    required this.displayText,
  });

  /// Position in the label's coordinate system.
  final Offset location;

  final Offset globalLocation;

  /// Character of the display text under the gesture, `null` when not on
  /// the text.
  final int? characterIndex;

  /// Rule match under the gesture.
  final ZLRichMatch? match;

  /// How the match is displayed (rules may replace the text).
  final String? matchDisplayText;

  /// The raw string.
  final String rawText;

  /// The rendered text (inline widgets are U+FFFC).
  final String displayText;

  @override
  String toString() =>
      'ZLRichGestureInfo(location: $location, characterIndex: $characterIndex, match: $match, matchDisplayText: $matchDisplayText)';
}

/// Controller of a [ZLRichLabel] / [ZLTagRichLabel]: everything of
/// [ZLLabelController] plus parse results, render cache control and
/// statistics.
class ZLRichLabelController extends ZLLabelController {
  ZLRichLabelController({super.initiallyExpanded});

  ZLRichLabelState<ZLRichLabel>? _rich;

  void _attachRich(ZLRichLabelState<ZLRichLabel> state) => _rich = state;

  void _detachRich(ZLRichLabelState<ZLRichLabel> state) {
    if (identical(_rich, state)) _rich = null;
  }

  /// The raw string.
  String get rawText => _rich?.widget.text ?? '';

  /// Plain text and matches, in order.
  List<ZLRichSegment> get segments =>
      _rich?._segments ?? const <ZLRichSegment>[];

  /// Effective matches of all rules (built-in rules included).
  List<ZLRichMatch> get matches => _rich?._matches ?? const <ZLRichMatch>[];

  /// Tags of a [ZLTagRichLabel] (outer tags first).
  List<ZLTagInfo> get tags => _rich?.parsedTags ?? const <ZLTagInfo>[];

  /// Render / layout counters.
  ZLLabelStatistics get statistics => _rich?.statistics ?? _fallbackStatistics;
  final ZLLabelStatistics _fallbackStatistics = ZLLabelStatistics();

  /// Runs every rule handler again (clears the render cache).
  void rebuild() => _rich?.setNeedsRebuild();

  /// Runs the handler of one rule again; other matches reuse their cached
  /// render result.
  void setNeedsRebuild(String ruleName) => _rich?.setNeedsRebuild(ruleName);

  /// The rule match at [location].
  ZLRichMatch? matchAt(Offset location) => _rich?._matchAtLocation(location);

  /// Gesture information at [location].
  ZLRichGestureInfo? gestureInfoAt(Offset location) =>
      _rich?._gestureInfo(location, location);

  /// Raw text of a display range: plain text maps character by character, a
  /// partially covered match maps to its whole raw text.
  String rawTextForDisplayRange(TextRange range) =>
      _rich?._rawTextForDisplayRange(range) ?? '';
}

/// Rule based rich text label.
///
/// Every [ZLRichRule] finds content in [text] with a pattern; overlapping
/// matches are resolved by priority; each match is rendered by the rule's
/// handler (style, replacement text, inline widgets, taps, press highlight).
///
/// ```dart
/// ZLRichLabel(
///   text: 'Hi @alice, see https://flutter.dev',
///   style: ZLTextStyle().fontSize(15),
///   rules: [
///     ZLRichRule.regex('mention', r'@\w+', priority: 10, handler: (ctx) {
///       ctx.addStyle(ZLTextStyle().color(Colors.purple));
///       ctx.onTap = (match) => openProfile(match.text);
///     }),
///   ],
/// )
/// ```
///
/// Render cache: the result of a handler is reused while the rule object,
/// the matched text and its position stay the same, and while [style], the
/// ambient text style, brightness and text scale do not change. Changing
/// only [highlightStyle], the tokens or the expand state never runs
/// handlers. Keep rule objects in a field to benefit from the cache; create
/// new rule objects (or call [ZLRichLabelController.rebuild] /
/// [ZLRichLabelController.setNeedsRebuild]) when the data a handler reads
/// changes.
///
/// Subclasses add built-in rules by overriding [ZLRichLabelState.builtInRules]
/// (that is how [ZLTagRichLabel] is implemented).
class ZLRichLabel extends StatefulWidget {
  const ZLRichLabel({
    super.key,
    required this.text,
    this.rules = const <ZLRichRule>[],
    this.style = ZLTextStyle.none,
    this.highlightStyle = ZLTextStyle.none,
    this.truncationToken,
    this.expandToken,
    this.collapseToken,
    this.expanded,
    this.onExpandChanged,
    this.onExpandTokenTap,
    this.collapseThreshold = 0,
    this.maxLines,
    this.truncationMode = ZLTruncationMode.tail,
    this.textAlign,
    this.textDirection,
    this.textScaler,
    this.padding = EdgeInsets.zero,
    this.verticalAlignment = ZLVerticalAlignment.center,
    this.adjustsFontSizeToFit = false,
    this.minimumScaleFactor = 0,
    this.extendsLinkTouchArea = false,
    this.onLongPress,
    this.onDoubleTap,
    this.selectable = false,
    this.selectionColor,
    this.onSelectionChanged,
    this.onCopy,
    this.copyLabel = '复制',
    this.copyRawLabel = '复制原文',
    this.selectAllLabel = '全选',
    this.semanticsLabel,
    this.controller,
  });

  /// Raw text, parsed by the rules.
  final String text;

  /// External rules (built-in rules of subclasses come first).
  final List<ZLRichRule> rules;

  /// Style of plain text, merged on top of the ambient [DefaultTextStyle].
  final ZLTextStyle style;

  /// Default press highlight of tappable content (empty: no highlight).
  /// Rules override it with `ctx.highlightStyle`.
  final ZLTextStyle highlightStyle;

  /// Shown where the text is truncated, `…` with the plain text style when
  /// `null`.
  final ZLAttributedText? truncationToken;

  /// "Expand" token such as `… 全文`, shown instead of the ellipsis when the
  /// text has more than [maxLines] lines; tapping it expands the text.
  /// Attributes it does not set use the plain text style.
  final ZLAttributedText? expandToken;

  /// "Collapse" token appended to the expanded text, e.g. ` 收起`. When
  /// `null` an expanded text cannot be collapsed.
  final ZLAttributedText? collapseToken;

  /// Expand state driven by the parent. When it changes the label follows;
  /// taps on the tokens still toggle internally and report through
  /// [onExpandChanged]. `null`: the state lives in the label (or its
  /// controller).
  final bool? expanded;

  /// Called with the new state after the expand / collapse token is tapped.
  final ValueChanged<bool>? onExpandChanged;

  /// Takes over taps on the expand (`true`) / collapse (`false`) token: the
  /// label no longer toggles by itself. Call
  /// [ZLLabelController.toggleExpanded] (or change [expanded]) to toggle.
  final ValueChanged<bool>? onExpandTokenTap;

  /// Only collapse texts with more than this many lines (when larger than
  /// [maxLines]): with `maxLines: 3, collapseThreshold: 5` texts of up to 5
  /// lines are shown completely.
  final int collapseThreshold;

  /// Line limit (collapsed line count when [expandToken] is set).
  final int? maxLines;
  final ZLTruncationMode truncationMode;
  final TextAlign? textAlign;

  /// `null`: detected from the content (right to left for Arabic, Hebrew …).
  final TextDirection? textDirection;
  final TextScaler? textScaler;
  final EdgeInsetsGeometry padding;
  final ZLVerticalAlignment verticalAlignment;
  final bool adjustsFontSizeToFit;
  final double minimumScaleFactor;

  /// Finds tappable matches up to 15pt around the finger when it is not on
  /// the text.
  final bool extendsLinkTouchArea;

  /// Long press. Matches with their own `ctx.onLongPress` take precedence. A
  /// long press cancels the press highlight and the tap.
  final ValueChanged<ZLRichGestureInfo>? onLongPress;

  /// Double tap. While set, single taps on links wait until the double tap
  /// is ruled out (about 300 ms); keep it `null` when not needed.
  final ValueChanged<ZLRichGestureInfo>? onDoubleTap;

  /// Long press selects a word (or a whole match), drag the handles to adjust,
  /// the menu copies the display text or the raw text. Long presses on plain
  /// text no longer call [onLongPress].
  final bool selectable;

  /// Selection background, primary colour with 25% alpha by default.
  final Color? selectionColor;
  final ValueChanged<TextRange?>? onSelectionChanged;

  /// Called after copying through the menu: the text and whether it is the
  /// raw text.
  final void Function(String text, bool isRawText)? onCopy;
  final String copyLabel;
  final String copyRawLabel;
  final String selectAllLabel;
  final String? semanticsLabel;
  final ZLRichLabelController? controller;

  @override
  State<ZLRichLabel> createState() => ZLRichLabelState<ZLRichLabel>();
}

/// A cached render result of one match.
class _RenderedMatch {
  _RenderedMatch({
    required this.match,
    required this.content,
    required this.onTap,
    required this.onLongPress,
    required this.highlightStyle,
    required this.links,
  });

  final ZLRichMatch match;
  final ZLAttributedText content;
  final ZLRichMatchCallback? onTap;
  final ZLRichMatchCallback? onLongPress;
  final ZLTextStyle? highlightStyle;
  final List<ZLRuleLink> links;

  bool isValidFor(ZLRichMatch other) =>
      identical(match.rule, other.rule) &&
      match.index == other.index &&
      match.range == other.range &&
      match.text == other.text;
}

/// A piece of the display text and its raw counterpart.
class _DisplayPiece {
  const _DisplayPiece(this.display, this.raw, {required this.isMatch});

  final TextRange display;
  final TextRange raw;
  final bool isMatch;
}

/// State of [ZLRichLabel]. Subclass it (together with the widget) to build
/// labels with built-in rules.
class ZLRichLabelState<T extends ZLRichLabel> extends State<T> {
  /// Render / layout counters.
  final ZLLabelStatistics statistics = ZLLabelStatistics();

  /// Built-in rules of subclasses, before [ZLRichLabel.rules] at equal
  /// priority. Call [setNeedsReparse] when they change.
  @protected
  List<ZLRichRule> get builtInRules => const <ZLRichRule>[];

  /// Called after parsing (segments / matches updated).
  @protected
  void didParse() {}

  /// Tags, only used by [ZLTagRichLabel].
  @protected
  List<ZLTagInfo> get parsedTags => const <ZLTagInfo>[];

  /// All rules: `builtInRules + widget.rules`.
  List<ZLRichRule> get allRules =>
      <ZLRichRule>[...builtInRules, ...widget.rules];

  /// Effective matches.
  List<ZLRichMatch> get matches => _matches;

  /// Plain text and matches.
  List<ZLRichSegment> get segments => _segments;

  List<ZLRichSegment> _segments = const <ZLRichSegment>[];
  List<ZLRichMatch> _matches = const <ZLRichMatch>[];
  String? _parsedText;
  List<ZLRichRule> _parsedRules = const <ZLRichRule>[];
  bool _needsParse = true;

  final Map<(int, int, int), _RenderedMatch> _cache =
      <(int, int, int), _RenderedMatch>{};
  ZLAttributedText _content = ZLAttributedText.empty;
  List<ZLLabelLink> _links = const <ZLLabelLink>[];
  List<_DisplayPiece> _pieces = const <_DisplayPiece>[];
  List<(TextRange, ZLRichMatch)> _displayMatches =
      const <(TextRange, ZLRichMatch)>[];
  bool _needsCompose = true;

  // Inputs of the last composition.
  ZLTextStyle? _composedStyle;
  ZLTextStyle? _composedHighlight;
  TextStyle? _composedBase;
  Brightness? _composedBrightness;
  TextScaler? _composedScaler;

  ZLRichLabelController? get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller?._attachRich(this);
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detachRich(this);
      widget.controller?._attachRich(this);
    }
  }

  @override
  void dispose() {
    _controller?._detachRich(this);
    super.dispose();
  }

  // MARK: Invalidation

  /// Parses the text again (rule patterns / priorities changed).
  @protected
  void setNeedsReparse() {
    _needsParse = true;
    if (mounted) setState(() {});
  }

  /// Runs the handlers again: all of them, or only those of [ruleName].
  void setNeedsRebuild([String? ruleName]) {
    invalidateRenderCache(ruleName);
    if (mounted) setState(() {});
  }

  /// Drops cached render results without scheduling a build (use it in
  /// `didUpdateWidget` / `didParse`).
  @protected
  void invalidateRenderCache([String? ruleName]) {
    if (ruleName == null) {
      _cache.clear();
    } else {
      _cache.removeWhere(
          (_, _RenderedMatch value) => value.match.rule.name == ruleName);
    }
    _needsCompose = true;
  }

  // MARK: Parse

  void _parseIfNeeded() {
    final List<ZLRichRule> rules = allRules;
    final bool rulesChanged = rules.length != _parsedRules.length ||
        Iterable<int>.generate(rules.length)
            .any((int i) => !identical(rules[i], _parsedRules[i]));
    if (!_needsParse && !rulesChanged && _parsedText == widget.text) return;
    _needsParse = false;
    _parsedText = widget.text;
    _parsedRules = rules;
    _matches = ZLRichParser.resolve(widget.text, rules);
    _segments = ZLRichParser.segmentsFromMatches(widget.text, _matches);
    _needsCompose = true;
    didParse();
  }

  // MARK: Compose

  /// Plain text style: ambient default text style + [ZLRichLabel.style].
  ZLTextStyle _baseStyle(BuildContext context) =>
      ZLTextStyle(textStyle: DefaultTextStyle.of(context).style)
          .merge(widget.style);

  void _composeIfNeeded(BuildContext context) {
    final TextStyle ambient = DefaultTextStyle.of(context).style;
    final Brightness brightness = Theme.of(context).brightness;
    final TextScaler scaler =
        widget.textScaler ?? MediaQuery.textScalerOf(context);
    if (_composedStyle != widget.style ||
        _composedBase != ambient ||
        _composedBrightness != brightness ||
        _composedScaler != scaler) {
      _cache.clear();
      _needsCompose = true;
    }
    if (_composedHighlight != widget.highlightStyle) _needsCompose = true;
    if (!_needsCompose) return;
    _needsCompose = false;
    _composedStyle = widget.style;
    _composedHighlight = widget.highlightStyle;
    _composedBase = ambient;
    _composedBrightness = brightness;
    _composedScaler = scaler;
    statistics.renders += 1;

    final ZLTextStyle base = _baseStyle(context);
    final List<ZLTextRun> runs = <ZLTextRun>[];
    final List<ZLLabelLink> links = <ZLLabelLink>[];
    final List<_DisplayPiece> pieces = <_DisplayPiece>[];
    final List<(TextRange, ZLRichMatch)> displayMatches =
        <(TextRange, ZLRichMatch)>[];
    final Map<(int, int, int), _RenderedMatch> next =
        <(int, int, int), _RenderedMatch>{};
    int display = 0;
    int raw = 0;

    for (final ZLRichSegment segment in _segments) {
      final ZLRichMatch? match = segment.match;
      if (match == null) {
        final int length = segment.text.length;
        runs.add(ZLTextRun(segment.text, style: base));
        pieces.add(_DisplayPiece(
            TextRange(start: display, end: display + length),
            TextRange(start: raw, end: raw + length),
            isMatch: false));
        display += length;
        raw += length;
        continue;
      }
      final (int, int, int) key =
          (match.range.start, match.range.end, match.index);
      _RenderedMatch? rendered = _cache[key];
      if (rendered != null && rendered.isValidFor(match)) {
        statistics.reusedMatches += 1;
      } else {
        rendered = _render(context, match, base);
        statistics.handlerCalls += 1;
      }
      next[key] = rendered;

      final ZLAttributedText content = rendered.content;
      final TextRange range =
          TextRange(start: display, end: display + content.length);
      runs.addAll(content.withGroup(match.index + 1).runs);
      pieces.add(_DisplayPiece(range, match.range, isMatch: true));
      if (!range.isCollapsed) displayMatches.add((range, match));
      final ZLTextStyle highlight =
          rendered.highlightStyle ?? widget.highlightStyle;
      if ((rendered.onTap != null || rendered.onLongPress != null) &&
          !range.isCollapsed) {
        final ZLRichMatchCallback? onTap = rendered.onTap;
        final ZLRichMatchCallback? onLongPress = rendered.onLongPress;
        links.add(ZLLabelLink(
          range: range,
          style: ZLTextStyle.none,
          activeStyle: highlight,
          onTap: onTap == null ? null : (_) => onTap(match),
          onLongPress: onLongPress == null ? null : (_) => onLongPress(match),
        ));
      }
      for (final ZLRuleLink link in rendered.links) {
        if (link.range.end > content.length) continue;
        final ZLRichMatchCallback? onTap = link.onTap;
        final ZLRichMatchCallback? onLongPress = link.onLongPress;
        links.add(ZLLabelLink(
          range: TextRange(
              start: display + link.range.start, end: display + link.range.end),
          style: ZLTextStyle.none,
          activeStyle: onTap == null
              ? ZLTextStyle.none
              : (link.highlightStyle ?? widget.highlightStyle),
          onTap: onTap == null ? null : (_) => onTap(match),
          onLongPress: onLongPress == null ? null : (_) => onLongPress(match),
        ));
      }
      display += content.length;
      raw = match.range.end;
    }
    _cache
      ..clear()
      ..addAll(next);
    _content = ZLAttributedText.fromRuns(runs);
    _links = links;
    _pieces = pieces;
    _displayMatches = displayMatches;
  }

  _RenderedMatch _render(
      BuildContext context, ZLRichMatch match, ZLTextStyle base) {
    final ZLRichRuleContext ctx =
        ZLRichRuleContext(match: match, baseStyle: base, context: context);
    match.rule.handler(ctx);
    return _RenderedMatch(
      match: match,
      content: ctx.content.build(),
      onTap: ctx.onTap,
      onLongPress: ctx.onLongPress,
      highlightStyle: ctx.highlightStyle,
      links: ctx.links,
    );
  }

  // MARK: Queries

  /// Display text of the last composition.
  String get displayText => _content.string;

  ZLRichMatch? _matchAtIndex(int? index) {
    if (index == null) return null;
    int low = 0;
    int high = _displayMatches.length - 1;
    while (low <= high) {
      final int mid = (low + high) >> 1;
      final TextRange range = _displayMatches[mid].$1;
      if (index < range.start) {
        high = mid - 1;
      } else if (index >= range.end) {
        low = mid + 1;
      } else {
        return _displayMatches[mid].$2;
      }
    }
    return null;
  }

  TextRange? _displayRangeOf(ZLRichMatch match) {
    for (final (TextRange range, ZLRichMatch m) in _displayMatches) {
      if (identical(m, match)) return range;
    }
    return null;
  }

  ZLRichMatch? _matchAtLocation(Offset location) {
    final ZLLabelController? controller = widget.controller;
    if (controller == null) return null;
    final int? index = controller.characterIndexAt(location);
    if (index != null) return _matchAtIndex(index);
    if (!widget.extendsLinkTouchArea) return null;
    final ZLLabelLink? link = controller.linkAt(location);
    return link == null ? null : _matchAtIndex(link.range.start);
  }

  ZLRichGestureInfo _gestureInfo(Offset location, Offset global,
      {int? characterIndex}) {
    final int? index =
        characterIndex ?? widget.controller?.characterIndexAt(location);
    final ZLRichMatch? match = _matchAtIndex(index);
    final TextRange? range = match == null ? null : _displayRangeOf(match);
    final String display = _content.string;
    return ZLRichGestureInfo(
      location: location,
      globalLocation: global,
      characterIndex: index,
      match: match,
      matchDisplayText:
          range == null ? null : display.substring(range.start, range.end),
      rawText: widget.text,
      displayText: display,
    );
  }

  String _rawTextForDisplayRange(TextRange range) {
    final String raw = widget.text;
    final StringBuffer buffer = StringBuffer();
    for (final _DisplayPiece piece in _pieces) {
      final int start =
          range.start > piece.display.start ? range.start : piece.display.start;
      final int end =
          range.end < piece.display.end ? range.end : piece.display.end;
      // An empty match strictly inside the range keeps its raw text.
      final bool inside = piece.display.isCollapsed &&
          piece.display.start > range.start &&
          piece.display.start < range.end;
      if (end <= start && !inside) continue;
      if (piece.isMatch) {
        buffer.write(raw.substring(piece.raw.start, piece.raw.end));
      } else {
        final int offset = start - piece.display.start;
        buffer.write(raw.substring(piece.raw.start + offset,
            piece.raw.start + offset + (end - start)));
      }
    }
    return buffer.toString();
  }

  // MARK: Build

  @override
  Widget build(BuildContext context) {
    _parseIfNeeded();
    _composeIfNeeded(context);
    return buildLabel(context);
  }

  /// Builds the label from the composed content.
  @protected
  Widget buildLabel(BuildContext context) {
    final ValueChanged<ZLRichGestureInfo>? onLongPress = widget.onLongPress;
    final ValueChanged<ZLRichGestureInfo>? onDoubleTap = widget.onDoubleTap;
    return ZLLabelCore(
      content: _content,
      style: widget.style,
      links: _links,
      activeLinkStyle: widget.highlightStyle,
      truncationToken: widget.truncationToken,
      expandToken: widget.expandToken,
      collapseToken: widget.collapseToken,
      expanded: widget.expanded,
      onExpandChanged: widget.onExpandChanged,
      onExpandTokenTap: widget.onExpandTokenTap,
      collapseThreshold: widget.collapseThreshold,
      maxLines: widget.maxLines,
      truncationMode: widget.truncationMode,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      textScaler: widget.textScaler,
      padding: widget.padding,
      verticalAlignment: widget.verticalAlignment,
      adjustsFontSizeToFit: widget.adjustsFontSizeToFit,
      minimumScaleFactor: widget.minimumScaleFactor,
      extendsLinkTouchArea: widget.extendsLinkTouchArea,
      onLongPress: onLongPress == null
          ? null
          : (ZLLabelGestureDetails d) => onLongPress(_gestureInfo(
              d.location, d.globalLocation,
              characterIndex: d.characterIndex)),
      onDoubleTap: onDoubleTap == null
          ? null
          : (ZLLabelGestureDetails d) => onDoubleTap(_gestureInfo(
              d.location, d.globalLocation,
              characterIndex: d.characterIndex)),
      selectable: widget.selectable,
      selectionColor: widget.selectionColor,
      onSelectionChanged: widget.onSelectionChanged,
      onCopy: widget.onCopy,
      rawTextForRange: _rawTextForDisplayRange,
      atomicRanges: <TextRange>[
        for (final (TextRange range, ZLRichMatch _) in _displayMatches) range
      ],
      copyLabel: widget.copyLabel,
      copyRawLabel: widget.copyRawLabel,
      selectAllLabel: widget.selectAllLabel,
      semanticsLabel: widget.semanticsLabel,
      statistics: statistics,
      controller: widget.controller,
    );
  }
}
