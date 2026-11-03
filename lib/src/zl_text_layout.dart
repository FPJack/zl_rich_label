import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'zl_attributed_text.dart';
import 'zl_statistics.dart';
import 'zl_text_style.dart';

/// How a single line is truncated. Multi-line text is always truncated at
/// the end of the last line.
enum ZLTruncationMode {
  /// `Long text…`
  tail,

  /// `…ong text` (single line only).
  head,

  /// `Lon…text` (single line only).
  middle,
}

/// Vertical position of the text when the label is taller than the text.
enum ZLVerticalAlignment { top, center, bottom }

/// Result of hit testing the text: a character of the content, or the
/// truncation token.
@immutable
class ZLTextHit {
  const ZLTextHit.content(int this.index) : isToken = false;

  const ZLTextHit.token()
      : index = null,
        isToken = true;

  /// Index in the display content, `null` for the token.
  final int? index;

  final bool isToken;
}

/// A link exposed to accessibility services as its own node.
@immutable
class ZLSemanticsLink {
  const ZLSemanticsLink(
      {required this.range,
      required this.label,
      this.hint,
      this.onTap,
      this.onLongPress,
      this.isButton = false});

  /// Range in the display content.
  final TextRange range;
  final String label;
  final String? hint;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isButton;
}

enum _PieceKind { text, atomic, spacer, tokenText, tokenAtomic }

/// One piece of the paragraph and where it comes from.
class _Piece {
  _Piece(this.kind, this.paraStart, this.paraLength, this.displayStart,
      this.displayLength);

  final _PieceKind kind;
  final int paraStart;
  final int paraLength;

  /// Content offset (token offset for token pieces; the character a spacer
  /// belongs to for spacers).
  final int displayStart;
  final int displayLength;

  int get paraEnd => paraStart + paraLength;

  int get displayEnd => displayStart + displayLength;

  bool get isContent => kind == _PieceKind.text || kind == _PieceKind.atomic;

  bool get isToken =>
      kind == _PieceKind.tokenText || kind == _PieceKind.tokenAtomic;
}

/// A background / gradient occurrence in the paragraph.
class _Decoration {
  _Decoration(
      this.paraStart, this.paraEnd, this.background, this.gradient, this.shift);

  final int paraStart;
  int paraEnd;
  final ZLTextBackground? background;
  final Gradient? gradient;

  /// Vertical shift (baseline offset of baseline-shifted runs).
  final double shift;
}

/// A slice of content (or the token) to put into the paragraph.
class _Slice {
  const _Slice(this.text, this.displayStart, {this.isToken = false});

  final ZLAttributedText text;
  final int displayStart;
  final bool isToken;
}

/// A paragraph ready to be laid out.
class _Paragraph {
  _Paragraph(this.span, this.maskSpan, this.pieces, this.placeholders,
      this.backgrounds, this.gradients);

  final InlineSpan span;
  final InlineSpan? maskSpan;
  final List<_Piece> pieces;

  /// Child index of every placeholder, `-1 - width` encodes spacers.
  final List<_Placeholder> placeholders;
  final List<_Decoration> backgrounds;
  final List<_Decoration> gradients;

  _Piece? pieceAt(int paraOffset) {
    int low = 0;
    int high = pieces.length - 1;
    while (low <= high) {
      final int mid = (low + high) >> 1;
      final _Piece piece = pieces[mid];
      if (paraOffset < piece.paraStart) {
        high = mid - 1;
      } else if (paraOffset >= piece.paraEnd) {
        low = mid + 1;
      } else {
        return piece;
      }
    }
    return null;
  }

  ZLTextHit? hitAt(int paraOffset) {
    final _Piece? piece = pieceAt(paraOffset);
    if (piece == null) return null;
    switch (piece.kind) {
      case _PieceKind.text:
        return ZLTextHit.content(
            piece.displayStart + (paraOffset - piece.paraStart));
      case _PieceKind.atomic:
      case _PieceKind.spacer:
        return ZLTextHit.content(piece.displayStart);
      case _PieceKind.tokenText:
      case _PieceKind.tokenAtomic:
        return const ZLTextHit.token();
    }
  }

  /// Paragraph ranges covering a display range of the content.
  List<TextRange> paragraphRanges(TextRange display) {
    final List<TextRange> result = <TextRange>[];
    for (final _Piece piece in pieces) {
      if (!piece.isContent) continue;
      final int s = math.max(display.start, piece.displayStart);
      final int e = math.min(display.end, piece.displayEnd);
      if (s >= e) continue;
      final int ps = piece.kind == _PieceKind.text
          ? piece.paraStart + (s - piece.displayStart)
          : piece.paraStart;
      final int pe = piece.kind == _PieceKind.text
          ? piece.paraStart + (e - piece.displayStart)
          : piece.paraEnd;
      if (result.isNotEmpty && result.last.end == ps) {
        result[result.length - 1] =
            TextRange(start: result.last.start, end: pe);
      } else {
        result.add(TextRange(start: ps, end: pe));
      }
    }
    return result;
  }

  /// Display caret for a paragraph caret position.
  int displayCaret(int paraOffset) {
    int lastContentEnd = 0;
    for (final _Piece piece in pieces) {
      if (piece.isContent && piece.paraEnd <= paraOffset) {
        lastContentEnd = piece.displayEnd;
      }
      if (paraOffset < piece.paraStart || paraOffset > piece.paraEnd) continue;
      switch (piece.kind) {
        case _PieceKind.text:
          return piece.displayStart + (paraOffset - piece.paraStart);
        case _PieceKind.atomic:
          return paraOffset == piece.paraStart
              ? piece.displayStart
              : piece.displayEnd;
        case _PieceKind.spacer:
        case _PieceKind.tokenText:
        case _PieceKind.tokenAtomic:
          continue;
      }
    }
    return lastContentEnd;
  }

  /// Paragraph offset of the end of the content (before the token).
  int get contentParagraphEnd {
    int end = 0;
    for (final _Piece piece in pieces) {
      if (!piece.isToken) end = math.max(end, piece.paraEnd);
    }
    return end;
  }

  TextRange? get tokenRange {
    int? start;
    int end = 0;
    for (final _Piece piece in pieces) {
      if (!piece.isToken) continue;
      start ??= piece.paraStart;
      end = piece.paraEnd;
    }
    return start == null ? null : TextRange(start: start, end: end);
  }
}

class _Placeholder {
  const _Placeholder.child(this.childIndex) : spacerWidth = 0;

  const _Placeholder.spacer(this.spacerWidth) : childIndex = -1;

  final int childIndex;
  final double spacerWidth;

  bool get isSpacer => childIndex < 0;
}

