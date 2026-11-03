import 'package:flutter/widgets.dart';

import 'zl_text_style.dart';

/// Where a widget returned by `tagWidgetBuilder` is placed relative to the
/// tag text.
enum ZLRichWidgetPosition {
  /// The widget replaces the text.
  replace,

  /// The widget is shown before the text (the text is kept).
  before,

  /// The widget is shown after the text (the text is kept).
  after,
}

/// An inline widget embedded in the text (an inline `UIView` on iOS).
///
/// ```dart
/// ZLRichWidget(
///   child: const Icon(Icons.star, size: 16),
///   size: const Size(16, 16),          // null: measured from the child
///   alignment: PlaceholderAlignment.middle,
/// )
/// ```
///
/// The widget gets the text style of its position through [DefaultTextStyle]
/// and [IconTheme], so an [Icon] without colour follows the text colour
/// (including the press highlight colour), like template images on iOS.
///
/// When the size of the child changes the label lays the text out again
/// automatically.
@immutable
class ZLRichWidget {
  const ZLRichWidget({
    required this.child,
    this.size,
    this.position = ZLRichWidgetPosition.replace,
    this.alignment = PlaceholderAlignment.middle,
    this.tappable = true,
    this.semanticsLabel,
  });

  /// An [Icon] that follows the text colour unless [color] is given.
  factory ZLRichWidget.icon(
    IconData icon, {
    double size = 16,
    Color? color,
    ZLRichWidgetPosition position = ZLRichWidgetPosition.replace,
    PlaceholderAlignment alignment = PlaceholderAlignment.middle,
    bool tappable = true,
    String? semanticsLabel,
  }) {
    return ZLRichWidget(
      child: Icon(icon, size: size, color: color),
      size: Size(size, size),
      position: position,
      alignment: alignment,
      tappable: tappable,
      semanticsLabel: semanticsLabel,
    );
  }

  /// The widget to show.
  final Widget child;

  /// Fixed size of the widget. `null` lets the child size itself (it gets the
  /// available width as maximum).
  final Size? size;

  /// Only used by `ZLTagRichLabel.tagWidgetBuilder`.
  final ZLRichWidgetPosition position;

  /// Vertical alignment relative to the surrounding text.
  final PlaceholderAlignment alignment;

  /// Whether tapping the widget triggers the tap of the rule match / tag it
  /// belongs to. Set to `false` when the widget handles its own gestures
  /// (checkbox, button …).
  final bool tappable;

  /// Text used for accessibility and for the selected text.
  final String? semanticsLabel;
}

/// The character that represents an inline widget in the display text.
const String kZLObjectReplacementCharacter = '\uFFFC';

/// A run of [ZLAttributedText]: text with one style, or one inline widget.
@immutable
class ZLTextRun {
  const ZLTextRun(this.text,
      {this.style = ZLTextStyle.none, this.widget, this.group = 0})
      : assert(widget == null || text.length > 0);

  /// Text of the run. For widget runs this is the text the widget stands for
  /// in the display text (U+FFFC by default).
  final String text;

  final ZLTextStyle style;

  /// Inline widget, `null` for text runs.
  final ZLRichWidget? widget;

  /// Decoration group. Neighbouring runs with the same [ZLTextBackground] are
  /// painted as one capsule only when they are in the same group (every rule
  /// match gets its own group, so two adjacent `#topic#`s are two capsules).
  final int group;

  bool get isWidget => widget != null;

  int get length => text.length;

  ZLTextRun copyWith({String? text, ZLTextStyle? style, int? group}) =>
      ZLTextRun(text ?? this.text,
          style: style ?? this.style,
          widget: widget,
          group: group ?? this.group);

  @override
  String toString() =>
      isWidget ? 'ZLTextRun(widget, "$text")' : 'ZLTextRun("$text", $style)';
}

/// Immutable rich text: a list of [ZLTextRun]s (the Flutter counterpart of
/// `NSAttributedString` in the iOS library).
///
/// ```dart
/// final text = ZLAttributedText('Hello ', style: ZLTextStyle().fontSize(15)) +
///     ZLAttributedText('world', style: ZLTextStyle().bold().color(Colors.blue)) +
///     ZLAttributedText.widget(ZLRichWidget.icon(Icons.star));
/// ```
@immutable
class ZLAttributedText {
  /// Text with a single style.
  ZLAttributedText(String text, {ZLTextStyle style = ZLTextStyle.none})
      : runs = text.isEmpty
            ? const <ZLTextRun>[]
            : List<ZLTextRun>.unmodifiable(
                <ZLTextRun>[ZLTextRun(text, style: style)]);

