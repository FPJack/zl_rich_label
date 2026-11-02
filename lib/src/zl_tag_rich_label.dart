import 'package:flutter/widgets.dart';

import 'zl_attributed_text.dart';
import 'zl_rich_label.dart';
import 'zl_rule.dart';
import 'zl_tag_parser.dart';
import 'zl_text_style.dart';

/// Style of a single tag (by index / name / level / text / attributes).
typedef ZLTagStyleBuilder = ZLTextStyle? Function(ZLTagInfo info);

/// Fully custom content of a tag (may contain inline widgets). `null` uses
/// the default rendering. The whole result is tappable when the tag is.
typedef ZLTagSpanBuilder = ZLAttributedText? Function(
    ZLTagInfo info, ZLTextStyle style);

/// An inline widget replacing the tag text, or placed before / after it
/// ([ZLRichWidget.position]). `null` uses the default rendering.
typedef ZLTagWidgetBuilder = ZLRichWidget? Function(
    ZLTagInfo info, ZLTextStyle style);

/// Tag tap / long press callback.
typedef ZLTagTapCallback = void Function(ZLTagInfo info);

/// Tag highlighting label: `<h>`, `<h1>`, `<h2>` … by default, any tag name
/// with attributes and nesting when configured. Styles, press highlights and
/// taps are configured per tag name. External [rules] work together with the
/// built-in tag rule (overlaps are resolved by priority).
///
/// ```dart
/// ZLTagRichLabel(
///   text: 'I agree to the <h1>User Agreement</h1> and <h2>Privacy Policy</h2>.',
///   style: ZLTextStyle().fontSize(14).color(Colors.grey),
///   tagStyle: ZLTextStyle().color(Colors.blue),
///   tagStyles: {'h2': ZLTextStyle().color(Colors.red)},
///   highlightStyle: ZLTextStyle().backgroundColor(const Color(0xFFE0E0E0)),
///   tagTapHandlers: {'h1': (_) => openAgreement(), 'h2': (_) => openPrivacy()},
///   onTagTap: (info) => print('${info.name} ${info.text}'),
/// )
/// ```
///
/// Styles merge in this order (later wins):
/// `DefaultTextStyle → style → tagStyle → tagStyles[name] → tagStyleBuilder(info)`.
/// Nested tags continue from the style of the outer tag.
class ZLTagRichLabel extends ZLRichLabel {
  const ZLTagRichLabel({
    super.key,
    required super.text,
    super.rules,
    super.style,
    super.highlightStyle,
    this.tagStyle = ZLTextStyle.none,
    this.tagStyles = const <String, ZLTextStyle>{},
    this.tagStyleBuilder,
    this.tagSpanBuilder,
    this.tagWidgetBuilder,
    this.tagHighlightStyles = const <String, ZLTextStyle>{},
    this.tagTapHandlers = const <String, ZLTagTapCallback>{},
    this.onTagTap,
    this.onTagLongPress,
    this.onParsed,
    this.tagPriority = 0,
    this.parsesTags = true,
    this.tagConfiguration = ZLTagParserConfiguration.hTags,
    super.truncationToken,
    super.expandToken,
    super.collapseToken,
    super.expanded,
    super.onExpandChanged,
    super.onExpandTokenTap,
    super.collapseThreshold,
    super.maxLines,
    super.truncationMode,
    super.textAlign,
    super.textDirection,
    super.textScaler,
    super.padding,
    super.verticalAlignment,
    super.adjustsFontSizeToFit,
    super.minimumScaleFactor,
    super.extendsLinkTouchArea,
    super.onLongPress,
    super.onDoubleTap,
    super.selectable,
    super.selectionColor,
    super.onSelectionChanged,
    super.onCopy,
    super.copyLabel,
    super.copyRawLabel,
    super.selectAllLabel,
    super.semanticsLabel,
    super.controller,
  });

  /// Name of the built-in tag rule.
  static const String tagRuleName = 'h-tag';

  /// Style of all tags (merged on top of [style]).
  final ZLTextStyle tagStyle;

  /// Style per lower-case tag name (`h`, `h1`, `b` …), merged on top of
  /// [tagStyle].
  final Map<String, ZLTextStyle> tagStyles;

  /// Style of a single tag, merged last.
  final ZLTagStyleBuilder? tagStyleBuilder;

  /// Fully custom content. Priority: [tagSpanBuilder] > [tagWidgetBuilder] >
  /// default text. When it returns content, inner tags are not rendered
  /// separately.
  final ZLTagSpanBuilder? tagSpanBuilder;

  /// Inline widgets for tags.
  final ZLTagWidgetBuilder? tagWidgetBuilder;

  /// Press highlight per tag name, overriding [highlightStyle];
  /// [ZLTextStyle.none] disables the highlight of a tag name.
  final Map<String, ZLTextStyle> tagHighlightStyles;

  /// Tap handlers per lower-case tag name. Tags without a handler call
  /// [onTagTap]; tags handled by neither are not tappable.
  final Map<String, ZLTagTapCallback> tagTapHandlers;

