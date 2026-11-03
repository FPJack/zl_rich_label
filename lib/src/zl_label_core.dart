import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'zl_attributed_text.dart';
import 'zl_data_detector.dart';
import 'zl_statistics.dart';
import 'zl_text_layout.dart';
import 'zl_text_style.dart';

/// A tappable range of a label.
///
/// ```dart
/// ZLLabelLink(
///   range: const TextRange(start: 5, end: 9),
///   style: ZLTextStyle().color(Colors.white).backgroundColor(Colors.orange),
///   activeStyle: ZLTextStyle().backgroundColor(Colors.brown),
///   onTap: (link) => print(link.range),
/// )
/// ```
class ZLLabelLink {
  ZLLabelLink({
    required this.range,
    this.url,
    this.result,
    this.style,
    this.activeStyle,
    this.inactiveStyle,
    this.onTap,
    this.onLongPress,
    this.semanticsHint,
  });

  /// Range in the display text.
  final TextRange range;

  /// Link target (`ZLTextStyle.link`, detected URLs …).
  final Uri? url;

  /// Detection result of links found by data detectors.
  final ZLDataDetectorResult? result;

  /// Style applied to the range. `null` uses the label's `linkStyle`,
  /// [ZLTextStyle.none] keeps the text as is.
  final ZLTextStyle? style;

  /// Style while pressed. `null` uses the label's `activeLinkStyle`.
  final ZLTextStyle? activeStyle;

  /// Style while the label is inactive (a dialog / sheet covers its route).
  /// `null` uses the label's `inactiveLinkStyle`.
  final ZLTextStyle? inactiveStyle;

  /// Tap callback. When `null` the label's `onLinkTap` is called.
  final void Function(ZLLabelLink link)? onTap;

  /// Long press callback. When `null` the label's `onLinkLongPress` is called.
  final void Function(ZLLabelLink link)? onLongPress;

  /// Extra text read by screen readers.
  final String? semanticsHint;

  @override
  String toString() =>
      'ZLLabelLink(${range.start}-${range.end}${url == null ? '' : ', $url'})';
}

/// Position information of a gesture on a label.
@immutable
class ZLLabelGestureDetails {
  const ZLLabelGestureDetails(
      {required this.location,
      required this.characterIndex,
      required this.globalLocation});

  /// Position in the label's coordinate system.
  final Offset location;

  final Offset globalLocation;

  /// Character of the display text under the gesture, `null` when the
  /// gesture is not on the text.
  final int? characterIndex;
}

/// Controls a label: expand state, selection, geometry queries.
///
/// Attach it to one label at a time.
class ZLLabelController extends ChangeNotifier {
  ZLLabelController({bool initiallyExpanded = false})
      : _initiallyExpanded = initiallyExpanded;

  final bool _initiallyExpanded;
  ZLLabelCoreState? _core;

  bool get isAttached => _core != null;

  void _attach(ZLLabelCoreState core) => _core = core;

  void _detach(ZLLabelCoreState core) {
    if (identical(_core, core)) _core = null;
  }

  // MARK: Expand / collapse

  /// Whether the label is expanded. Setting it does not call
  /// `onExpandChanged` (use it to restore the state of recycled list items).
  bool get isExpanded => _core?._expanded ?? _initiallyExpanded;

  set isExpanded(bool value) => _core?._setExpanded(value, notify: false);

  /// Toggles the expand state and calls `onExpandChanged`, like tapping the
  /// expand / collapse token.
  void toggleExpanded() => _core?._setExpanded(!isExpanded, notify: true);

  /// Whether the text is truncated in the last layout.
  bool get isTruncated => _core?._render?.isTruncated ?? false;

  /// Tappable area of the expand token (local coordinates), `null` when not
  /// shown.
  Rect? get expandTokenRect => _core?._expandTokenRect;

  /// Font scale chosen by `adjustsFontSizeToFit` (1 when not scaled).
  double get currentFontScale => _core?._render?.fontScale ?? 1;

  /// The render object of the label (after the first layout), e.g. to
  /// measure it with `getDryLayout`.
  RenderZLText? get renderObject => _core?._render;

  /// Number of lines of the full text at the current width.
  int get lineCount => _core?._render?.lineCount ?? 0;

  // MARK: Geometry

  /// Display text (inline widgets are U+FFFC).
  String get displayText => _core?._contentText ?? '';

  /// Character of the display text at [location] (local coordinates),
  /// `null` when the point is not on the text.
  int? characterIndexAt(Offset location) => _core?._characterIndexAt(location);

  /// Boxes of a display range in local coordinates (one or more per line).
  List<Rect> rectsForRange(TextRange range) =>
      _core?._render?.rectsForRange(range) ?? const <Rect>[];

  /// Bounding box of a display range in local coordinates.
  Rect? boundingRectForRange(TextRange range) =>
      _core?._render?.boundingRectForRange(range);

