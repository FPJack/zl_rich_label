import 'package:flutter/widgets.dart';

import 'zl_attributed_text.dart';
import 'zl_text_style.dart';

/// Handler of a [ZLRichRule]: writes the display content of a match into the
/// context, and optionally sets taps and highlight styles.
typedef ZLRichRuleHandler = void Function(ZLRichRuleContext ctx);

/// Callback with the rule match that was tapped / long pressed.
typedef ZLRichMatchCallback = void Function(ZLRichMatch match);

/// A pattern based rule.
///
/// ```dart
/// final mention = ZLRichRule.regex('mention', r'@\w+', priority: 10, handler: (ctx) {
///   ctx.addStyle(ZLTextStyle().color(Colors.purple));
///   ctx.onTap = (match) => openProfile(match.text);
/// });
/// ```
///
/// When matches of different rules overlap:
/// 1. the higher [priority] wins;
/// 2. same priority: the earlier match wins → then the longer one → then the
///    rule that comes first (built-in rules come before external rules);
/// 3. a losing match is dropped as a whole, its text is handled as plain text
///    or by other rules (no nested parsing).
///
/// The handler output is cached per match while the rule object stays the
/// same (see `ZLRichLabel`). Create a new rule object, or call
/// `ZLRichLabelController.rebuild()` / `setNeedsRebuild(ruleName)` when the
/// data the handler depends on changes.
class ZLRichRule {
  /// [pattern] is usually a [RegExp]; any [Pattern] works, for example
  /// [ZLDataDetector].
  ZLRichRule(
      {required this.name,
      required this.pattern,
      this.priority = 0,
      required this.handler});

  /// Creates a rule from a regular expression source. Throws a
  /// [FormatException] when the expression is invalid.
  factory ZLRichRule.regex(
    String name,
    String source, {
    int priority = 0,
    bool caseSensitive = true,
    bool multiLine = false,
    bool dotAll = false,
    bool unicode = false,
    required ZLRichRuleHandler handler,
  }) {
    return ZLRichRule(
      name: name,
      pattern: RegExp(source,
          caseSensitive: caseSensitive,
          multiLine: multiLine,
          dotAll: dotAll,
          unicode: unicode),
      priority: priority,
      handler: handler,
    );
  }

  /// Name of the rule (used to remove / refresh rules and in callbacks).
  final String name;

  /// What to match.
  final Pattern pattern;

  /// Larger values win when matches overlap.
  final int priority;

  /// Renders a match.
  final ZLRichRuleHandler handler;

  @override
  String toString() => 'ZLRichRule($name, priority: $priority)';
}

/// A match produced by a [Pattern] that is not a [RegExp] can expose named
/// groups by implementing this interface.
abstract interface class ZLNamedGroupMatch implements Match {
  String? namedGroup(String name);
}

/// A simple [Match] implementation for custom [Pattern]s.
class ZLPatternMatch implements ZLNamedGroupMatch {
  ZLPatternMatch({
    required this.input,
    required this.pattern,
    required List<TextRange?> groups,
    Map<String, int> names = const <String, int>{},
  })  : assert(groups.isNotEmpty && groups.first != null),
        _groups = groups,
        _names = names;

  @override
  final String input;

  @override
  final Pattern pattern;

  final List<TextRange?> _groups;
  final Map<String, int> _names;

  @override
  int get start => _groups.first!.start;

  @override
  int get end => _groups.first!.end;

  @override
  int get groupCount => _groups.length - 1;

  @override
  String? group(int group) {
    if (group < 0 || group >= _groups.length) return null;
    final TextRange? range = _groups[group];
    return range == null ? null : input.substring(range.start, range.end);
  }

  @override
  String? operator [](int group) => this.group(group);

  @override
  List<String?> groups(List<int> groupIndices) =>
      groupIndices.map(group).toList();

  @override
  String? namedGroup(String name) {
    final int? index = _names[name];
    return index == null ? null : group(index);
  }

  /// Range of a group in [input].
  TextRange? groupRange(int group) =>
      group < 0 || group >= _groups.length ? null : _groups[group];
}