/// The result of one layout pass.
class _Layout {
  _Layout({
    required this.paragraph,
    required this.painter,
    required this.dims,
    required this.size,
    required this.textOffset,
    required this.truncated,
    required this.fontScale,
    required this.lineCount,
    required this.visibleContentLength,
  });

  final _Paragraph paragraph;
  final TextPainter painter;
  final List<PlaceholderDimensions> dims;
  final Size size;
  final Offset textOffset;
  final bool truncated;
  final double fontScale;
  final int lineCount;
  final int visibleContentLength;
  TextPainter? maskPainter;

  void dispose() {
    painter.dispose();
    maskPainter?.dispose();
  }
}

/// Parent data of the inline widgets.
class ZLTextParentData extends ContainerBoxParentData<RenderBox> {
  /// Whether the child is in the visible (possibly truncated) text.
  bool visible = false;
}

/// Lays out [ZLAttributedText] with inline widgets, custom truncation tokens,
/// capsule backgrounds, gradient text and selection highlights.
///
/// This is the rendering core shared by all labels of the package.
class ZLTextLayout extends MultiChildRenderObjectWidget {
  const ZLTextLayout({
    super.key,
    required this.content,
    this.token,
    required this.baseStyle,
    this.lineSpacing,
    this.textAlign = TextAlign.start,
    required this.textDirection,
    this.textScaler = TextScaler.noScaling,
    this.maxLines,
    this.collapseThreshold = 0,
    this.truncationMode = ZLTruncationMode.tail,
    this.padding = EdgeInsets.zero,
    this.verticalAlignment = ZLVerticalAlignment.center,
    this.adjustsFontSizeToFit = false,
    this.minimumScaleFactor = 0,
    this.selection,
    this.selectionColor = const Color(0x402196F3),
    this.semanticsLabel,
    this.semanticsLinks = const <ZLSemanticsLink>[],
    this.statistics,
    super.children,
  });

  /// Display content. Widget runs map to [children] in order, followed by the
  /// widget runs of [token].
  final ZLAttributedText content;

  /// Shown at the end of the truncated text.
  final ZLAttributedText? token;
  final TextStyle baseStyle;
  final double? lineSpacing;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final int? maxLines;
  final int collapseThreshold;
  final ZLTruncationMode truncationMode;
  final EdgeInsets padding;
  final ZLVerticalAlignment verticalAlignment;
  final bool adjustsFontSizeToFit;
  final double minimumScaleFactor;
  final TextRange? selection;
  final Color selectionColor;
  final String? semanticsLabel;
  final List<ZLSemanticsLink> semanticsLinks;
  final ZLLabelStatistics? statistics;

  @override
  RenderZLText createRenderObject(BuildContext context) {
    return RenderZLText(
      content: content,
      token: token,
      baseStyle: baseStyle,
      lineSpacing: lineSpacing,
      textAlign: textAlign,
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: maxLines,
      collapseThreshold: collapseThreshold,
      truncationMode: truncationMode,
      padding: padding,
      verticalAlignment: verticalAlignment,
      adjustsFontSizeToFit: adjustsFontSizeToFit,
      minimumScaleFactor: minimumScaleFactor,
      selection: selection,
      selectionColor: selectionColor,
      semanticsLabel: semanticsLabel,
      semanticsLinks: semanticsLinks,
      statistics: statistics,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderZLText renderObject) {
    renderObject
      ..content = content
      ..token = token
      ..baseStyle = baseStyle
      ..lineSpacing = lineSpacing
      ..textAlign = textAlign
      ..textDirection = textDirection
      ..textScaler = textScaler
      ..maxLines = maxLines
      ..collapseThreshold = collapseThreshold
      ..truncationMode = truncationMode
      ..padding = padding
      ..verticalAlignment = verticalAlignment
      ..adjustsFontSizeToFit = adjustsFontSizeToFit
      ..minimumScaleFactor = minimumScaleFactor
      ..selection = selection
      ..selectionColor = selectionColor
      ..semanticsLabel = semanticsLabel
      ..semanticsLinks = semanticsLinks
      ..statistics = statistics;
  }
}

/// Render object of [ZLTextLayout].
class RenderZLText extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, ZLTextParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, ZLTextParentData> {
  RenderZLText({
    required ZLAttributedText content,
    ZLAttributedText? token,
    required TextStyle baseStyle,
    double? lineSpacing,
    TextAlign textAlign = TextAlign.start,
    required TextDirection textDirection,
    TextScaler textScaler = TextScaler.noScaling,
    int? maxLines,
    int collapseThreshold = 0,
    ZLTruncationMode truncationMode = ZLTruncationMode.tail,
    EdgeInsets padding = EdgeInsets.zero,
    ZLVerticalAlignment verticalAlignment = ZLVerticalAlignment.center,
    bool adjustsFontSizeToFit = false,
    double minimumScaleFactor = 0,
    TextRange? selection,
    Color selectionColor = const Color(0x402196F3),
    String? semanticsLabel,
    List<ZLSemanticsLink> semanticsLinks = const <ZLSemanticsLink>[],
    this.statistics,
  })  : _content = content,
        _token = token,
        _baseStyle = baseStyle,
        _lineSpacing = lineSpacing,
        _textAlign = textAlign,
        _textDirection = textDirection,
        _textScaler = textScaler,
        _maxLines = maxLines,
        _collapseThreshold = collapseThreshold,
        _truncationMode = truncationMode,
        _padding = padding,
        _verticalAlignment = verticalAlignment,
        _adjustsFontSizeToFit = adjustsFontSizeToFit,
        _minimumScaleFactor = minimumScaleFactor,
        _selection = selection,
        _selectionColor = selectionColor,
        _semanticsLabel = semanticsLabel,
        _semanticsLinks = semanticsLinks;

  ZLLabelStatistics? statistics;