  /// The link at [location] (honours `extendsLinkTouchArea`).
  ZLLabelLink? linkAt(Offset location) => _core?._linkAt(location);

  /// Triggers the tap of [link] like a user tap.
  void performTap(ZLLabelLink link) => _core?._performTap(link);

  // MARK: Selection

  /// Selected display range, `null` without selection.
  TextRange? get selectedRange => _core?._selection;

  bool get hasSelection => selectedRange != null;

  /// Selected display text (inline widgets removed).
  String? get selectedText => _core?._selectedText;

  /// Raw text of the selection (whole rule matches when partially selected).
  String? get selectedRawText => _core?._selectedRawText;

  /// Selects a display range (clamped to the content).
  void select(TextRange range) => _core?._setSelection(range, showMenu: true);

  /// Selects the whole content (without the collapse token).
  void selectAll() => _core?._selectAll();

  /// Clears the selection and hides the menu.
  void clearSelection() => _core?._clearSelection();

  /// Copies the selection; [raw] copies the raw text.
  Future<void> copySelection({bool raw = false}) =>
      _core?._copySelection(raw: raw) ?? Future<void>.value();

  void _notify() => notifyListeners();
}

/// Internal: the label widget shared by `ZLAttributedLabel` and
/// `ZLRichLabel`. Handles links, press highlight, truncation tokens,
/// expand / collapse, long press, double tap and selection.
class ZLLabelCore extends StatefulWidget {
  const ZLLabelCore({
    super.key,
    required this.content,
    this.style = ZLTextStyle.none,
    this.links = const <ZLLabelLink>[],
    this.linkStyle = ZLTextStyle.none,
    this.activeLinkStyle = ZLTextStyle.none,
    this.inactiveLinkStyle,
    this.onLinkTap,
    this.onLinkLongPress,
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
    this.rawTextForRange,
    this.atomicRanges = const <TextRange>[],
    this.copyLabel = '复制',
    this.copyRawLabel = '复制原文',
    this.selectAllLabel = '全选',
    this.highlighted = false,
    this.highlightedTextColor,
    this.semanticsLabel,
    this.statistics,
    this.controller,
  });

  final ZLAttributedText content;
  final ZLTextStyle style;
  final List<ZLLabelLink> links;
  final ZLTextStyle linkStyle;
  final ZLTextStyle activeLinkStyle;
  final ZLTextStyle? inactiveLinkStyle;
  final void Function(ZLLabelLink link)? onLinkTap;
  final void Function(ZLLabelLink link, Offset location)? onLinkLongPress;
  final ZLAttributedText? truncationToken;
  final ZLAttributedText? expandToken;
  final ZLAttributedText? collapseToken;
  final bool? expanded;
  final ValueChanged<bool>? onExpandChanged;
  final ValueChanged<bool>? onExpandTokenTap;
  final int collapseThreshold;
  final int? maxLines;
  final ZLTruncationMode truncationMode;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final TextScaler? textScaler;
  final EdgeInsetsGeometry padding;
  final ZLVerticalAlignment verticalAlignment;
  final bool adjustsFontSizeToFit;
  final double minimumScaleFactor;
  final bool extendsLinkTouchArea;
  final ValueChanged<ZLLabelGestureDetails>? onLongPress;
  final ValueChanged<ZLLabelGestureDetails>? onDoubleTap;
  final bool selectable;
  final Color? selectionColor;
  final ValueChanged<TextRange?>? onSelectionChanged;
  final void Function(String text, bool isRawText)? onCopy;
  final String Function(TextRange displayRange)? rawTextForRange;
  final List<TextRange> atomicRanges;
  final String copyLabel;
  final String copyRawLabel;
  final String selectAllLabel;
  final bool highlighted;
  final Color? highlightedTextColor;
  final String? semanticsLabel;
  final ZLLabelStatistics? statistics;
  final ZLLabelController? controller;

  @override
  State<ZLLabelCore> createState() => ZLLabelCoreState();

  /// Text direction of a string: the first strong character (Hebrew, Arabic …
  /// are right-to-left), `null` without strong characters.
  static TextDirection? detectTextDirection(String string) {
    for (final int rune in string.runes) {
      if ((rune >= 0x0590 && rune <= 0x08FF) ||
          (rune >= 0xFB1D && rune <= 0xFDFF) ||
          (rune >= 0xFE70 && rune <= 0xFEFF) ||
          (rune >= 0x10800 && rune <= 0x10FFF) ||
          (rune >= 0x1E800 && rune <= 0x1EFFF)) {
        // Arabic-Indic digits are weak.
        if ((rune >= 0x0660 && rune <= 0x0669) ||
            (rune >= 0x06F0 && rune <= 0x06F9)) {
          continue;
        }
        return TextDirection.rtl;
      }
      if (_isLetter(rune)) return TextDirection.ltr;
    }
    return null;
  }