  /// An inline widget. [text] is what it stands for in the display text.
  ZLAttributedText.widget(ZLRichWidget widget,
      {ZLTextStyle style = ZLTextStyle.none,
      String text = kZLObjectReplacementCharacter})
      : runs = List<ZLTextRun>.unmodifiable(
            <ZLTextRun>[ZLTextRun(text, style: style, widget: widget)]);

  /// Builds from runs (empty text runs are dropped, neighbours with the same
  /// style are joined).
  ZLAttributedText.fromRuns(Iterable<ZLTextRun> runs)
      : runs = List<ZLTextRun>.unmodifiable(_normalize(runs));

  const ZLAttributedText._(this.runs);

  /// The empty text.
  static const ZLAttributedText empty = ZLAttributedText._(<ZLTextRun>[]);

  /// Converts a Flutter [InlineSpan] tree. [TextSpan] styles are inherited
  /// like in Flutter, [WidgetSpan]s become inline widgets.
  factory ZLAttributedText.fromSpan(InlineSpan span,
      {ZLTextStyle style = ZLTextStyle.none}) {
    final List<ZLTextRun> runs = <ZLTextRun>[];
    void visit(InlineSpan span, TextStyle inherited) {
      final TextStyle current =
          span.style == null ? inherited : inherited.merge(span.style);
      if (span is TextSpan) {
        final String? text = span.text;
        if (text != null && text.isNotEmpty) {
          runs.add(ZLTextRun(text,
              style: style.merge(ZLTextStyle(textStyle: current))));
        }
        for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
          visit(child, current);
        }
      } else if (span is WidgetSpan) {
        runs.add(ZLTextRun(
          kZLObjectReplacementCharacter,
          style: style.merge(ZLTextStyle(textStyle: current)),
          widget: ZLRichWidget(child: span.child, alignment: span.alignment),
        ));
      }
    }