  ZLAttributedText _content;
  ZLAttributedText get content => _content;
  set content(ZLAttributedText value) {
    if (_content == value) return;
    _content = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  ZLAttributedText? _token;
  ZLAttributedText? get token => _token;
  set token(ZLAttributedText? value) {
    if (_token == value) return;
    _token = value;
    markNeedsLayout();
  }

  TextStyle _baseStyle;
  TextStyle get baseStyle => _baseStyle;
  set baseStyle(TextStyle value) {
    if (_baseStyle == value) return;
    _baseStyle = value;
    markNeedsLayout();
  }

  double? _lineSpacing;
  double? get lineSpacing => _lineSpacing;
  set lineSpacing(double? value) {
    if (_lineSpacing == value) return;
    _lineSpacing = value;
    markNeedsLayout();
  }

  TextAlign _textAlign;
  TextAlign get textAlign => _textAlign;
  set textAlign(TextAlign value) {
    if (_textAlign == value) return;
    _textAlign = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  TextScaler _textScaler;
  TextScaler get textScaler => _textScaler;
  set textScaler(TextScaler value) {
    if (_textScaler == value) return;
    _textScaler = value;
    markNeedsLayout();
  }

  int? _maxLines;
  int? get maxLines => _maxLines;
  set maxLines(int? value) {
    if (_maxLines == value) return;
    _maxLines = value;
    markNeedsLayout();
  }

  int _collapseThreshold;
  int get collapseThreshold => _collapseThreshold;
  set collapseThreshold(int value) {
    if (_collapseThreshold == value) return;
    _collapseThreshold = value;
    markNeedsLayout();
  }

  ZLTruncationMode _truncationMode;
  ZLTruncationMode get truncationMode => _truncationMode;
  set truncationMode(ZLTruncationMode value) {
    if (_truncationMode == value) return;
    _truncationMode = value;
    markNeedsLayout();
  }

  EdgeInsets _padding;
  EdgeInsets get padding => _padding;
  set padding(EdgeInsets value) {
    if (_padding == value) return;
    _padding = value;
    markNeedsLayout();
  }

  ZLVerticalAlignment _verticalAlignment;
  ZLVerticalAlignment get verticalAlignment => _verticalAlignment;
  set verticalAlignment(ZLVerticalAlignment value) {
    if (_verticalAlignment == value) return;
    _verticalAlignment = value;
    markNeedsLayout();
  }

  bool _adjustsFontSizeToFit;
  bool get adjustsFontSizeToFit => _adjustsFontSizeToFit;
  set adjustsFontSizeToFit(bool value) {
    if (_adjustsFontSizeToFit == value) return;
    _adjustsFontSizeToFit = value;
    markNeedsLayout();
  }

  double _minimumScaleFactor;
  double get minimumScaleFactor => _minimumScaleFactor;
  set minimumScaleFactor(double value) {
    if (_minimumScaleFactor == value) return;
    _minimumScaleFactor = value;
    markNeedsLayout();
  }

  TextRange? _selection;
  TextRange? get selection => _selection;
  set selection(TextRange? value) {
    if (_selection == value) return;
    _selection = value;
    markNeedsPaint();
  }

  Color _selectionColor;
  Color get selectionColor => _selectionColor;
  set selectionColor(Color value) {
    if (_selectionColor == value) return;
    _selectionColor = value;
    markNeedsPaint();
  }

  String? _semanticsLabel;
  String? get semanticsLabel => _semanticsLabel;
  set semanticsLabel(String? value) {
    if (_semanticsLabel == value) return;
    _semanticsLabel = value;
    markNeedsSemanticsUpdate();
  }

  List<ZLSemanticsLink> _semanticsLinks;
  List<ZLSemanticsLink> get semanticsLinks => _semanticsLinks;
  set semanticsLinks(List<ZLSemanticsLink> value) {
    _semanticsLinks = value;
    markNeedsSemanticsUpdate();
  }

  // MARK: Layout

  _Layout? _layout;
  final Map<BoxConstraints, _Layout> _dryLayouts = <BoxConstraints, _Layout>{};

  /// Whether [_layout] matches the current properties and constraints.
  bool _layoutValid = false;

  @override
  void markNeedsLayout() {
    _layoutValid = false;
    _clearDryLayouts();
    super.markNeedsLayout();
  }

  void _clearDryLayouts() {
    for (final _Layout layout in _dryLayouts.values) {
      layout.dispose();
    }
    _dryLayouts.clear();
  }

  @override
  void dispose() {
    _layout?.dispose();
    _layout = null;
    _clearDryLayouts();
    super.dispose();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ZLTextParentData) {
      child.parentData = ZLTextParentData();
    }
  }

  /// Number of inline widgets of the content (token widgets follow).
  int get _contentWidgetCount =>
      _content.runs.where((ZLTextRun run) => run.isWidget).length;

  List<ZLTextRun> get _widgetRuns => <ZLTextRun>[
        ..._content.runs.where((ZLTextRun run) => run.isWidget),
        ...?_token?.runs.where((ZLTextRun run) => run.isWidget),
      ];

  /// Lays out (or dry lays out) the children; returns their dimensions.
  List<PlaceholderDimensions> _childDimensions(double maxWidth,
      {required bool dry}) {
    final List<ZLTextRun> runs = _widgetRuns;
    final List<PlaceholderDimensions> result = <PlaceholderDimensions>[];
    int i = 0;
    for (RenderBox? child = firstChild;
        child != null;
        child = childAfter(child), i++) {
      final ZLRichWidget? widget = i < runs.length ? runs[i].widget : null;
      final Size? fixed = widget?.size;
      final BoxConstraints constraints = fixed != null
          ? BoxConstraints.tight(fixed)
          : BoxConstraints(
              maxWidth:
                  maxWidth.isFinite ? math.max(0, maxWidth) : double.infinity);
      final Size size;
      if (dry) {
        size = child.getDryLayout(constraints);
      } else {
        child.layout(constraints, parentUsesSize: true);
        size = child.size;
      }
      final PlaceholderAlignment alignment =
          widget?.alignment ?? PlaceholderAlignment.middle;
      double? baselineOffset;
      if (alignment == PlaceholderAlignment.baseline) {
        baselineOffset = dry
            ? child.getDryBaseline(constraints, TextBaseline.alphabetic)
            : child.getDistanceToBaseline(TextBaseline.alphabetic,
                onlyReal: true);
        baselineOffset ??= size.height;
      }
      result.add(PlaceholderDimensions(
        size: size,
        alignment: alignment,
        baseline: TextBaseline.alphabetic,
        baselineOffset: baselineOffset,
      ));
    }
    return result;
  }

  StrutStyle? get _strut {
    final double? spacing = _lineSpacing;
    if (spacing == null || spacing <= 0) return null;
    final double fontSize = _baseStyle.fontSize ?? 14;
    return StrutStyle(
      fontSize: fontSize,
      fontFamily: _baseStyle.fontFamily,
      fontFamilyFallback: _baseStyle.fontFamilyFallback,
      height: _baseStyle.height,
      leading: spacing / fontSize,
    );
  }

  static TextStyle _withColor(TextStyle style, Color color) {
    if (style.foreground != null) {
      return style.copyWith(foreground: Paint()..color = color);
    }
    return style.copyWith(color: color);
  }

  /// Builds the paragraph for [slices].
  _Paragraph _buildParagraph(List<_Slice> slices, int contentWidgetCount) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final List<InlineSpan> maskSpans = <InlineSpan>[];
    final List<_Piece> pieces = <_Piece>[];
    final List<_Placeholder> placeholders = <_Placeholder>[];
    final List<_Decoration> backgrounds = <_Decoration>[];
    final List<_Decoration> gradients = <_Decoration>[];
    bool needsMask = false;
    int para = 0;
    int tokenWidget = 0;

    // Content widget run offset → child index.
    final Map<int, int> childAtOffset = <int, int>{};
    int childIndex = 0;
    for (final (int offset, ZLTextRun run) in _content.runsWithOffsets) {
      if (run.isWidget) childAtOffset[offset] = childIndex++;
    }

    void addSpacer(double width, int attachTo) {
      if (width <= 0) return;
      const WidgetSpan span = WidgetSpan(
          child: SizedBox.shrink(), alignment: PlaceholderAlignment.middle);
      spans.add(span);
      maskSpans.add(span);
      placeholders.add(_Placeholder.spacer(width));
      pieces.add(_Piece(_PieceKind.spacer, para, 1, attachTo, 0));
      para += 1;
    }

    for (final _Slice slice in slices) {
      _Decoration? background;
      ZLTextBackground? backgroundValue;
      int backgroundGroup = 0;
      _Decoration? gradient;
      Gradient? gradientValue;
      int gradientGroup = 0;
      int display = slice.displayStart;
      bool atParagraphStart = !slice.isToken &&
          (slice.displayStart == 0 ||
              _content.string.codeUnitAt(slice.displayStart - 1) == 0x0A);

      void closeBackground(int attachTo) {
        final _Decoration? current = background;
        if (current == null) return;
        addSpacer(
            backgroundValue!.padding.right + backgroundValue!.margin, attachTo);
        background = null;
        backgroundValue = null;
      }

      for (final (int offset, ZLTextRun run) in slice.text.runsWithOffsets) {
        display = slice.displayStart + offset;
        final ZLTextStyle style = run.style;
        final double shift = run.isWidget ? (style.baselineOffset ?? 0) : 0;

        // Capsule backgrounds: one occurrence per (background, group).
        if (background != null &&
            (style.background != backgroundValue ||
                run.group != backgroundGroup)) {
          closeBackground(math.max(0, display - 1));
        }
        if (style.background != null && background == null) {
          addSpacer(style.background!.padding.left + style.background!.margin,
              display);
          backgroundValue = style.background;
          backgroundGroup = run.group;
          background = _Decoration(para, para, style.background, null, shift);
          backgrounds.add(background!);
        }
        // Gradients: one occurrence per (gradient, group).
        if (gradient != null &&
            (style.gradient != gradientValue || run.group != gradientGroup)) {
          gradient = null;
        }
        if (style.gradient != null && gradient == null) {
          gradientValue = style.gradient;
          gradientGroup = run.group;
          gradient = _Decoration(para, para, null, style.gradient, shift);
          gradients.add(gradient);
          needsMask = true;
        }

        TextStyle paint = style.textStyle;
        if (style.gradient != null) {
          paint = _withColor(paint, const Color(0x00000000))
              .copyWith(decorationColor: const Color(0x00000000));
        }
        TextStyle mask = _withColor(
                style.textStyle,
                style.gradient != null
                    ? const Color(0xFF000000)
                    : const Color(0x00000000))
            .copyWith(
                decoration: TextDecoration.none, shadows: const <Shadow>[]);
        if (mask.background == null && mask.backgroundColor != null) {
          mask = mask.copyWith(backgroundColor: const Color(0x00000000));
        }

        if (run.isWidget) {
          final ZLRichWidget widget = run.widget!;
          final WidgetSpan span = WidgetSpan(
            child: const SizedBox.shrink(),
            alignment: widget.alignment,
            baseline: TextBaseline.alphabetic,
            style: paint,
          );
          spans.add(span);
          maskSpans.add(WidgetSpan(
              child: const SizedBox.shrink(),
              alignment: widget.alignment,
              baseline: TextBaseline.alphabetic,
              style: mask));
          final int child = slice.isToken
              ? contentWidgetCount + tokenWidget++
              : (childAtOffset[display] ?? -1);
          placeholders.add(_Placeholder.child(child));
          pieces.add(_Piece(
              slice.isToken ? _PieceKind.tokenAtomic : _PieceKind.atomic,
              para,
              1,
              slice.isToken ? offset : display,
              run.length));
          para += 1;
          atParagraphStart = false;
        } else {
          // First-line indent: a spacer at the start of every paragraph.
          final double indent = style.firstLineIndent ?? 0;
          int start = 0;
          final String text = run.text;
          while (start < text.length) {
            if (atParagraphStart && indent > 0 && !slice.isToken) {
              addSpacer(indent, display + start);
            }
            int end = text.length;
            if (indent > 0) {
              final int newline = text.indexOf('\n', start);
              if (newline >= 0) end = newline + 1;
            }
            final String part = text.substring(start, end);
            spans.add(TextSpan(text: part, style: paint));
            maskSpans.add(TextSpan(text: part, style: mask));
            pieces.add(_Piece(
                slice.isToken ? _PieceKind.tokenText : _PieceKind.text,
                para,
                part.length,
                slice.isToken ? offset + start : display + start,
                part.length));
            para += part.length;
            atParagraphStart = part.endsWith('\n');
            start = end;
          }
        }
        background?.paraEnd = para;
        gradient?.paraEnd = para;
        display = slice.displayStart + offset + run.length;
      }
      closeBackground(math.max(0, display - 1));
    }

    return _Paragraph(
      TextSpan(style: _baseStyle, children: spans),
      needsMask
          ? TextSpan(
              style: _withColor(_baseStyle, const Color(0x00000000)),
              children: maskSpans)
          : null,
      pieces,
      placeholders,
      backgrounds,
      gradients,
    );
  }