  static bool _isLetter(int rune) {
    if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A)) {
      return true;
    }
    if (rune < 0xC0) return false;
    // Letters of other scripts (Latin-1 supplement and above, excluding
    // punctuation / symbols blocks and the object replacement character).
    if (rune >= 0x2000 && rune <= 0x2BFF) return false;
    if (rune >= 0x3000 && rune <= 0x303F) return false;
    if (rune >= 0xFE00 && rune <= 0xFE6F) return false;
    if (rune >= 0xFF00 && rune <= 0xFF20) return false;
    if (rune == 0xFFFC || rune == 0xD7 || rune == 0xF7) return false;
    if (rune >= 0x1F000) return false; // emoji
    return true;
  }
}

class _ZLTapRecognizer extends TapGestureRecognizer {
  _ZLTapRecognizer({super.debugOwner, required this.accepts});

  bool Function(Offset globalPosition) accepts;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      super.isPointerAllowed(event) && accepts(event.position);
}

class _ZLLongPressRecognizer extends LongPressGestureRecognizer {
  _ZLLongPressRecognizer({super.debugOwner, required this.accepts});

  bool Function(Offset globalPosition) accepts;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      super.isPointerAllowed(event) && accepts(event.position);
}

class _ZLDoubleTapRecognizer extends DoubleTapGestureRecognizer {
  _ZLDoubleTapRecognizer({super.debugOwner, required this.accepts});

  bool Function(Offset globalPosition) accepts;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      super.isPointerAllowed(event) && accepts(event.position);
}

class ZLLabelCoreState extends State<ZLLabelCore> {
  final GlobalKey _layoutKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlay = OverlayPortalController();

  ZLLabelLink? _pressed;
  late bool _expanded;
  TextRange? _selection;
  TextRange? _selectionAnchor;
  bool _adjustingSelection = false;
  bool _showsMenu = false;
  Offset? _doubleTapPosition;

  /// Content shown on screen (styles applied, collapse token appended).
  ZLAttributedText _shown = ZLAttributedText.empty;

  /// Links of [_shown] (including the collapse token link).
  List<ZLLabelLink> _shownLinks = const <ZLLabelLink>[];

  RenderZLText? get _render {
    final RenderObject? object = _layoutKey.currentContext?.findRenderObject();
    return object is RenderZLText && object.hasSize ? object : null;
  }

  String get _contentText => widget.content.string;

  int get _contentLength => widget.content.length;