/// One effective match of a rule (ranges are relative to the raw string).
class ZLRichMatch {
  ZLRichMatch(
      {required this.rule,
      required this.index,
      required this.result,
      required this.source});

  final ZLRichRule rule;

  /// Position of the match among all effective matches (all rules counted
  /// together, starting at 0).
  final int index;

  /// The underlying [Match] ([RegExpMatch] for [RegExp] rules).
  final Match result;

  /// The raw string.
  final String source;

  /// Matched raw text.
  String get text => source.substring(result.start, result.end);

  /// Range in the raw string.
  TextRange get range => TextRange(start: result.start, end: result.end);

  /// Capture group [i] (0 is the whole match). `null` when it does not exist
  /// or did not take part in the match.
  String? group(int i) {
    if (i < 0 || i > result.groupCount) return null;
    return result.group(i);
  }

  /// Named capture group `(?<name>…)`.
  String? namedGroup(String name) {
    final Match match = result;
    try {
      if (match is RegExpMatch) return match.namedGroup(name);
      if (match is ZLNamedGroupMatch) return match.namedGroup(name);
    } on ArgumentError {
      return null;
    }
    return null;
  }

  @override
  String toString() =>
      'ZLRichMatch(rule: ${rule.name}, index: $index, text: $text, range: ${range.start}-${range.end})';
}

/// A tap / long press on a part of the content of one match (see
/// [ZLRichRuleContext.addLink]).
class ZLRuleLink {
  const ZLRuleLink(
      {required this.range, this.highlightStyle, this.onTap, this.onLongPress});

  /// Range relative to the content written by the handler.
  final TextRange range;
  final ZLTextStyle? highlightStyle;
  final ZLRichMatchCallback? onTap;
  final ZLRichMatchCallback? onLongPress;
}

/// What a rule handler receives: the match, and the content to write.
class ZLRichRuleContext {
  ZLRichRuleContext(
      {required this.match, required this.baseStyle, this.context})
      : content = ZLAttributedTextBuilder(
            ZLAttributedText(match.text, style: baseStyle));

  final ZLRichMatch match;

  /// Style of plain text (label style merged on top of the default style).
  final ZLTextStyle baseStyle;

  /// Context of the label. Use it to read the theme (dark mode) in a
  /// handler; handlers run again when the theme brightness or the text scale
  /// changes.
  final BuildContext? context;

  /// Display content of the match. It starts as "matched text + baseStyle";
  /// modify it freely. Empty content hides the match.
  final ZLAttributedTextBuilder content;

  /// Makes the whole content tappable (including tappable inline widgets).
  /// The argument is the match that was tapped.
  ZLRichMatchCallback? onTap;

  /// Long press on the content. When set, the label's `onLongPress` is not
  /// called for this match.
  ZLRichMatchCallback? onLongPress;

  /// Press highlight. `null` uses the label's `highlightStyle`,
  /// [ZLTextStyle.none] disables the highlight.
  ZLTextStyle? highlightStyle;

  final List<ZLRuleLink> _links = <ZLRuleLink>[];

  /// Links added with [addLink].
  List<ZLRuleLink> get links => List<ZLRuleLink>.unmodifiable(_links);

  String get ruleName => match.rule.name;

  String get matchedText => match.text;

  String? group(int i) => match.group(i);

  String? namedGroup(String name) => match.namedGroup(name);

  /// Replaces the content with [text]; [style] is merged on top of
  /// [baseStyle].
  void setText(String text, [ZLTextStyle? style]) {
    content.setText(ZLAttributedText(text, style: baseStyle.merge(style)));
  }

  /// Merges [style] on top of the whole content.
  void addStyle(ZLTextStyle style) => content.addStyle(style);

  /// Replaces the content with an inline widget.
  void setWidget(ZLRichWidget widget, [ZLTextStyle? style]) {
    content.setText(widgetText(widget, style));
  }

  /// Rich text holding an inline widget, to combine with other content:
  /// `ctx.content.appendText(ctx.widgetText(badge))`.
  ZLAttributedText widgetText(ZLRichWidget widget, [ZLTextStyle? style]) {
    return ZLAttributedText.widget(widget,
        style: baseStyle.merge(style),
        text: widget.semanticsLabel ?? kZLObjectReplacementCharacter);
  }

