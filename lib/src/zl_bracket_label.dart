import 'zl_tag_rich_label.dart';

/// [ZLTagRichLabel] using `[` / `]` as tag symbols: `[h]text[/h]`,
/// `[h1]text[/h1]`, `[a href="x"]link[/a]` … All other behaviour is the same
/// as [ZLTagRichLabel].
///
/// ```dart
/// ZLBracketLabel(
///   text: 'I agree to the [h1]User Agreement[/h1] and [h2]Privacy Policy[/h2].',
///   tagStyle: ZLTextStyle().color(Colors.blue),
///   onTagTap: (info) => print('${info.name} ${info.text}'),
/// )
/// ```
class ZLBracketLabel extends ZLTagRichLabel {
  const ZLBracketLabel({
    super.key,
    required super.text,
    super.rules,
    super.style,
    super.highlightStyle,
    super.tagStyle,
    super.tagStyles,
    super.tagStyleBuilder,
    super.tagSpanBuilder,
    super.tagWidgetBuilder,
    super.tagHighlightStyles,
    super.tagTapHandlers,
    super.onTagTap,
    super.onTagLongPress,
    super.onParsed,
    super.tagPriority,
    super.parsesTags,
    super.tagConfiguration,
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
  }) : super(tagOpenSymbol: openSymbol, tagCloseSymbol: closeSymbol);

  /// Opening tag symbol.
  static const String openSymbol = '[';

  /// Closing tag symbol.
  static const String closeSymbol = ']';
}