  TextPainter _painter(_Paragraph paragraph,
      List<PlaceholderDimensions> childDims, TextScaler scaler,
      {double minWidth = 0, required double maxWidth, bool mask = false}) {
    final TextPainter painter = TextPainter(
      text: mask ? paragraph.maskSpan : paragraph.span,
      textAlign: _textAlign,
      textDirection: _textDirection,
      textScaler: scaler,
      strutStyle: _strut,
      textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: false, applyHeightToLastDescent: false),
    );
    painter.setPlaceholderDimensions(<PlaceholderDimensions>[
      for (final _Placeholder p in paragraph.placeholders)
        if (p.isSpacer)
          PlaceholderDimensions(
              size: Size(p.spacerWidth, 0),
              alignment: PlaceholderAlignment.middle)
        else if (p.childIndex < childDims.length)
          childDims[p.childIndex]
        else
          PlaceholderDimensions.empty,
    ]);
    painter.layout(minWidth: math.min(minWidth, maxWidth), maxWidth: maxWidth);
    statistics?.textLayouts += 1;
    return painter;
  }

  /// Scales the inherited text scaler by [factor].
  TextScaler _scaled(double factor) {
    if (factor >= 1) return _textScaler;
    final double size = _baseStyle.fontSize ?? 14;
    return TextScaler.linear(_textScaler.scale(size) / size * factor);
  }

