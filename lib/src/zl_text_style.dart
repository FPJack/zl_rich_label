import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Rounded background drawn behind a piece of text: capsules for `#topic#`,
/// inline `code`, badges, outlined tags …
///
/// * The horizontal [padding] and [margin] take up layout space, so the
///   background never overlaps neighbouring text.
/// * The vertical [padding] only affects painting and does not change the line
///   height. Use [ZLTextStyle.lineSpacing] when the background is tall.
/// * A background that wraps over several lines is painted line by line.
@immutable
class ZLTextBackground {
  const ZLTextBackground({
    this.fillColor,
    this.strokeColor,
    this.strokeWidth = 1,
    this.cornerRadius = -1,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    this.margin = 2,
  });

  /// Light capsule tinted with [color] (12% alpha), fully rounded ends.
  factory ZLTextBackground.capsule(Color color) =>
      ZLTextBackground(fillColor: color.withValues(alpha: 0.12));

  /// Inline code: grey fill, hairline border, small corner radius.
  static const ZLTextBackground code = ZLTextBackground(
    fillColor: Color(0x1F787880),
    strokeColor: Color(0x4A3C3C43),
    strokeWidth: 0.5,
    cornerRadius: 4,
    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
    margin: 1,
  );

  /// Fill colour, `null` for no fill.
  final Color? fillColor;

  /// Border colour, `null` for no border.
  final Color? strokeColor;

  /// Border width.
  final double strokeWidth;

  /// Corner radius. Negative values mean "half of the height" (capsule).
  final double cornerRadius;

  /// Distance between the text and the edge of the background.
  final EdgeInsets padding;

  /// Horizontal distance between the background and the neighbouring text.
  final double margin;

