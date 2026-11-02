import 'package:flutter/widgets.dart';

import 'zl_attributed_text.dart';
import 'zl_data_detector.dart';
import 'zl_label_core.dart';
import 'zl_text_layout.dart';
import 'zl_text_style.dart';

/// Low-level rich text label: shows a [ZLAttributedText] (or a plain string)
/// with links, without rule parsing (the Flutter counterpart of the iOS
/// `ZLAttributedLabel`, a TTTAttributedLabel replacement).
///
/// * padding and vertical alignment, line limit with head / middle / tail
///   truncation and a rich [truncationToken] (may contain inline widgets);
/// * links: [links], runs styled with [ZLTextStyle.linkTo], and
///   [dataDetectorTypes] (URLs, phone numbers, e-mails, dates, addresses);
///   default / pressed / inactive styles, tap and long press callbacks,
///   larger touch areas;
/// * [adjustsFontSizeToFit] / [minimumScaleFactor];
/// * [highlighted] text colour;
/// * every link is a separate accessibility node.
///
/// ```dart
/// ZLAttributedLabel(
///   '阅读并同意《用户协议》，或访问 https://flutter.dev',
///   dataDetectorTypes: const {ZLDataDetectorType.link},
///   links: [ZLLabelLink(range: const TextRange(start: 5, end: 11), onTap: (_) => openAgreement())],
///   onLinkTap: (link) => launchUrl(link.url!),
/// )
/// ```
class ZLAttributedLabel extends StatefulWidget {
  /// A label with plain [text] in [style].
  ZLAttributedLabel(
    String text, {
    Key? key,
    ZLTextStyle style = ZLTextStyle.none,
    List<ZLLabelLink> links = const <ZLLabelLink>[],
    ZLTextStyle linkStyle = defaultLinkStyle,
    ZLTextStyle activeLinkStyle = defaultActiveLinkStyle,
    ZLTextStyle? inactiveLinkStyle = defaultInactiveLinkStyle,
    Set<ZLDataDetectorType> dataDetectorTypes = const <ZLDataDetectorType>{},
    void Function(ZLLabelLink link)? onLinkTap,
    void Function(ZLLabelLink link, Offset location)? onLinkLongPress,
    bool extendsLinkTouchArea = false,
    int? maxLines,
    ZLTruncationMode truncationMode = ZLTruncationMode.tail,
    ZLAttributedText? truncationToken,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    ZLVerticalAlignment verticalAlignment = ZLVerticalAlignment.center,
    TextAlign? textAlign,
    TextDirection? textDirection,
    TextScaler? textScaler,
    bool highlighted = false,
    Color? highlightedTextColor,
    bool adjustsFontSizeToFit = false,
    double minimumScaleFactor = 0,
    bool selectable = false,
    String? semanticsLabel,
    ZLLabelController? controller,
  }) : this.rich(
          ZLAttributedText(text, style: style),
          key: key,
          style: style,
          links: links,
          linkStyle: linkStyle,
          activeLinkStyle: activeLinkStyle,
          inactiveLinkStyle: inactiveLinkStyle,
          dataDetectorTypes: dataDetectorTypes,
          onLinkTap: onLinkTap,
          onLinkLongPress: onLinkLongPress,
          extendsLinkTouchArea: extendsLinkTouchArea,
          maxLines: maxLines,
          truncationMode: truncationMode,
          truncationToken: truncationToken,
          padding: padding,
          verticalAlignment: verticalAlignment,
          textAlign: textAlign,
          textDirection: textDirection,
          textScaler: textScaler,
          highlighted: highlighted,
          highlightedTextColor: highlightedTextColor,
          adjustsFontSizeToFit: adjustsFontSizeToFit,
          minimumScaleFactor: minimumScaleFactor,
          selectable: selectable,
          semanticsLabel: semanticsLabel,
          controller: controller,
        );

  /// A label with rich [text]. Parts of [text] without a font / colour use
  /// [style] (merged on top of the ambient [DefaultTextStyle]).
  const ZLAttributedLabel.rich(
    this.text, {
    super.key,
    this.style = ZLTextStyle.none,
    this.links = const <ZLLabelLink>[],
    this.linkStyle = defaultLinkStyle,
    this.activeLinkStyle = defaultActiveLinkStyle,
    this.inactiveLinkStyle = defaultInactiveLinkStyle,
    this.dataDetectorTypes = const <ZLDataDetectorType>{},
    this.onLinkTap,
    this.onLinkLongPress,
    this.extendsLinkTouchArea = false,
    this.maxLines,
    this.truncationMode = ZLTruncationMode.tail,
    this.truncationToken,
    this.padding = EdgeInsets.zero,
    this.verticalAlignment = ZLVerticalAlignment.center,
    this.textAlign,
    this.textDirection,
    this.textScaler,
    this.highlighted = false,
    this.highlightedTextColor,
    this.adjustsFontSizeToFit = false,
    this.minimumScaleFactor = 0,
    this.selectable = false,
    this.semanticsLabel,
    this.controller,
  });

  /// Blue with an underline.
  static const ZLTextStyle defaultLinkStyle = ZLTextStyle(
      textStyle: TextStyle(
          color: Color(0xFF007AFF), decoration: TextDecoration.underline));

  /// Half transparent blue.
  static const ZLTextStyle defaultActiveLinkStyle =
      ZLTextStyle(textStyle: TextStyle(color: Color(0x80007AFF)));

  /// Grey.
  static const ZLTextStyle defaultInactiveLinkStyle =
      ZLTextStyle(textStyle: TextStyle(color: Color(0xFF8E8E93)));

  final ZLAttributedText text;