  /// Fallback tap of tags without an entry in [tagTapHandlers].
  final ZLTagTapCallback? onTagTap;

  /// Long press on a tag. When set, long pressing a tag only calls this;
  /// other positions call [onLongPress].
  final ZLTagTapCallback? onTagLongPress;

  /// All tags after parsing (outer tags first). Called after the frame when
  /// the parsed tags change (not again when the label only parses again with
  /// the same result).
  final ValueChanged<List<ZLTagInfo>>? onParsed;

  /// Priority of the built-in tag rule when it overlaps external rules.
  final int tagPriority;

  /// `false` turns the built-in tags off (only [rules] are used).
  final bool parsesTags;

  /// Recognised tag names, nesting and self-closing tags. Default: `<h>` /
  /// `<hN>` only. [ZLTagParserConfiguration.anyTags]: any tag name, nesting
  /// and self-closing tags.
  final ZLTagParserConfiguration tagConfiguration;

  @override
  State<ZLRichLabel> createState() => _ZLTagRichLabelState();
}

class _ZLTagRichLabelState extends ZLRichLabelState<ZLTagRichLabel> {
  ZLTagMarkupPattern? _pattern;
  ZLRichRule? _rule;
  List<ZLTagInfo> _tags = const <ZLTagInfo>[];
  Map<int, ZLTagElement> _rootByStart = const <int, ZLTagElement>{};
  Map<ZLTagElement, ZLTagInfo> _infoByElement =
      const <ZLTagElement, ZLTagInfo>{};
  Map<int, int> _rootIndexByStart = const <int, int>{};
  bool _notifyScheduled = false;

  /// Tags last reported through `onParsed` (`null`: not reported yet).
  List<ZLTagInfo>? _reportedTags;

  ZLRichRule get _tagRule {
    final ZLRichRule? cached = _rule;
    if (cached != null) return cached;
    final ZLTagMarkupPattern pattern =
        _pattern ??= ZLTagMarkupPattern(widget.tagConfiguration);
    return _rule = ZLRichRule(
      name: ZLTagRichLabel.tagRuleName,
      pattern: pattern,
      priority: widget.tagPriority,
      handler: _renderTag,
    );
  }

  @override
  List<ZLRichRule> get builtInRules =>
      widget.parsesTags ? <ZLRichRule>[_tagRule] : const <ZLRichRule>[];

  @override
  List<ZLTagInfo> get parsedTags => _tags;