  @override
  void initState() {
    super.initState();
    _expanded =
        widget.expanded ?? widget.controller?._initiallyExpanded ?? false;
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(ZLLabelCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (widget.expanded != null && widget.expanded != oldWidget.expanded) {
      _expanded = widget.expanded!;
    }
    // Only a different display text invalidates the press state and the
    // selection (new styles or inline widget objects keep them).
    if (oldWidget.content.string != widget.content.string) {
      _pressed = null;
      if (_selection != null) {
        _selection = null;
        _selectionAnchor = null;
        _hideOverlay();
        WidgetsBinding.instance
            .addPostFrameCallback((_) => widget.onSelectionChanged?.call(null));
      }
    }
    if (!widget.selectable && _selection != null) _clearSelection();
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  // MARK: Expand

  void _setExpanded(bool value, {required bool notify}) {
    if (_expanded == value) return;
    setState(() => _expanded = value);
    widget.controller?._notify();
    if (notify) widget.onExpandChanged?.call(value);
  }

  void _expandTokenTapped(bool wantsExpand) {
    final ValueChanged<bool>? handler = widget.onExpandTokenTap;
    if (handler != null) {
      handler(wantsExpand);
    } else {
      _setExpanded(wantsExpand, notify: true);
    }
  }

  bool get _showsExpandToken => !_expanded && widget.expandToken != null;

  Rect? get _expandTokenRect {
    if (!_showsExpandToken) return null;
    final Rect? rect = _render?.tokenRect;
    return rect == null
        ? null
        : Rect.fromLTRB(
            rect.left - 8, rect.top - 6, rect.right + 8, rect.bottom + 6);
  }

  // MARK: Hit testing

  Offset? _toLocal(Offset global) {
    final RenderZLText? render = _render;
    return render?.globalToLocal(global);
  }

  int? _characterIndexAt(Offset local) {
    final ZLTextHit? hit = _render?.hitTestText(local);
    if (hit == null || hit.isToken) return null;
    return hit.index! < _contentLength ? hit.index : null;
  }

  ZLLabelLink? _linkAtIndex(int index) {
    for (int i = _shownLinks.length - 1; i >= 0; i--) {
      final ZLLabelLink link = _shownLinks[i];
      if (index >= link.range.start && index < link.range.end) return link;
    }
    return null;
  }

  /// Display index under [local] that is covered by a link (searching up to
  /// 15pt around when `extendsLinkTouchArea` is on and the point is not on
  /// the text).
  int? _linkIndexAt(Offset local) {
    final RenderZLText? render = _render;
    if (render == null || _shownLinks.isEmpty) return null;
    final ZLTextHit? hit = render.hitTestText(local);
    if (hit != null) {
      if (hit.isToken) return null;
      return _linkAtIndex(hit.index!) == null ? null : hit.index;
    }
    if (!widget.extendsLinkTouchArea) return null;
    for (final double radius in const <double>[2.5, 5, 7.5, 12.5, 15]) {
      final double d = math.sqrt(2 * radius * radius) / 2;
      for (final Offset delta in <Offset>[
        Offset(0, -radius),
        Offset(0, radius),
        Offset(-radius, 0),
        Offset(radius, 0),
        Offset(-d, -d),
        Offset(-d, d),
        Offset(d, d),
        Offset(d, -d),
      ]) {
        final ZLTextHit? near = render.hitTestText(local + delta);
        if (near == null || near.isToken) continue;
        if (_linkAtIndex(near.index!) != null) return near.index;
      }
    }
    return null;
  }

  /// The link at [local]: the link added last wins where links overlap.
  ZLLabelLink? _linkAt(Offset local) {
    final int? index = _linkIndexAt(local);
    return index == null ? null : _linkAtIndex(index);
  }

  bool _isTappable(ZLLabelLink link) =>
      link.onTap != null || widget.onLinkTap != null;

  /// The tappable link at [local] (the last added wins where links overlap).
  ZLLabelLink? _tapLinkAt(Offset local) {
    final int? index = _linkIndexAt(local);
    return index == null ? null : _tapLinkAtIndex(index);
  }

  ZLLabelLink? _tapLinkAtIndex(int index) {
    for (int i = _shownLinks.length - 1; i >= 0; i--) {
      final ZLLabelLink link = _shownLinks[i];
      if (index >= link.range.start &&
          index < link.range.end &&
          _isTappable(link)) {
        return link;
      }
    }
    return null;
  }

  /// Long press target at [local]: the last link at that position with its
  /// own long press, otherwise the topmost link with the label's
  /// `onLinkLongPress`.
  (ZLLabelLink, void Function(ZLLabelLink))? _longPressTarget(Offset local) {
    final int? index = _linkIndexAt(local);
    if (index == null) return null;
    for (int i = _shownLinks.length - 1; i >= 0; i--) {
      final ZLLabelLink link = _shownLinks[i];
      if (index >= link.range.start &&
          index < link.range.end &&
          link.onLongPress != null) {
        return (link, link.onLongPress!);
      }
    }
    final ZLLabelLink? top = _linkAtIndex(index);
    final void Function(ZLLabelLink, Offset)? fallback = widget.onLinkLongPress;
    if (top == null || fallback == null) return null;
    return (top, (ZLLabelLink l) => fallback(l, local));
  }

  bool _isOnExpandToken(Offset local) =>
      _expandTokenRect?.contains(local) ?? false;

  bool _acceptsTap(Offset global) {
    final Offset? local = _toLocal(global);
    if (local == null) return false;
    if (_selection != null) return true;
    return _isOnExpandToken(local) || _tapLinkAt(local) != null;
  }

  bool _acceptsLongPress(Offset global) {
    if (widget.onLongPress != null || widget.selectable) return true;
    final Offset? local = _toLocal(global);
    return local != null && _longPressTarget(local) != null;
  }

  bool _acceptsDoubleTap(Offset global) =>
      widget.onDoubleTap != null && _selection == null;

  ZLLabelGestureDetails _details(Offset local, Offset global) =>
      ZLLabelGestureDetails(
          location: local,
          globalLocation: global,
          characterIndex: _characterIndexAt(local));

  // MARK: Gestures

  void _onTapDown(TapDownDetails details) {
    if (_selection != null) return;
    final ZLLabelLink? link = _tapLinkAt(details.localPosition);
    if (link != null && !identical(link, _pressed)) {
      setState(() => _pressed = link);
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_selection != null) {
      _clearSelection();
      return;
    }
    final Offset local = details.localPosition;
    if (_isOnExpandToken(local)) {
      if (_pressed != null) setState(() => _pressed = null);
      _expandTokenTapped(true);
      return;
    }
    final ZLLabelLink? link = _tapLinkAt(local) ?? _pressed;
    if (_pressed != null) setState(() => _pressed = null);
    if (link != null) _performTap(link);
  }

  void _onTapCancel() {
    if (_pressed != null) setState(() => _pressed = null);
  }

  void _performTap(ZLLabelLink link) {
    if (link.onTap != null) {
      link.onTap!(link);
    } else {
      widget.onLinkTap?.call(link);
    }
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final Offset local = details.localPosition;
    if (_pressed != null) setState(() => _pressed = null);
    final (ZLLabelLink, void Function(ZLLabelLink))? target =
        _longPressTarget(local);
    if (target != null) {
      HapticFeedback.mediumImpact();
      target.$2(target.$1);
      return;
    }
    if (widget.selectable) {
      _beginSelection(local);
      return;
    }
    if (widget.onLongPress != null) {
      HapticFeedback.mediumImpact();
      widget.onLongPress!(_details(local, details.globalPosition));
    }
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_selectionAnchor != null) _extendSelection(details.localPosition);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_selectionAnchor != null) {
      _selectionAnchor = null;
      _showMenu();
    }
  }