  _Layout _computeLayout(BoxConstraints constraints, {required bool dry}) {
    final EdgeInsets pad = _padding;
    final double maxWidth = math.max(0, constraints.maxWidth - pad.horizontal);
    final double minWidth = math.max(0, constraints.minWidth - pad.horizontal);
    final double maxHeight = constraints.hasBoundedHeight
        ? math.max(0, constraints.maxHeight - pad.vertical)
        : double.infinity;
    final List<PlaceholderDimensions> childDims =
        _childDimensions(maxWidth, dry: dry);
    final int contentWidgets = _contentWidgetCount;
    final ZLAttributedText content = _content;
    final ZLAttributedText token = _token ?? ZLAttributedText.empty;
    final _Paragraph full =
        _buildParagraph(<_Slice>[_Slice(content, 0)], contentWidgets);

    int? limit = (_maxLines ?? 0) > 0 ? _maxLines : null;

    // Font fitting: the largest scale in [minimumScaleFactor, 1] that fits.
    double scale = 1;
    if (_adjustsFontSizeToFit &&
        _minimumScaleFactor > 0 &&
        _minimumScaleFactor < 1 &&
        content.isNotEmpty) {
      bool fits(double s) {
        final TextPainter p = _painter(full, childDims, _scaled(s),
            maxWidth: limit == 1 ? double.infinity : maxWidth);
        final bool result;
        if (limit == 1) {
          result = p.maxIntrinsicWidth <= maxWidth + 0.25;
        } else {
          final int lines = p.computeLineMetrics().length;
          result = (limit == null || lines <= limit) &&
              (maxHeight.isInfinite || p.height <= maxHeight + 0.5);
        }
        p.dispose();
        return result;
      }

      if (!fits(1)) {
        final double minimum = _minimumScaleFactor;
        if (fits(minimum)) {
          double low = minimum;
          double high = 1;
          for (int i = 0; i < 8; i++) {
            final double mid = (low + high) / 2;
            if (fits(mid)) {
              low = mid;
            } else {
              high = mid;
            }
          }
          scale = low;
        } else {
          scale = minimum;
        }
      }
    }
    final TextScaler scaler = _scaled(scale);

    TextPainter painter = _painter(full, childDims, scaler,
        minWidth: minWidth, maxWidth: maxWidth);
    final List<ui.LineMetrics> lines = painter.computeLineMetrics();
    final int lineCount = lines.length;
    if (limit != null &&
        _collapseThreshold > limit &&
        lineCount <= _collapseThreshold) {
      limit = null;
    }
    // A bounded height limits the number of lines as well.
    if (maxHeight.isFinite && painter.height > maxHeight + 0.5) {
      int fitting = 0;
      for (final ui.LineMetrics line in lines) {
        if (line.baseline + line.descent <= maxHeight + 0.5) fitting++;
      }
      fitting = math.max(1, fitting);
      limit = limit == null ? fitting : math.min(limit, fitting);
    }

    _Paragraph paragraph = full;
    bool truncated = false;
    int visibleLength = content.length;
    if (limit != null && lineCount > limit) {
      truncated = true;
      final int lineLimit = limit;
      bool fits(List<_Slice> slices) {
        final _Paragraph candidate = _buildParagraph(slices, contentWidgets);
        final TextPainter p =
            _painter(candidate, childDims, scaler, maxWidth: maxWidth);
        final bool result = p.computeLineMetrics().length <= lineLimit;
        p.dispose();
        return result;
      }

      final List<_Slice> best;
      if (lineLimit == 1 && _truncationMode == ZLTruncationMode.head) {
        int low = 0;
        int high = content.length;
        while (low < high) {
          final int mid = (low + high) >> 1;
          if (fits(<_Slice>[
            _Slice(token, 0, isToken: true),
            _Slice(content.substring(_snap(content, mid)), _snap(content, mid))
          ])) {
            high = mid;
          } else {
            low = mid + 1;
          }
        }
        final int start = _snap(content, low, forward: true);
        best = <_Slice>[
          _Slice(token, 0, isToken: true),
          _Slice(content.substring(start), start)
        ];
        visibleLength = content.length - start;
      } else if (lineLimit == 1 && _truncationMode == ZLTruncationMode.middle) {
        List<_Slice> middle(int keep) {
          final int head = _snap(content, (keep + 1) >> 1);
          final int tail =
              _snap(content, content.length - (keep >> 1), forward: true);
          return <_Slice>[
            _Slice(content.substring(0, head), 0),
            _Slice(token, 0, isToken: true),
            _Slice(content.substring(tail), tail),
          ];
        }

        int low = 0;
        int high = content.length;
        while (low < high) {
          final int mid = (low + high + 1) >> 1;
          if (fits(middle(mid))) {
            low = mid;
          } else {
            high = mid - 1;
          }
        }
        best = middle(low);
        visibleLength = low;
      } else {
        // Tail: the longest prefix that fits together with the token. The
        // prefix never goes beyond the end of the last allowed line.
        final ui.LineMetrics last = lines[lineLimit - 1];
        final TextPosition position = painter
            .getPositionForOffset(Offset(0, last.baseline - last.ascent / 2));
        final int lineEnd = painter.getLineBoundary(position).end;
        int high = full.displayCaret(lineEnd);
        int low = 0;
        int cut = 0;
        while (low <= high) {
          final int mid = (low + high) >> 1;
          final int c = _trimmedCut(content, mid);
          if (fits(<_Slice>[
            _Slice(content.substring(0, c), 0),
            _Slice(token, 0, isToken: true)
          ])) {
            cut = c;
            low = mid + 1;
          } else {
            high = mid - 1;
          }
        }
        best = <_Slice>[
          _Slice(content.substring(0, cut), 0),
          _Slice(token, 0, isToken: true)
        ];
        visibleLength = cut;
      }
      paragraph = _buildParagraph(best, contentWidgets);
      painter.dispose();
      painter = _painter(paragraph, childDims, scaler,
          minWidth: minWidth, maxWidth: maxWidth);
    }

    final Size textSize = painter.size;
    final Size size = constraints.constrain(
        Size(textSize.width + pad.horizontal, textSize.height + pad.vertical));
    final double free = size.height - pad.vertical - textSize.height;
    final double dy = switch (_verticalAlignment) {
      ZLVerticalAlignment.top => 0,
      ZLVerticalAlignment.center => math.max(0, free / 2),
      ZLVerticalAlignment.bottom => math.max(0, free),
    };
    return _Layout(
      paragraph: paragraph,
      painter: painter,
      dims: childDims,
      size: size,
      textOffset: Offset(pad.left, pad.top + dy),
      truncated: truncated,
      fontScale: scale,
      lineCount: lineCount,
      visibleContentLength: visibleLength,
    );
  }