  @override
  void didUpdateWidget(ZLTagRichLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tagConfiguration != widget.tagConfiguration ||
        oldWidget.tagPriority != widget.tagPriority) {
      if (oldWidget.tagConfiguration != widget.tagConfiguration) {
        _pattern = null;
      }
      _rule = null; // new rule object: parsed again, tags rendered again
      return;
    }
    // Render configuration of the tags: only the tags are rendered again,
    // external rule matches keep their cached results.
    if (oldWidget.tagStyle != widget.tagStyle ||
        !_mapEquals(oldWidget.tagStyles, widget.tagStyles) ||
        !_mapEquals(oldWidget.tagHighlightStyles, widget.tagHighlightStyles) ||
        !identical(oldWidget.tagStyleBuilder, widget.tagStyleBuilder) ||
        !identical(oldWidget.tagSpanBuilder, widget.tagSpanBuilder) ||
        !identical(oldWidget.tagWidgetBuilder, widget.tagWidgetBuilder) ||
        !_sameKeys(oldWidget.tagTapHandlers, widget.tagTapHandlers) ||
        (oldWidget.onTagTap == null) != (widget.onTagTap == null) ||
        (oldWidget.onTagLongPress == null) != (widget.onTagLongPress == null)) {
      invalidateRenderCache(ZLTagRichLabel.tagRuleName);
    }
  }

  static bool _mapEquals<V>(Map<String, V> a, Map<String, V> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final MapEntry<String, V> entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  static bool _sameKeys<V>(Map<String, V> a, Map<String, V> b) =>
      a.length == b.length && a.keys.every(b.containsKey);

  @override
  void didParse() {
    super.didParse();
    final List<ZLTagInfo> infos = <ZLTagInfo>[];
    final Map<ZLTagElement, ZLTagInfo> byElement = <ZLTagElement, ZLTagInfo>{};
    final Map<int, ZLTagElement> roots = <int, ZLTagElement>{};
    final Map<int, int> rootIndexes = <int, int>{};
    final ZLRichRule? rule = _rule;
    final ZLTagMarkupPattern? pattern = _pattern;
    final List<ZLRichMatch> tagMatches = rule == null
        ? const <ZLRichMatch>[]
        : matches.where((ZLRichMatch m) => identical(m.rule, rule)).toList();
    if (pattern != null && tagMatches.isNotEmpty) {
      final String source = tagMatches.first.source;
      final Map<int, ZLTagElement> documentRoots = <int, ZLTagElement>{
        for (final ZLTagElement root in pattern.document(source).roots)
          root.range.start: root,
      };
      for (final ZLRichMatch match in tagMatches) {
        final ZLTagElement? root = documentRoots[match.range.start];
        if (root == null) continue;
        roots[match.range.start] = root;
        rootIndexes[match.range.start] = infos.length;
        for (final ZLTagElement element in root.allElements) {
          final ZLTagInfo info = ZLTagParser.makeInfo(
              element, source, infos.length, byElement[element.parent]);
          byElement[element] = info;
          infos.add(info);
        }
      }
    }
    // Tag indexes changed (tags added / removed before): cached results hold
    // outdated tag infos.
    final bool indexesChanged = _rootIndexByStart.entries.any(
        (MapEntry<int, int> old) =>
            rootIndexes.containsKey(old.key) &&
            rootIndexes[old.key] != old.value);
    if (indexesChanged) invalidateRenderCache(ZLTagRichLabel.tagRuleName);
    _tags = infos;
    _infoByElement = byElement;
    _rootByStart = roots;
    _rootIndexByStart = rootIndexes;

    if (widget.onParsed == null || _notifyScheduled) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!mounted) return;
      // Parsing again (e.g. because the parent created new rule objects) must
      // not report the same tags again: a parent calling setState in onParsed
      // would rebuild forever.
      final List<ZLTagInfo>? reported = _reportedTags;
      if (reported != null && _sameTags(reported, _tags)) return;
      _reportedTags = _tags;
      widget.onParsed?.call(_tags);
    });
  }

  static bool _sameTags(List<ZLTagInfo> a, List<ZLTagInfo> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final ZLTagInfo x = a[i];
      final ZLTagInfo y = b[i];
      if (x.index != y.index ||
          x.name != y.name ||
          x.text != y.text ||
          x.raw != y.raw ||
          x.depth != y.depth ||
          !_mapEquals(x.attributes, y.attributes)) {
        return false;
      }
    }
    return true;
  }

  // MARK: Rendering

  void _renderTag(ZLRichRuleContext ctx) {
    final ZLTagElement? root = _rootByStart[ctx.match.range.start];
    if (root == null) return;
    final String source = ctx.match.source;
    final ZLAttributedTextBuilder output = ZLAttributedTextBuilder();
    final List<(TextRange, ZLTagInfo)> links = <(TextRange, ZLTagInfo)>[];
    _append(root, ctx.baseStyle, source, output, links, ctx);
    ctx.content.setText(output.build());

    // Outer tags first, inner tags last: inner tags win where they overlap.
    final ZLTagTapCallback? onLongPress = widget.onTagLongPress;
    for (final (TextRange range, ZLTagInfo info) in links) {
      ctx.addLink(
        range,
        highlightStyle: widget.tagHighlightStyles[info.name],
        onTap: _isTappable(info) ? (_) => _dispatchTap(info) : null,
        onLongPress: onLongPress == null
            ? null
            : (_) => widget.onTagLongPress?.call(info),
      );
    }
  }

  void _append(
      ZLTagElement element,
      ZLTextStyle inherited,
      String source,
      ZLAttributedTextBuilder output,
      List<(TextRange, ZLTagInfo)> links,
      ZLRichRuleContext ctx) {
    final ZLTagInfo? info = _infoByElement[element];
    if (info == null) {
      output.append(
          source.substring(element.range.start, element.range.end), inherited);
      return;
    }
    ZLTextStyle style = inherited.merge(widget.tagStyle);
    style = style.merge(widget.tagStyles[info.name]);
    style = style.merge(widget.tagStyleBuilder?.call(info));

    final int start = output.length;
    final int slot = links.length;
    links.add((TextRange.collapsed(start), info));

    final ZLAttributedText? custom = widget.tagSpanBuilder?.call(info, style);
    if (custom != null) {
      output.appendText(custom);
    } else {
      final ZLRichWidget? inline = widget.tagWidgetBuilder?.call(info, style);
      final ZLAttributedText? span =
          inline == null ? null : ctx.widgetText(inline, style);
      if (span != null && inline!.position == ZLRichWidgetPosition.replace) {
        output.appendText(span);
      } else {
        if (span != null && inline!.position == ZLRichWidgetPosition.before) {
          output.appendText(span);
        }
        for (final ZLTagNode child in element.children) {
          switch (child) {
            case ZLTagTextNode(:final TextRange range):
              output.append(source.substring(range.start, range.end), style);
            case ZLTagElementNode(element: final ZLTagElement inner):
              _append(inner, style, source, output, links, ctx);
          }
        }
        if (span != null && inline!.position == ZLRichWidgetPosition.after) {
          output.appendText(span);
        }
      }
    }
    links[slot] = (TextRange(start: start, end: output.length), info);
  }

  bool _isTappable(ZLTagInfo info) =>
      widget.tagTapHandlers.containsKey(info.name) || widget.onTagTap != null;

  void _dispatchTap(ZLTagInfo info) {
    final ZLTagTapCallback? handler = widget.tagTapHandlers[info.name];
    if (handler != null) {
      handler(info);
    } else {
      widget.onTagTap?.call(info);
    }
  }
}