  // MARK: Selection

  String? get _selectedText {
    final TextRange? range = _selection;
    if (range == null) return null;
    return _contentText
        .substring(range.start, range.end)
        .replaceAll(kZLObjectReplacementCharacter, '');
  }

  String? get _selectedRawText {
    final TextRange? range = _selection;
    if (range == null) return null;
    return widget.rawTextForRange?.call(range) ?? _selectedText;
  }

  TextRange _wordRange(int index) {
    for (final TextRange range in widget.atomicRanges) {
      if (index >= range.start && index < range.end && !range.isCollapsed) {
        return range;
      }
    }
    return _render?.wordAt(index) ?? TextRange(start: index, end: index + 1);
  }

  void _beginSelection(Offset local) {
    final RenderZLText? render = _render;
    if (render == null || _contentLength == 0) return;
    int index = _characterIndexAt(local) ?? render.caretAt(local);
    index = index.clamp(0, _contentLength - 1);
    final TextRange range = _wordRange(index);
    HapticFeedback.selectionClick();
    _selectionAnchor = range;
    _setSelection(range, showMenu: false);
  }

  void _extendSelection(Offset local) {
    final TextRange? anchor = _selectionAnchor;
    final RenderZLText? render = _render;
    if (anchor == null || render == null) return;
    final int caret = render.caretAt(local);
    _setSelection(
        TextRange(
            start: math.min(anchor.start, caret),
            end: math.max(anchor.end, caret)),
        showMenu: false);
  }

  void _setSelection(TextRange range, {required bool showMenu}) {
    final int start = range.start.clamp(0, _contentLength);
    final int end = range.end.clamp(start, _contentLength);
    if (end <= start) {
      _clearSelection();
      return;
    }
    final TextRange clamped = TextRange(start: start, end: end);
    final bool changed = clamped != _selection;
    setState(() {
      _selection = clamped;
      _showsMenu = showMenu;
    });
    _overlay.show();
    if (changed) {
      widget.onSelectionChanged?.call(clamped);
      widget.controller?._notify();
    }
  }

  void _selectAll() {
    if (_contentLength == 0) return;
    _setSelection(TextRange(start: 0, end: _contentLength), showMenu: true);
  }

  void _clearSelection() {
    _selectionAnchor = null;
    if (_selection == null) return;
    setState(() {
      _selection = null;
      _showsMenu = false;
    });
    _hideOverlay();
    widget.onSelectionChanged?.call(null);
    widget.controller?._notify();
  }

  void _hideOverlay() {
    if (_overlay.isShowing) _overlay.hide();
  }

  void _showMenu() {
    if (_selection == null) return;
    setState(() => _showsMenu = true);
    _overlay.show();
  }

  Future<void> _copySelection({required bool raw}) async {
    final String? text = raw ? _selectedRawText : _selectedText;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    widget.onCopy?.call(text, raw);
  }

  // MARK: Build

  TextStyle _baseTextStyle(BuildContext context) {
    final TextStyle inherited = DefaultTextStyle.of(context).style;
    return inherited.merge(widget.style.textStyle);
  }

  ZLAttributedText _resolveContent(
      BuildContext context, List<ZLLabelLink> links, ZLAttributedText content) {
    ZLAttributedText text = content;
    // Link styles.
    for (final ZLLabelLink link in links) {
      final ZLTextStyle style = link.style ?? widget.linkStyle;
      if (!style.isEmpty) text = text.applyingStyle(style, link.range);
    }
    // Inactive (a dialog covers the route).
    if (ModalRoute.isCurrentOf(context) == false) {
      for (final ZLLabelLink link in links) {
        final ZLTextStyle? style =
            link.inactiveStyle ?? widget.inactiveLinkStyle;
        if (style != null && !style.isEmpty) {
          text = text.applyingStyle(style, link.range);
        }
      }
    }
    // Press highlight.
    final ZLLabelLink? pressed = _pressed;
    if (pressed != null) {
      final ZLTextStyle style = pressed.activeStyle ?? widget.activeLinkStyle;
      if (!style.isEmpty) text = text.applyingStyle(style, pressed.range);
    }
    // Highlighted label (e.g. a selected cell).
    final Color? highlightColor = widget.highlightedTextColor;
    if (widget.highlighted && highlightColor != null) {
      text = text.applyingStyle(ZLTextStyle(
          textStyle: TextStyle(
              color: highlightColor, decorationColor: highlightColor)));
    }
    return text;
  }