    visit(span, const TextStyle());
    return ZLAttributedText.fromRuns(runs);
  }

  final List<ZLTextRun> runs;

  static List<ZLTextRun> _normalize(Iterable<ZLTextRun> input) {
    final List<ZLTextRun> result = <ZLTextRun>[];
    for (final ZLTextRun run in input) {
      if (run.text.isEmpty) continue;
      if (result.isNotEmpty) {
        final ZLTextRun last = result.last;
        if (!last.isWidget &&
            !run.isWidget &&
            last.group == run.group &&
            last.style == run.style) {
          result[result.length - 1] = last.copyWith(text: last.text + run.text);
          continue;
        }
      }
      result.add(run);
    }
    return result;
  }

  /// The display string (inline widgets contribute their [ZLTextRun.text]).
  String get string {
    final StringBuffer buffer = StringBuffer();
    for (final ZLTextRun run in runs) {
      buffer.write(run.text);
    }
    return buffer.toString();
  }

  int get length {
    int total = 0;
    for (final ZLTextRun run in runs) {
      total += run.length;
    }
    return total;
  }

  bool get isEmpty => runs.isEmpty;

  bool get isNotEmpty => runs.isNotEmpty;

  /// Whether the text contains inline widgets.
  bool get hasWidgets => runs.any((ZLTextRun run) => run.isWidget);

  /// Runs together with their start offset.
  Iterable<(int, ZLTextRun)> get runsWithOffsets sync* {
    int offset = 0;
    for (final ZLTextRun run in runs) {
      yield (offset, run);
      offset += run.length;
    }
  }

  /// Style of the run at [index], `null` when out of range.
  ZLTextStyle? styleAt(int index) {
    for (final (int start, ZLTextRun run) in runsWithOffsets) {
      if (index >= start && index < start + run.length) return run.style;
    }
    return null;
  }

  ZLAttributedText operator +(ZLAttributedText other) {
    if (other.isEmpty) return this;
    if (isEmpty) return other;
    return ZLAttributedText.fromRuns(<ZLTextRun>[...runs, ...other.runs]);
  }

  /// The text between [start] and [end]. Widget runs are kept whole when the
  /// range covers part of them.
  ZLAttributedText substring(int start, [int? end]) {
    final int total = length;
    final int to = (end ?? total).clamp(0, total);
    final int from = start.clamp(0, to);
    if (from == 0 && to == total) return this;
    final List<ZLTextRun> result = <ZLTextRun>[];
    for (final (int offset, ZLTextRun run) in runsWithOffsets) {
      final int runEnd = offset + run.length;
      if (runEnd <= from || offset >= to) continue;
      if (run.isWidget) {
        result.add(run);
        continue;
      }
      final int s = (from - offset).clamp(0, run.length);
      final int e = (to - offset).clamp(0, run.length);
      result.add(run.copyWith(text: run.text.substring(s, e)));
    }
    return ZLAttributedText.fromRuns(result);
  }

  /// Merges [style] on top of the runs in [range] (all runs when `null`).
  ZLAttributedText applyingStyle(ZLTextStyle style, [TextRange? range]) {
    if (style.isEmpty || isEmpty) return this;
    final int from = range == null ? 0 : range.start;
    final int to = range == null ? length : range.end;
    if (from >= to) return this;
    final List<ZLTextRun> result = <ZLTextRun>[];
    for (final (int offset, ZLTextRun run) in runsWithOffsets) {
      final int runEnd = offset + run.length;
      if (runEnd <= from || offset >= to || run.isWidget) {
        result.add(runEnd <= from || offset >= to
            ? run
            : run.copyWith(style: run.style.merge(style)));
        continue;
      }
      final int s = (from - offset).clamp(0, run.length);
      final int e = (to - offset).clamp(0, run.length);
      if (s > 0) result.add(run.copyWith(text: run.text.substring(0, s)));
      result.add(run.copyWith(
          text: run.text.substring(s, e), style: run.style.merge(style)));
      if (e < run.length) result.add(run.copyWith(text: run.text.substring(e)));
    }
    return ZLAttributedText.fromRuns(result);
  }

  /// Puts [base] under every run: `base.merge(run.style)`.
  ZLAttributedText withBaseStyle(ZLTextStyle base) {
    if (base.isEmpty) return this;
    return ZLAttributedText.fromRuns(runs
        .map((ZLTextRun run) => run.copyWith(style: base.merge(run.style))));
  }

  /// Assigns a decoration group to every run, see [ZLTextRun.group].
  ZLAttributedText withGroup(int group) => ZLAttributedText.fromRuns(
      runs.map((ZLTextRun run) => run.copyWith(group: group)));

  /// Converts to a Flutter [TextSpan] (backgrounds, gradients and baseline
  /// offsets drawn by the label are dropped).
  TextSpan toTextSpan() {
    return TextSpan(
      children: <InlineSpan>[
        for (final ZLTextRun run in runs)
          if (run.isWidget)
            WidgetSpan(
                child: run.widget!.child,
                alignment: run.widget!.alignment,
                style: run.style.textStyle)
          else
            TextSpan(text: run.text, style: run.style.textStyle),
      ],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ZLAttributedText || other.runs.length != runs.length) {
      return false;
    }
    for (int i = 0; i < runs.length; i++) {
      final ZLTextRun a = runs[i];
      final ZLTextRun b = other.runs[i];
      if (a.text != b.text ||
          a.style != b.style ||
          a.group != b.group ||
          !identical(a.widget, b.widget)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
      runs.map((ZLTextRun run) => Object.hash(run.text, run.style, run.group)));

  @override
  String toString() => 'ZLAttributedText("$string", ${runs.length} runs)';
}

/// Mutable builder for [ZLAttributedText], used by rule handlers.
class ZLAttributedTextBuilder {
  ZLAttributedTextBuilder([ZLAttributedText initial = ZLAttributedText.empty])
      : _runs = <ZLTextRun>[...initial.runs];

  final List<ZLTextRun> _runs;

  int get length {
    int total = 0;
    for (final ZLTextRun run in _runs) {
      total += run.length;
    }
    return total;
  }

  bool get isEmpty => _runs.isEmpty;

  /// Current display string.
  String get string => _runs.map((ZLTextRun run) => run.text).join();

  /// Appends [text] with [style].
  void append(String text, [ZLTextStyle style = ZLTextStyle.none]) {
    if (text.isNotEmpty) _runs.add(ZLTextRun(text, style: style));
  }

  /// Appends an inline widget.
  void appendWidget(ZLRichWidget widget,
      [ZLTextStyle style = ZLTextStyle.none]) {
    _runs.add(
        ZLTextRun(kZLObjectReplacementCharacter, style: style, widget: widget));
  }

  /// Appends rich text.
  void appendText(ZLAttributedText text) => _runs.addAll(text.runs);

  /// Replaces the content.
  void setText(ZLAttributedText text) {
    _runs
      ..clear()
      ..addAll(text.runs);
  }

  /// Merges [style] on top of the runs in [range] (everything when `null`).
  void addStyle(ZLTextStyle style, [TextRange? range]) {
    final ZLAttributedText updated = build().applyingStyle(style, range);
    setText(updated);
  }

  void clear() => _runs.clear();

  ZLAttributedText build() => ZLAttributedText.fromRuns(_runs);
}