  /// Style of the text (font / colour of parts without their own).
  final ZLTextStyle style;

  /// Links added by hand; later links win where they overlap.
  final List<ZLLabelLink> links;

  /// Style of links without their own style (detected links, `linkTo` runs).
  final ZLTextStyle linkStyle;

  /// Style of a pressed link without its own `activeStyle`. Use
  /// [ZLTextStyle.none] to keep the style when pressed.
  final ZLTextStyle activeLinkStyle;

  /// Style of links while a dialog / sheet covers the route of the label.
  final ZLTextStyle? inactiveLinkStyle;

  /// Content recognised as links.
  final Set<ZLDataDetectorType> dataDetectorTypes;

  /// Tap on a link without its own `onTap`.
  final void Function(ZLLabelLink link)? onLinkTap;

  /// Long press on a link without its own `onLongPress`.
  final void Function(ZLLabelLink link, Offset location)? onLinkLongPress;

  /// When the finger is not on the text (line spacing, end of line …) links
  /// within 15pt are found as well.
  final bool extendsLinkTouchArea;

  /// Maximum number of lines, `null` or 0 for no limit.
  final int? maxLines;

  /// Truncation of a single line; multiple lines are truncated at the tail.
  final ZLTruncationMode truncationMode;

  /// Shown where the text is truncated, `…` (with the style of the text)
  /// when `null`.
  final ZLAttributedText? truncationToken;

  final EdgeInsetsGeometry padding;
  final ZLVerticalAlignment verticalAlignment;

  /// `null`: the style's alignment, else the start of the text.
  final TextAlign? textAlign;

  /// `null`: detected from the first strong character of the text (Arabic,
  /// Hebrew … are right to left), else the ambient [Directionality].
  final TextDirection? textDirection;

  /// `null`: [MediaQuery.textScalerOf].
  final TextScaler? textScaler;

  /// When `true` all text uses [highlightedTextColor] (e.g. selected cells).
  final bool highlighted;
  final Color? highlightedTextColor;

  /// Shrinks all fonts by the same factor (down to [minimumScaleFactor]) when
  /// the text does not fit: by width for one line, by line count and height
  /// for multiple lines. Inline widgets are not scaled.
  final bool adjustsFontSizeToFit;

  /// 0 – 1; 0 disables the shrinking.
  final double minimumScaleFactor;

  /// Long press selects words, with copy menu.
  final bool selectable;

  final String? semanticsLabel;

  final ZLLabelController? controller;

  @override
  State<ZLAttributedLabel> createState() => _ZLAttributedLabelState();
}

class _ZLAttributedLabelState extends State<ZLAttributedLabel> {
  String? _detectedSource;
  Set<ZLDataDetectorType>? _detectedTypes;
  List<ZLDataDetectorResult> _detected = const <ZLDataDetectorResult>[];

  List<ZLLabelLink> _links() {
    final ZLAttributedText text = widget.text;
    final List<ZLLabelLink> result = <ZLLabelLink>[];
    // Runs with a link target.
    int? start;
    Object? target;
    void flush(int end) {
      if (start != null && target != null && end > start!) {
        final Object value = target!;
        result.add(ZLLabelLink(
          range: TextRange(start: start!, end: end),
          url: value is Uri ? value : Uri.tryParse(value.toString()),
        ));
      }
      start = null;
      target = null;
    }

    for (final (int offset, ZLTextRun run) in text.runsWithOffsets) {
      if (run.style.link != target) {
        flush(offset);
        if (run.style.link != null) {
          start = offset;
          target = run.style.link;
        }
      }
    }
    flush(text.length);

    // Data detectors.
    if (widget.dataDetectorTypes.isNotEmpty) {
      final String source = text.string;
      if (source != _detectedSource ||
          !_setEquals(_detectedTypes, widget.dataDetectorTypes)) {
        _detectedSource = source;
        _detectedTypes = widget.dataDetectorTypes;
        _detected = ZLDataDetector(widget.dataDetectorTypes).detect(source);
      }
      for (final ZLDataDetectorResult match in _detected) {
        final bool overlaps = result.any((ZLLabelLink link) =>
            link.range.start < match.end && match.start < link.range.end);
        if (!overlaps) {
          result.add(
              ZLLabelLink(range: match.range, url: match.url, result: match));
        }
      }
    }
    return <ZLLabelLink>[...result, ...widget.links];
  }

  @override
  Widget build(BuildContext context) {
    return ZLLabelCore(
      content: widget.text,
      style: widget.style,
      links: _links(),
      linkStyle: widget.linkStyle,
      activeLinkStyle: widget.activeLinkStyle,
      inactiveLinkStyle: widget.inactiveLinkStyle,
      onLinkTap: widget.onLinkTap,
      onLinkLongPress: widget.onLinkLongPress,
      extendsLinkTouchArea: widget.extendsLinkTouchArea,
      maxLines: widget.maxLines,
      truncationMode: widget.truncationMode,
      truncationToken: widget.truncationToken,
      padding: widget.padding,
      verticalAlignment: widget.verticalAlignment,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      textScaler: widget.textScaler,
      highlighted: widget.highlighted,
      highlightedTextColor: widget.highlightedTextColor,
      adjustsFontSizeToFit: widget.adjustsFontSizeToFit,
      minimumScaleFactor: widget.minimumScaleFactor,
      selectable: widget.selectable,
      semanticsLabel: widget.semanticsLabel,
      controller: widget.controller,
    );
  }
}

bool _setEquals<T>(Set<T>? a, Set<T>? b) {
  if (a == null || b == null) return a == b;
  return a.length == b.length && a.containsAll(b);
}