  /// Text runs with a baseline offset become inline widgets (Flutter text
  /// spans cannot move the baseline).
  ZLAttributedText _resolveBaselineRuns(ZLAttributedText text, TextStyle base) {
    if (!text.runs.any((ZLTextRun run) =>
        !run.isWidget && (run.style.baselineOffset ?? 0) != 0)) {
      return text;
    }
    return ZLAttributedText.fromRuns(text.runs.map((ZLTextRun run) {
      final double shift = run.style.baselineOffset ?? 0;
      if (run.isWidget || shift == 0) return run;
      final TextStyle style = base.merge(run.style.textStyle);
      return ZLTextRun(
        run.text,
        style: run.style,
        group: run.group,
        widget: ZLRichWidget(
          alignment: PlaceholderAlignment.baseline,
          semanticsLabel: run.text,
          child: Transform.translate(
            offset: Offset(0, -shift),
            child: Text(run.text, style: style, maxLines: 1, softWrap: false),
          ),
        ),
      );
    }));
  }

  ZLAttributedText _styledToken(ZLAttributedText token) =>
      token.withBaseStyle(widget.style);

  Widget _buildChild(ZLTextRun run, TextStyle base, ZLLabelLink? link) {
    final ZLRichWidget inline = run.widget!;
    final TextStyle style = base.merge(run.style.textStyle);
    Widget child = IconTheme.merge(
      data: IconThemeData(color: style.color, size: style.fontSize),
      child: DefaultTextStyle.merge(style: style, child: inline.child),
    );
    if (inline.tappable && link != null) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _performTap(link),
        child: child,
      );
    }
    if (inline.semanticsLabel != null) {
      child = Semantics(label: inline.semanticsLabel, child: child);
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle base = _baseTextStyle(context);
    final ZLLabelLink? collapseLink;
    ZLAttributedText content = widget.content;
    List<ZLLabelLink> links = widget.links;
    if (_expanded &&
        widget.collapseToken != null &&
        widget.collapseToken!.isNotEmpty) {
      final ZLAttributedText token =
          _styledToken(widget.collapseToken!).withGroup(-2);
      collapseLink = ZLLabelLink(
        range: TextRange(
            start: content.length, end: content.length + token.length),
        style: ZLTextStyle.none,
        onTap: (_) => _expandTokenTapped(false),
      );
      content = content + token;
      links = <ZLLabelLink>[...links, collapseLink];
    } else {
      collapseLink = null;
    }
    _shownLinks = links;
    _shown =
        _resolveBaselineRuns(_resolveContent(context, links, content), base);

    final ZLAttributedText token = _showsExpandToken
        ? _styledToken(widget.expandToken!)
        : _styledToken(widget.truncationToken ?? ZLAttributedText('…'));
    final ZLAttributedText shownToken = _resolveBaselineRuns(token, base);

    final TextDirection direction = widget.textDirection ??
        ZLLabelCore.detectTextDirection(_shown.string) ??
        Directionality.of(context);
    final TextAlign align = widget.textAlign ??
        widget.style.textAlign ??
        DefaultTextStyle.of(context).textAlign ??
        TextAlign.start;

    final List<Widget> children = <Widget>[
      for (final (int offset, ZLTextRun run) in _shown.runsWithOffsets)
        if (run.isWidget) _buildChild(run, base, _tapLinkAtIndex(offset)),
      for (final ZLTextRun run in shownToken.runs)
        if (run.isWidget) _buildChild(run, base, null),
    ];

    final Color selectionColor = widget.selectionColor ??
        DefaultSelectionStyle.of(context).selectionColor ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.25);

    final List<ZLSemanticsLink> semanticsLinks = <ZLSemanticsLink>[
      for (final ZLLabelLink link in links)
        if (link.range.end <= _shown.length)
          ZLSemanticsLink(
            range: link.range,
            label: _shown.string
                .substring(link.range.start, link.range.end)
                .replaceAll(kZLObjectReplacementCharacter, ''),
            hint: link.semanticsHint,
            isButton: identical(link, collapseLink),
            onTap: () => _performTap(link),
            onLongPress:
                link.onLongPress == null ? null : () => link.onLongPress!(link),
          ),
      if (_showsExpandToken)
        ZLSemanticsLink(
          range: TextRange(start: _shown.length + 1, end: _shown.length + 2),
          label: widget.expandToken!.string
              .replaceAll(kZLObjectReplacementCharacter, '')
              .trim(),
          isButton: true,
          onTap: () => _expandTokenTapped(true),
        ),
    ];

    Widget result = ZLTextLayout(
      key: _layoutKey,
      content: _shown,
      token: shownToken,
      baseStyle: base,
      lineSpacing: widget.style.lineSpacing,
      textAlign: align,
      textDirection: direction,
      textScaler: widget.textScaler ?? MediaQuery.textScalerOf(context),
      maxLines: _expanded ? null : widget.maxLines,
      collapseThreshold: widget.collapseThreshold,
      truncationMode: widget.expandToken != null
          ? ZLTruncationMode.tail
          : widget.truncationMode,
      padding: widget.padding.resolve(direction),
      verticalAlignment: widget.verticalAlignment,
      adjustsFontSizeToFit: widget.adjustsFontSizeToFit,
      minimumScaleFactor: widget.minimumScaleFactor,
      selection: _selection,
      selectionColor: selectionColor,
      semanticsLabel: widget.semanticsLabel,
      semanticsLinks: semanticsLinks,
      statistics: widget.statistics,
      children: children,
    );

    result = RawGestureDetector(
      behavior: HitTestBehavior.deferToChild,
      gestures: <Type, GestureRecognizerFactory>{
        _ZLTapRecognizer:
            GestureRecognizerFactoryWithHandlers<_ZLTapRecognizer>(
          () => _ZLTapRecognizer(debugOwner: this, accepts: _acceptsTap),
          (_ZLTapRecognizer recognizer) => recognizer
            ..accepts = _acceptsTap
            ..onTapDown = _onTapDown
            ..onTapUp = _onTapUp
            ..onTapCancel = _onTapCancel,
        ),
        _ZLLongPressRecognizer:
            GestureRecognizerFactoryWithHandlers<_ZLLongPressRecognizer>(
          () => _ZLLongPressRecognizer(
              debugOwner: this, accepts: _acceptsLongPress),
          (_ZLLongPressRecognizer recognizer) => recognizer
            ..accepts = _acceptsLongPress
            ..onLongPressStart = _onLongPressStart
            ..onLongPressMoveUpdate = _onLongPressMoveUpdate
            ..onLongPressEnd = _onLongPressEnd,
        ),
        if (widget.onDoubleTap != null)
          _ZLDoubleTapRecognizer:
              GestureRecognizerFactoryWithHandlers<_ZLDoubleTapRecognizer>(
            () => _ZLDoubleTapRecognizer(
                debugOwner: this, accepts: _acceptsDoubleTap),
            (_ZLDoubleTapRecognizer recognizer) => recognizer
              ..accepts = _acceptsDoubleTap
              ..onDoubleTapDown = (TapDownDetails details) {
                _doubleTapPosition = details.globalPosition;
              }
              ..onDoubleTap = _onDoubleTap,
          ),
      },
      child: result,
    );

    if (widget.selectable) {
      result = TapRegion(
        groupId: this,
        enabled: _selection != null,
        onTapOutside: (_) => _clearSelection(),
        child: OverlayPortal(
          controller: _overlay,
          overlayChildBuilder: _buildSelectionOverlay,
          child: CompositedTransformTarget(link: _layerLink, child: result),
        ),
      );
    }
    return result;
  }

  void _onDoubleTap() {
    final Offset? global = _doubleTapPosition;
    final Offset? local = global == null ? null : _toLocal(global);
    if (global == null || local == null) return;
    widget.onDoubleTap?.call(_details(local, global));
  }

  // MARK: Selection overlay

  Widget _buildSelectionOverlay(BuildContext context) {
    final TextRange? selection = _selection;
    final RenderZLText? render = _render;
    if (selection == null || render == null) return const SizedBox.shrink();
    final Color color = widget.selectionColor?.withValues(alpha: 1) ??
        Theme.of(context).colorScheme.primary;
    final Rect? startCaret = render.caretRect(selection.start);
    final Rect? endCaret =
        render.caretRect(selection.end, preferPreviousLine: true);
    final Rect? bounds = render.boundingRectForRange(selection);

    Widget handle(Rect caret, {required bool isStart}) {
      const double touchWidth = 28;
      const double dot = 10;
      final double height = caret.height + dot + 8;
      final Offset topLeft = Offset(caret.center.dx - touchWidth / 2,
          isStart ? caret.top - dot - 4 : caret.top);
      return CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: topLeft,
        child: _ZLSelectionHandle(
          isStart: isStart,
          color: color,
          size: Size(touchWidth, height),
          caret: caret,
          onDragStart: () {
            _adjustingSelection = true;
            setState(() => _showsMenu = false);
          },
          onDragUpdate: (Offset global) {
            final Offset? local = _toLocal(global);
            final TextRange? current = _selection;
            if (local == null || current == null) return;
            final int caretIndex = render.caretAt(local);
            if (isStart && caretIndex < current.end) {
              _setSelection(TextRange(start: caretIndex, end: current.end),
                  showMenu: false);
            } else if (!isStart && caretIndex > current.start) {
              _setSelection(TextRange(start: current.start, end: caretIndex),
                  showMenu: false);
            }
          },
          onDragEnd: () {
            _adjustingSelection = false;
            _showMenu();
          },
        ),
      );
    }

    final bool canSelectAll =
        selection.start > 0 || selection.end < _contentLength;
    final Widget menu = _ZLSelectionToolbar(
      items: <(String, VoidCallback)>[
        (
          widget.copyLabel,
          () {
            _copySelection(raw: false);
            _clearSelection();
          }
        ),
        if (widget.rawTextForRange != null)
          (
            widget.copyRawLabel,
            () {
              _copySelection(raw: true);
              _clearSelection();
            }
          ),
        if (canSelectAll) (widget.selectAllLabel, _selectAll),
      ],
    );

    Widget? toolbar;
    if (_showsMenu && !_adjustingSelection && bounds != null) {
      final double globalTop = render.localToGlobal(bounds.topCenter).dy;
      final bool below = globalTop < MediaQuery.paddingOf(context).top + 56;
      toolbar = CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topLeft,
        followerAnchor: below ? Alignment.topCenter : Alignment.bottomCenter,
        offset: below
            ? bounds.bottomCenter + const Offset(0, 22)
            : bounds.topCenter - const Offset(0, 10),
        child: menu,
      );
    }

    return TapRegion(
      groupId: this,
      child: Stack(
        children: <Widget>[
          if (startCaret != null)
            Positioned(
                left: 0, top: 0, child: handle(startCaret, isStart: true)),
          if (endCaret != null)
            Positioned(
                left: 0, top: 0, child: handle(endCaret, isStart: false)),
          if (toolbar != null) Positioned(left: 0, top: 0, child: toolbar),
        ],
      ),
    );
  }
}