  /// Moves an offset out of a widget run (and out of a surrogate pair).
  static int _snap(ZLAttributedText text, int offset, {bool forward = false}) {
    for (final (int start, ZLTextRun run) in text.runsWithOffsets) {
      final int end = start + run.length;
      if (offset > start && offset < end) {
        if (run.isWidget) return forward ? end : start;
        final int unit = run.text.codeUnitAt(offset - start - 1);
        if (unit >= 0xD800 && unit <= 0xDBFF) {
          return forward ? offset + 1 : offset - 1;
        }
        return offset;
      }
    }
    return offset;
  }

  /// A tail cut without trailing white space.
  static int _trimmedCut(ZLAttributedText text, int offset) {
    int cut = _snap(text, offset);
    final String string = text.string;
    while (cut > 0) {
      final int unit = string.codeUnitAt(cut - 1);
      if (unit == 0x20 || unit == 0x0A || unit == 0x09 || unit == 0x3000) {
        cut--;
      } else {
        break;
      }
    }
    return cut;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    return _dryLayout(constraints).size;
  }

  _Layout _dryLayout(BoxConstraints constraints) {
    final _Layout? current = _layout;
    if (current != null && _layoutValid && this.constraints == constraints) {
      statistics?.layoutCacheHits += 1;
      return current;
    }
    final _Layout? cached = _dryLayouts[constraints];
    if (cached != null) {
      statistics?.layoutCacheHits += 1;
      return cached;
    }
    final _Layout layout = _computeLayout(constraints, dry: true);
    if (_dryLayouts.length > 8) _clearDryLayouts();
    _dryLayouts[constraints] = layout;
    return layout;
  }

  @override
  double? computeDryBaseline(
      covariant BoxConstraints constraints, TextBaseline baseline) {
    final _Layout layout = _dryLayout(constraints);
    return layout.textOffset.dy +
        layout.painter.computeDistanceToActualBaseline(baseline);
  }

  @override
  void performLayout() {
    final _Layout layout = _computeLayout(constraints, dry: false);
    _layout?.dispose();
    _layout = layout;
    _layoutValid = true;
    size = layout.size;

    // Position the visible children.
    final List<TextBox> boxes =
        layout.painter.inlinePlaceholderBoxes ?? const <TextBox>[];
    final List<RenderBox> children = getChildrenAsList();
    for (final RenderBox child in children) {
      (child.parentData! as ZLTextParentData).visible = false;
    }
    for (int i = 0;
        i < layout.paragraph.placeholders.length && i < boxes.length;
        i++) {
      final _Placeholder placeholder = layout.paragraph.placeholders[i];
      if (placeholder.isSpacer || placeholder.childIndex >= children.length) {
        continue;
      }
      final ZLTextParentData data =
          children[placeholder.childIndex].parentData! as ZLTextParentData;
      data
        ..visible = true
        ..offset = Offset(boxes[i].left, boxes[i].top) + layout.textOffset;
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return _intrinsicPainterWidth(min: true) + _padding.horizontal;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _intrinsicPainterWidth(min: false) + _padding.horizontal;
  }

  double _intrinsicPainterWidth({required bool min}) {
    final List<ZLTextRun> runs = _widgetRuns;
    final List<PlaceholderDimensions> dims = <PlaceholderDimensions>[];
    int i = 0;
    for (RenderBox? child = firstChild;
        child != null;
        child = childAfter(child), i++) {
      final ZLRichWidget? widget = i < runs.length ? runs[i].widget : null;
      final Size size = widget?.size ??
          Size(child.getMaxIntrinsicWidth(double.infinity),
              child.getMinIntrinsicHeight(double.infinity));
      dims.add(PlaceholderDimensions(
        size: size,
        alignment: widget?.alignment ?? PlaceholderAlignment.middle,
        baseline: TextBaseline.alphabetic,
        baselineOffset: size.height,
      ));
    }
    final _Paragraph paragraph =
        _buildParagraph(<_Slice>[_Slice(_content, 0)], _contentWidgetCount);
    final TextPainter painter =
        _painter(paragraph, dims, _textScaler, maxWidth: double.infinity);
    final double width =
        min ? painter.minIntrinsicWidth : painter.maxIntrinsicWidth;
    painter.dispose();
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) => getDryLayout(
          BoxConstraints(maxWidth: width.isFinite ? width : double.infinity))
      .height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final _Layout? layout = _layout;
    if (layout == null) return null;
    return layout.textOffset.dy +
        layout.painter.computeDistanceToActualBaseline(baseline);
  }

  // MARK: Queries (local coordinates)

  /// Whether the text is truncated in the last layout.
  bool get isTruncated => _layout?.truncated ?? false;

  /// Font scale used by [adjustsFontSizeToFit], 1 when not scaled.
  double get fontScale => _layout?.fontScale ?? 1;

  /// Number of lines of the full (not truncated) text.
  int get lineCount => _layout?.lineCount ?? 0;

  /// Visible part of the content (the content length when not truncated).
  int get visibleContentLength =>
      _layout?.visibleContentLength ?? _content.length;

  /// The character (or token) under [point]; `null` when the point is not on
  /// the text. Spacers of capsules count as the capsule.
  ZLTextHit? hitTestText(Offset point) {
    final _Layout? layout = _layout;
    if (layout == null) return null;
    final Offset local = point - layout.textOffset;
    if (local.dy < -0.5 || local.dy > layout.painter.height + 0.5) return null;
    final ui.GlyphInfo? glyph = layout.painter.getClosestGlyphForOffset(local);
    if (glyph == null) return null;
    final Rect bounds = glyph.graphemeClusterLayoutBounds;
    if (!bounds.inflate(0.5).contains(local)) return null;
    final ZLTextHit? hit =
        layout.paragraph.hitAt(glyph.graphemeClusterCodeUnitRange.start);
    if (hit == null) return null;
    // A newline is not "on the text".
    if (hit.index != null) {
      final String string = _content.string;
      if (hit.index! < string.length && string.codeUnitAt(hit.index!) == 0x0A) {
        return null;
      }
    }
    return hit;
  }