  /// Rich text with [baseStyle] merged under [style].
  ZLAttributedText text(String text, [ZLTextStyle? style]) =>
      ZLAttributedText(text, style: baseStyle.merge(style));

  /// Gives a part of the content (range relative to [content]) its own tap /
  /// long press / press highlight. Links may nest; the link added last wins
  /// where they overlap (outer tags first, inner tags last). Parts not covered
  /// by any link use [onTap] / [onLongPress].
  void addLink(TextRange range,
      {ZLTextStyle? highlightStyle,
      ZLRichMatchCallback? onTap,
      ZLRichMatchCallback? onLongPress}) {
    if (!range.isValid ||
        range.isCollapsed ||
        (onTap == null && onLongPress == null)) {
      return;
    }
    _links.add(ZLRuleLink(
        range: range,
        highlightStyle: highlightStyle,
        onTap: onTap,
        onLongPress: onLongPress));
  }
}

/// Plain text (`match == null`) or a rule match, in order.
class ZLRichSegment {
  const ZLRichSegment(this.text, this.match);

  final String text;
  final ZLRichMatch? match;

  bool get isRuleMatch => match != null;

  @override
  String toString() =>
      match == null ? 'ZLRichSegment("$text")' : 'ZLRichSegment($match)';
}

class _Candidate {
  _Candidate(
      this.start, this.end, this.priority, this.order, this.rule, this.result);

  final int start;
  final int end;
  final int priority;
  final int order;
  final ZLRichRule rule;
  final Match result;
}

/// Runs all rules and resolves overlaps by priority.
abstract final class ZLRichParser {
  /// Effective matches, sorted by position. Runs in O(n log n) for n
  /// candidates.
  static List<ZLRichMatch> resolve(String source, List<ZLRichRule> rules) {
    final List<_Candidate> candidates = <_Candidate>[];
    for (int i = 0; i < rules.length; i++) {
      final ZLRichRule rule = rules[i];
      for (final Match m in rule.pattern.allMatches(source)) {
        if (m.end > m.start) {
          candidates.add(_Candidate(m.start, m.end, rule.priority, i, rule, m));
        }
      }
    }
    candidates.sort((_Candidate a, _Candidate b) {
      if (a.priority != b.priority) return b.priority.compareTo(a.priority);
      if (a.start != b.start) return a.start.compareTo(b.start);
      if (a.end - a.start != b.end - b.start) {
        return (b.end - b.start).compareTo(a.end - a.start);
      }
      return a.order.compareTo(b.order);
    });
    // Accepted candidates never overlap and are sorted by position: a binary
    // search finds the insertion point, only the two neighbours can overlap.
    final List<_Candidate> accepted = <_Candidate>[];
    for (final _Candidate c in candidates) {
      int low = 0;
      int high = accepted.length;
      while (low < high) {
        final int mid = (low + high) >> 1;
        if (accepted[mid].start < c.start) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }
      if (low > 0 && accepted[low - 1].end > c.start) continue;
      if (low < accepted.length && accepted[low].start < c.end) continue;
      accepted.insert(low, c);
    }
    return <ZLRichMatch>[
      for (int i = 0; i < accepted.length; i++)
        ZLRichMatch(
            rule: accepted[i].rule,
            index: i,
            result: accepted[i].result,
            source: source),
    ];
  }

  /// Splits [source] into plain text and matches.
  static List<ZLRichSegment> segments(String source, List<ZLRichRule> rules) {
    return segmentsFromMatches(source, resolve(source, rules));
  }

  static List<ZLRichSegment> segmentsFromMatches(
      String source, List<ZLRichMatch> matches) {
    final List<ZLRichSegment> result = <ZLRichSegment>[];
    int cursor = 0;
    for (final ZLRichMatch match in matches) {
      if (match.range.start > cursor) {
        result.add(
            ZLRichSegment(source.substring(cursor, match.range.start), null));
      }
      result.add(ZLRichSegment(match.text, match));
      cursor = match.range.end;
    }
    if (cursor < source.length) {
      result.add(ZLRichSegment(source.substring(cursor), null));
    }
    return result;
  }
}