/// Selection handle: a caret line with a dot above (start) or below (end).
class _ZLSelectionHandle extends StatefulWidget {
  const _ZLSelectionHandle({
    required this.isStart,
    required this.color,
    required this.size,
    required this.caret,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final bool isStart;
  final Color color;
  final Size size;
  final Rect caret;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  State<_ZLSelectionHandle> createState() => _ZLSelectionHandleState();
}

class _ZLSelectionHandleState extends State<_ZLSelectionHandle> {
  /// Distance from the finger to the caret centre when the drag started.
  Offset _dragOffset = Offset.zero;

  Offset _caretCenterGlobal() {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    final double dy =
        widget.isStart ? 14 + widget.caret.height / 2 : widget.caret.height / 2;
    return box.localToGlobal(Offset(widget.size.width / 2, dy));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onPanStart: (DragStartDetails details) {
        _dragOffset = _caretCenterGlobal() - details.globalPosition;
        widget.onDragStart();
      },
      onPanUpdate: (DragUpdateDetails details) =>
          widget.onDragUpdate(details.globalPosition + _dragOffset),
      onPanEnd: (_) => widget.onDragEnd(),
      onPanCancel: widget.onDragEnd,
      child: CustomPaint(
        size: widget.size,
        painter: _ZLHandlePainter(isStart: widget.isStart, color: widget.color),
      ),
    );
  }
}

class _ZLHandlePainter extends CustomPainter {
  const _ZLHandlePainter({required this.isStart, required this.color});