  /// The closest caret position (display offset) to [point].
  int caretAt(Offset point) {
    final _Layout? layout = _layout;
    if (layout == null) return 0;
    final Offset local = point - layout.textOffset;
    final double y =
        local.dy.clamp(0.0, math.max(0.0, layout.painter.height - 0.01));
    final TextPosition position =
        layout.painter.getPositionForOffset(Offset(local.dx, y));
    return layout.paragraph.displayCaret(
        math.min(position.offset, layout.paragraph.contentParagraphEnd));
  }

  /// Word (or atomic run) around [displayIndex], in display offsets.
  TextRange wordAt(int displayIndex) {
    final _Layout? layout = _layout;
    if (layout == null) {
      return TextRange(start: displayIndex, end: displayIndex + 1);
    }
    final List<TextRange> ranges = layout.paragraph
        .paragraphRanges(TextRange(start: displayIndex, end: displayIndex + 1));
    if (ranges.isEmpty) {
      return TextRange(start: displayIndex, end: displayIndex + 1);
    }
    final _Piece? piece = layout.paragraph.pieceAt(ranges.first.start);
    if (piece == null || piece.kind != _PieceKind.text) {
      return TextRange(
          start: piece?.displayStart ?? displayIndex,
          end: piece?.displayEnd ?? displayIndex + 1);
    }
    final TextRange word = layout.painter
        .getWordBoundary(TextPosition(offset: ranges.first.start));
    final int start =
        layout.paragraph.displayCaret(math.max(word.start, piece.paraStart));
    final int end =
        layout.paragraph.displayCaret(math.min(word.end, piece.paraEnd));
    if (end <= start || _content.string.substring(start, end).trim().isEmpty) {
      return TextRange(start: displayIndex, end: displayIndex + 1);
    }
    return TextRange(start: start, end: end);
  }

  /// Boxes (one or more per line) of a display range, in local coordinates.
  List<Rect> rectsForRange(TextRange range, {bool fullLineHeight = false}) {
    final _Layout? layout = _layout;
    if (layout == null || !range.isValid || range.isCollapsed) {
      return const <Rect>[];
    }
    final List<Rect> result = <Rect>[];
    for (final TextRange para in layout.paragraph.paragraphRanges(range)) {
      for (final TextBox box in layout.painter.getBoxesForSelection(
        TextSelection(baseOffset: para.start, extentOffset: para.end),
        boxHeightStyle:
            fullLineHeight ? ui.BoxHeightStyle.max : ui.BoxHeightStyle.tight,
      )) {
        result.add(box.toRect().shift(layout.textOffset));
      }
    }
    return result;
  }

  /// Union of [rectsForRange].
  Rect? boundingRectForRange(TextRange range) {
    Rect? result;
    for (final Rect rect in rectsForRange(range)) {
      result = result == null ? rect : result.expandToInclude(rect);
    }
    return result;
  }

  /// Rect of the truncation token, `null` when the text is not truncated.
  Rect? get tokenRect {
    final _Layout? layout = _layout;
    final TextRange? range = layout?.paragraph.tokenRange;
    if (layout == null || range == null || !layout.truncated) return null;
    Rect? result;
    for (final TextBox box in layout.painter.getBoxesForSelection(
        TextSelection(baseOffset: range.start, extentOffset: range.end))) {
      final Rect rect = box.toRect().shift(layout.textOffset);
      result = result == null ? rect : result.expandToInclude(rect);
    }
    return result;
  }

  /// Caret rect at a display offset (`preferPreviousLine`: a caret at the
  /// start of a line belongs to the end of the previous line).
  Rect? caretRect(int displayOffset, {bool preferPreviousLine = false}) {
    final _Layout? layout = _layout;
    if (layout == null) return null;
    final int clamped = displayOffset.clamp(0, _content.length);
    final List<Rect> rects = preferPreviousLine && clamped > 0
        ? rectsForRange(TextRange(start: clamped - 1, end: clamped),
            fullLineHeight: true)
        : rectsForRange(
            TextRange(
                start: clamped, end: math.min(clamped + 1, _content.length)),
            fullLineHeight: true);
    if (rects.isEmpty) return null;
    final Rect rect =
        preferPreviousLine && clamped > 0 ? rects.last : rects.first;
    final bool rtl = _textDirection == TextDirection.rtl;
    final double x = preferPreviousLine && clamped > 0
        ? (rtl ? rect.left : rect.right)
        : (rtl ? rect.right : rect.left);
    return Rect.fromLTWH(x - 1, rect.top, 2, rect.height);
  }