  ZLTextBackground copyWith({
    Color? fillColor,
    Color? strokeColor,
    double? strokeWidth,
    double? cornerRadius,
    EdgeInsets? padding,
    double? margin,
  }) {
    return ZLTextBackground(
      fillColor: fillColor ?? this.fillColor,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ZLTextBackground &&
      other.fillColor == fillColor &&
      other.strokeColor == strokeColor &&
      other.strokeWidth == strokeWidth &&
      other.cornerRadius == cornerRadius &&
      other.padding == padding &&
      other.margin == margin;

  @override
  int get hashCode => Object.hash(
      fillColor, strokeColor, strokeWidth, cornerRadius, padding, margin);

  @override
  String toString() =>
      'ZLTextBackground(fill: $fillColor, stroke: $strokeColor, radius: $cornerRadius, padding: $padding)';
}

/// Rich-text style used everywhere in this package.
///
/// It wraps a Flutter [TextStyle] and adds the attributes that a plain
/// [TextStyle] cannot express: capsule [background], [gradient] text,
/// [baselineOffset], paragraph [lineSpacing] / [firstLineIndent] and [link].
///
/// Every chain method returns a new style and never modifies the receiver:
///
/// ```dart
/// final style = ZLTextStyle().fontSize(15).color(Colors.black87).lineSpacing(4);
/// final title = style.bold().fontSize(20).gradientColors([Colors.pink, Colors.orange]);
/// final topic = ZLTextStyle().color(Colors.purple).capsule(Colors.purple);
/// ```
///
/// Styles are merged with [merge]: non-null values of the other style win.
@immutable
class ZLTextStyle {
  const ZLTextStyle({
    this.textStyle = const TextStyle(),
    this.background,
    this.gradient,
    this.baselineOffset,
    this.lineSpacing,
    this.firstLineIndent,
    this.textAlign,
    this.link,
  });

  /// Wraps a Flutter [TextStyle].
  const ZLTextStyle.text(TextStyle style) : this(textStyle: style);

  /// An empty style. Used as "no highlight" for press highlight styles.
  static const ZLTextStyle none = ZLTextStyle();

  /// Font, colour, decoration, letter spacing, shadows …
  final TextStyle textStyle;

  /// Capsule background, painted by the label.
  final ZLTextBackground? background;

  /// Gradient fill of the glyphs (painted line by line). The original colour
  /// of the text, including its decorations, becomes transparent.
  final Gradient? gradient;

  /// Moves the text up (positive) or down (negative) without changing the
  /// line height.
  final double? baselineOffset;

  /// Extra space between lines. Only the value of the label's base style is
  /// used (Flutter lays out lines per paragraph, not per run).
  final double? lineSpacing;

  /// Indent of the first line of every paragraph that starts inside the run.
  final double? firstLineIndent;

  /// Horizontal alignment. Only the value of the label's base style is used,
  /// and only when the label itself has no `textAlign`.
  final TextAlign? textAlign;

  /// Link target. [ZLAttributedLabel] turns runs with a link into tappable
  /// [ZLLabelLink]s (similar to `NSAttributedString.Key.link`).
  final Object? link;

  /// Whether the style sets nothing.
  bool get isEmpty =>
      textStyle == const TextStyle() &&
      background == null &&
      gradient == null &&
      baselineOffset == null &&
      lineSpacing == null &&
      firstLineIndent == null &&
      textAlign == null &&
      link == null;

  /// Returns a style whose non-null values are taken from [other] first.
  ZLTextStyle merge(ZLTextStyle? other) {
    if (other == null || other.isEmpty) return this;
    if (isEmpty) return other;
    return ZLTextStyle(
      textStyle: textStyle.merge(other.textStyle),
      background: other.background ?? background,
      gradient: other.gradient ?? gradient,
      baselineOffset: other.baselineOffset ?? baselineOffset,
      lineSpacing: other.lineSpacing ?? lineSpacing,
      firstLineIndent: other.firstLineIndent ?? firstLineIndent,
      textAlign: other.textAlign ?? textAlign,
      link: other.link ?? link,
    );
  }

  /// Same as [merge], reads better in chains: `base.adding(highlight)`.
  ZLTextStyle adding(ZLTextStyle? other) => merge(other);

  ZLTextStyle copyWith({
    TextStyle? textStyle,
    ZLTextBackground? background,
    Gradient? gradient,
    double? baselineOffset,
    double? lineSpacing,
    double? firstLineIndent,
    TextAlign? textAlign,
    Object? link,
  }) {
    return ZLTextStyle(
      textStyle: textStyle ?? this.textStyle,
      background: background ?? this.background,
      gradient: gradient ?? this.gradient,
      baselineOffset: baselineOffset ?? this.baselineOffset,
      lineSpacing: lineSpacing ?? this.lineSpacing,
      firstLineIndent: firstLineIndent ?? this.firstLineIndent,
      textAlign: textAlign ?? this.textAlign,
      link: link ?? this.link,
    );
  }

  /// Removes the label-drawn decorations (background, gradient, baseline
  /// offset, link) and keeps the [TextStyle] and paragraph attributes.
  ZLTextStyle withoutDecorations() => ZLTextStyle(
        textStyle: textStyle,
        lineSpacing: lineSpacing,
        firstLineIndent: firstLineIndent,
        textAlign: textAlign,
      );

  ZLTextStyle _text(TextStyle style) =>
      copyWith(textStyle: textStyle.merge(style));

  // MARK: Font

  /// Replaces the whole [TextStyle] font related values with [style].
  ZLTextStyle font(TextStyle style) => _text(style);

  ZLTextStyle fontSize(double size) => _text(TextStyle(fontSize: size));

  ZLTextStyle fontWeight(FontWeight weight) =>
      _text(TextStyle(fontWeight: weight));

  ZLTextStyle fontFamily(String family, {List<String>? fallback}) =>
      _text(TextStyle(fontFamily: family, fontFamilyFallback: fallback));

  /// System font of [size] (optionally with a [weight]).
  ZLTextStyle systemFont(double size,
          {FontWeight weight = FontWeight.normal}) =>
      _text(TextStyle(fontSize: size, fontWeight: weight));

  /// Bold font of [size].
  ZLTextStyle boldFont(double size) =>
      _text(TextStyle(fontSize: size, fontWeight: FontWeight.bold));

  /// Monospaced font of [size].
  ZLTextStyle monospacedFont(double size,
          {FontWeight weight = FontWeight.normal}) =>
      _text(TextStyle(
        fontSize: size,
        fontWeight: weight,
        fontFamily: 'monospace',
        fontFamilyFallback: const <String>[
          'Menlo',
          'Courier',
          'RobotoMono',
          'Consolas'
        ],
      ));

  /// Bold version of the current font.
  ZLTextStyle bold() => _text(const TextStyle(fontWeight: FontWeight.bold));

  /// Italic version of the current font.
  ZLTextStyle italic() => _text(const TextStyle(fontStyle: FontStyle.italic));

  // MARK: Colour & decorations

  ZLTextStyle color(Color color) => _text(TextStyle(color: color));

  /// Rectangular background behind the glyphs (Flutter's
  /// [TextStyle.backgroundColor]). Use [background] / [capsule] for rounded
  /// backgrounds with padding.
  ZLTextStyle backgroundColor(Color color) =>
      _text(TextStyle(backgroundColor: color));

  /// Underline; keeps an existing strikethrough.
  ZLTextStyle underline(
          {TextDecorationStyle style = TextDecorationStyle.solid,
          Color? color,
          double? thickness}) =>
      _decoration(TextDecoration.underline, style, color, thickness);

  /// Strikethrough; keeps an existing underline.
  ZLTextStyle strikethrough(
          {TextDecorationStyle style = TextDecorationStyle.solid,
          Color? color,
          double? thickness}) =>
      _decoration(TextDecoration.lineThrough, style, color, thickness);

  ZLTextStyle _decoration(TextDecoration decoration, TextDecorationStyle style,
      Color? color, double? thickness) {
    final TextDecoration? current = textStyle.decoration;
    final TextDecoration combined =
        current == null || current == TextDecoration.none
            ? decoration
            : TextDecoration.combine(<TextDecoration>[current, decoration]);
    return _text(TextStyle(
      decoration: combined,
      decorationStyle: style,
      decorationColor: color,
      decorationThickness: thickness,
    ));
  }

  /// Letter spacing (`kern` on iOS).
  ZLTextStyle kern(double value) => _text(TextStyle(letterSpacing: value));

  ZLTextStyle wordSpacing(double value) => _text(TextStyle(wordSpacing: value));

  /// Moves the text up (positive) or down (negative), see [baselineOffset].
  ZLTextStyle baseline(double offset) => copyWith(baselineOffset: offset);

  ZLTextStyle shadow(Color color,
          {Offset offset = const Offset(0, 1), double blur = 2}) =>
      _text(TextStyle(shadows: <Shadow>[
        Shadow(color: color, offset: offset, blurRadius: blur)
      ]));

  /// Font features such as `FontFeature.tabularFigures()`.
  ZLTextStyle fontFeatures(List<ui.FontFeature> features) =>
      _text(TextStyle(fontFeatures: features));

  /// Link target, see [link].
  ZLTextStyle linkTo(Object target) => copyWith(link: target);

  // MARK: Label-drawn decorations

  ZLTextStyle withBackground(ZLTextBackground value) =>
      copyWith(background: value);

  /// Light capsule background ([ZLTextBackground.capsule]).
  ZLTextStyle capsule(Color color) =>
      copyWith(background: ZLTextBackground.capsule(color));

  /// Inline code background ([ZLTextBackground.code]).
  ZLTextStyle codeBackground() => copyWith(background: ZLTextBackground.code);

  ZLTextStyle withGradient(Gradient value) => copyWith(gradient: value);

  /// Linear gradient text, left to right (top to bottom when [vertical]).
  ZLTextStyle gradientColors(List<Color> colors, {bool vertical = false}) =>
      copyWith(
        gradient: LinearGradient(
          colors:
              colors.length == 1 ? <Color>[colors.first, colors.first] : colors,
          begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
          end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
        ),
      );

  // MARK: Paragraph

  ZLTextStyle withLineSpacing(double value) => copyWith(lineSpacing: value);

  /// Line height as a multiple of the font size ([TextStyle.height]).
  ZLTextStyle lineHeightMultiple(double value) =>
      _text(TextStyle(height: value));

  ZLTextStyle indent(double value) => copyWith(firstLineIndent: value);

  ZLTextStyle alignment(TextAlign value) => copyWith(textAlign: value);

  @override
  bool operator ==(Object other) =>
      other is ZLTextStyle &&
      other.textStyle == textStyle &&
      other.background == background &&
      other.gradient == gradient &&
      other.baselineOffset == baselineOffset &&
      other.lineSpacing == lineSpacing &&
      other.firstLineIndent == firstLineIndent &&
      other.textAlign == textAlign &&
      other.link == link;

  @override
  int get hashCode => Object.hash(textStyle, background, gradient,
      baselineOffset, lineSpacing, firstLineIndent, textAlign, link);

  @override
  String toString() {
    final List<String> parts = <String>[
      if (textStyle != const TextStyle()) textStyle.toString(),
      if (background != null) 'background: $background',
      if (gradient != null) 'gradient: $gradient',
      if (baselineOffset != null) 'baselineOffset: $baselineOffset',
      if (lineSpacing != null) 'lineSpacing: $lineSpacing',
      if (firstLineIndent != null) 'firstLineIndent: $firstLineIndent',
      if (textAlign != null) 'textAlign: $textAlign',
      if (link != null) 'link: $link',
    ];
    return 'ZLTextStyle(${parts.join(', ')})';
  }
}

/// Convenience conversion from a Flutter [TextStyle].
extension ZLTextStyleConversion on TextStyle {
  /// Wraps this [TextStyle] in a [ZLTextStyle].
  ZLTextStyle get zl => ZLTextStyle(textStyle: this);
}