  final bool isStart;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double dot = 10;
    final Paint paint = Paint()..color = color;
    final double midX = size.width / 2;
    if (isStart) {
      canvas.drawOval(Rect.fromLTWH(midX - dot / 2, 4, dot, dot), paint);
      canvas.drawRect(
          Rect.fromLTWH(midX - 1, 4 + dot / 2, 2, size.height - 8 - dot / 2),
          paint);
    } else {
      canvas.drawRect(
          Rect.fromLTWH(midX - 1, 0, 2, size.height - dot - 4), paint);
      canvas.drawOval(
          Rect.fromLTWH(midX - dot / 2, size.height - dot - 4, dot, dot),
          paint);
    }
  }

  @override
  bool shouldRepaint(_ZLHandlePainter oldDelegate) =>
      oldDelegate.isStart != isStart || oldDelegate.color != color;
}

/// The copy menu shown above the selection.
class _ZLSelectionToolbar extends StatelessWidget {
  const _ZLSelectionToolbar({required this.items});

  final List<(String, VoidCallback)> items;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF0222222),
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < items.length; i++) ...<Widget>[
            if (i > 0)
              Container(width: 0.5, height: 20, color: const Color(0x55FFFFFF)),
            InkWell(
              onTap: items[i].$2,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Text(items[i].$1,
                    style: const TextStyle(
                        color: Color(0xFFFFFFFF), fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