  // MARK: Hit testing

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    RenderBox? child = lastChild;
    while (child != null) {
      final ZLTextParentData data = child.parentData! as ZLTextParentData;
      if (data.visible) {
        final RenderBox current = child;
        final bool hit = result.addWithPaintOffset(
          offset: data.offset,
          position: position,
          hitTest: (BoxHitTestResult result, Offset transformed) =>
              current.hitTest(result, position: transformed),
        );
        if (hit) return true;
      }
      child = data.previousSibling;
    }
    return false;
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final ZLTextParentData data = child.parentData! as ZLTextParentData;
    if (!data.visible) {
      transform.setZero();
    } else {
      transform.multiply(
          Matrix4.translationValues(data.offset.dx, data.offset.dy, 0));
    }
  }

  // MARK: Paint

  @override
  void paint(PaintingContext context, Offset offset) {
    final _Layout? layout = _layout;
    if (layout == null) return;
    final bool overflows =
        layout.painter.height + layout.textOffset.dy > size.height + 0.5 ||
            layout.painter.width + layout.textOffset.dx > size.width + 0.5;
    if (overflows) {
      context.pushClipRect(needsCompositing, offset, Offset.zero & size,
          (PaintingContext context, Offset offset) {
        _paintContents(context, offset, layout);
      });
    } else {
      _paintContents(context, offset, layout);
    }
  }

  void _paintContents(PaintingContext context, Offset offset, _Layout layout) {
    final Canvas canvas = context.canvas;
    final Offset origin = offset + layout.textOffset;

    final TextRange? selection = _selection;
    if (selection != null && !selection.isCollapsed) {
      final Paint paint = Paint()..color = _selectionColor;
      for (final Rect rect in rectsForRange(selection, fullLineHeight: true)) {
        canvas.drawRect(rect.shift(offset), paint);
      }
    }

    if (layout.paragraph.backgrounds.isNotEmpty) {
      _paintBackgrounds(canvas, origin, offset, layout);
    }
    layout.painter.paint(canvas, origin);
    if (layout.paragraph.gradients.isNotEmpty) {
      _paintGradients(canvas, origin, layout);
    }

    RenderBox? child = firstChild;
    while (child != null) {
      final ZLTextParentData data = child.parentData! as ZLTextParentData;
      if (data.visible) context.paintChild(child, data.offset + offset);
      child = data.nextSibling;
    }
  }

  /// Rects of a paragraph range grouped by line (one rect per line).
  List<Rect> _lineRects(_Layout layout, int start, int end) {
    if (end <= start) return const <Rect>[];
    final List<TextBox> boxes = layout.painter.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end));
    final List<ui.LineMetrics> lines = layout.painter.computeLineMetrics();
    final Map<int, Rect> byLine = <int, Rect>{};
    for (final TextBox box in boxes) {
      if (box.right - box.left <= 0) continue;
      final double centerY = (box.top + box.bottom) / 2;
      int line = 0;
      for (int i = 0; i < lines.length; i++) {
        final ui.LineMetrics m = lines[i];
        if (centerY <= m.baseline + m.descent) {
          line = i;
          break;
        }
        line = i;
      }
      final Rect rect = box.toRect();
      byLine[line] = byLine[line]?.expandToInclude(rect) ?? rect;
    }
    final List<int> keys = byLine.keys.toList()..sort();
    return <Rect>[for (final int key in keys) byLine[key]!];
  }

  void _paintBackgrounds(
      Canvas canvas, Offset origin, Offset offset, _Layout layout) {
    final Rect bounds = offset & size;
    for (final _Decoration decoration in layout.paragraph.backgrounds) {
      final ZLTextBackground background = decoration.background!;
      final EdgeInsets padding = background.padding;
      for (final Rect line
          in _lineRects(layout, decoration.paraStart, decoration.paraEnd)) {
        Rect rect = Rect.fromLTRB(
          line.left - padding.left,
          line.top - padding.top - decoration.shift,
          line.right + padding.right,
          line.bottom + padding.bottom - decoration.shift,
        ).shift(origin);
        rect = rect.intersect(bounds);
        if (rect.width <= 0 || rect.height <= 0) continue;
        final double inset =
            background.strokeColor == null ? 0 : background.strokeWidth / 2;
        final Rect pathRect = rect.deflate(inset);
        final double radius = background.cornerRadius < 0
            ? pathRect.height / 2
            : math.min(background.cornerRadius, pathRect.height / 2);
        final RRect rrect =
            RRect.fromRectAndRadius(pathRect, Radius.circular(radius));
        if (background.fillColor != null) {
          canvas.drawRRect(rrect, Paint()..color = background.fillColor!);
        }
        if (background.strokeColor != null && background.strokeWidth > 0) {
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = background.strokeColor!
              ..style = PaintingStyle.stroke
              ..strokeWidth = background.strokeWidth,
          );
        }
      }
    }
  }

  void _paintGradients(Canvas canvas, Offset origin, _Layout layout) {
    final TextPainter mask = layout.maskPainter ??= _painter(
      layout.paragraph,
      layout.dims,
      _scaled(layout.fontScale),
      minWidth: math.max(0, constraints.minWidth - _padding.horizontal),
      maxWidth: math.max(0, constraints.maxWidth - _padding.horizontal),
      mask: true,
    );
    final Rect layer = (origin & mask.size).inflate(4);
    canvas.saveLayer(layer, Paint());
    mask.paint(canvas, origin);
    for (final _Decoration decoration in layout.paragraph.gradients) {
      for (final Rect line
          in _lineRects(layout, decoration.paraStart, decoration.paraEnd)) {
        final Rect rect = line.shift(origin).translate(0, -decoration.shift);
        canvas.drawRect(
          rect.inflate(1),
          Paint()
            ..shader = decoration.gradient!
                .createShader(rect, textDirection: _textDirection)
            ..blendMode = BlendMode.srcIn,
        );
      }
    }
    canvas.restore();
  }

  // MARK: Semantics

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    RenderBox? child = firstChild;
    while (child != null) {
      final ZLTextParentData data = child.parentData! as ZLTextParentData;
      if (data.visible) visitor(child);
      child = data.nextSibling;
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    config.textDirection = _textDirection;
    if (_semanticsLinks.isEmpty) {
      config.label = _semanticsLabel ??
          _content.string.replaceAll(kZLObjectReplacementCharacter, '');
    } else {
      config.explicitChildNodes = true;
    }
  }

  List<SemanticsNode> _semanticsNodes = <SemanticsNode>[];

  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config,
      Iterable<SemanticsNode> children) {
    if (_semanticsLinks.isEmpty) {
      super.assembleSemanticsNode(node, config, children);
      return;
    }
    final List<SemanticsNode> reuse = _semanticsNodes;
    final List<SemanticsNode> nodes = <SemanticsNode>[];
    int next = 0;
    SemanticsNode take() =>
        next < reuse.length ? reuse[next++] : SemanticsNode();

    double ordinal = 0;
    final SemanticsNode textNode = take()
      ..updateWith(
        config: SemanticsConfiguration()
          ..sortKey = OrdinalSortKey(ordinal++)
          ..label = _semanticsLabel ??
              _content.string.replaceAll(kZLObjectReplacementCharacter, '')
          ..textDirection = _textDirection,
      )
      ..rect = Offset.zero & size;
    nodes.add(textNode);
    for (final ZLSemanticsLink link in _semanticsLinks) {
      final Rect? rect = link.range.end <= _content.length
          ? boundingRectForRange(link.range)
          : tokenRect;
      if (rect == null) continue;
      final SemanticsConfiguration linkConfig = SemanticsConfiguration()
        ..sortKey = OrdinalSortKey(ordinal++)
        ..label = link.label
        ..textDirection = _textDirection;
      if (link.isButton) {
        linkConfig.isButton = true;
      } else {
        linkConfig.isLink = true;
      }
      if (link.hint != null) linkConfig.hint = link.hint!;
      if (link.onTap != null) linkConfig.onTap = link.onTap;
      if (link.onLongPress != null) linkConfig.onLongPress = link.onLongPress;
      final SemanticsNode linkNode = take()
        ..updateWith(config: linkConfig)
        ..rect = rect.inflate(2).intersect(Offset.zero & size);
      nodes.add(linkNode);
    }
    _semanticsNodes = nodes;
    node.updateWith(
        config: config,
        childrenInInversePaintOrder: <SemanticsNode>[...nodes, ...children]);
  }

  @override
  void clearSemantics() {
    super.clearSemantics();
    _semanticsNodes = <SemanticsNode>[];
  }
}
