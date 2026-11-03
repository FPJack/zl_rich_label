import 'dart:ui' show Color, TextRange;

import 'package:flutter/foundation.dart';

import 'zl_rule.dart';

/// Configuration of the tag parser.
@immutable
class ZLTagParserConfiguration {
  const ZLTagParserConfiguration({
    this.namePattern = r'h\d*',
    this.allowsNesting = false,
    this.allowsSelfClosing = false,
    this.openSymbol = '<',
    this.closeSymbol = '>',
  })  : assert(openSymbol != '', 'openSymbol must not be empty'),
        assert(closeSymbol != '', 'closeSymbol must not be empty');

  /// Tag names that are recognised (regular expression, must match the whole
  /// name, case-insensitive). Default `h\d*` (`<h>`, `<h1>`, `<h2>` …).
  final String namePattern;

  /// Symbol that opens a tag, default `<`. E.g. `[` for `[h]text[/h]`,
  /// `【` for `【h】text【/h】`, `{` for `{h}text{/h}`.
  final String openSymbol;

  /// Symbol that closes a tag, default `>`. E.g. `]`, `】`, `}`.
  final String closeSymbol;

  /// Whether tags may nest: `<b>bold <color value="red">red</color></b>`.
  final bool allowsNesting;

  /// Whether empty self-closing tags are recognised: `<br/>`, `<icon name="star"/>`.
  final bool allowsSelfClosing;

  /// Any tag name: a letter followed by letters, digits, `_`, `-` or `:`.
  static const String anyTagName = r'[a-z][a-z0-9_:-]*';

  /// Default: only `<h>` / `<hN>`, no nesting, no self-closing tags.
  static const ZLTagParserConfiguration hTags = ZLTagParserConfiguration();

  /// Any tag name, nesting and self-closing tags.
  static const ZLTagParserConfiguration anyTags = ZLTagParserConfiguration(
      namePattern: anyTagName, allowsNesting: true, allowsSelfClosing: true);

  ZLTagParserConfiguration copyWith(
      {String? namePattern,
      bool? allowsNesting,
      bool? allowsSelfClosing,
      String? openSymbol,
      String? closeSymbol}) {
    return ZLTagParserConfiguration(
      namePattern: namePattern ?? this.namePattern,
      allowsNesting: allowsNesting ?? this.allowsNesting,
      allowsSelfClosing: allowsSelfClosing ?? this.allowsSelfClosing,
      openSymbol: openSymbol ?? this.openSymbol,
      closeSymbol: closeSymbol ?? this.closeSymbol,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ZLTagParserConfiguration &&
      other.namePattern == namePattern &&
      other.allowsNesting == allowsNesting &&
      other.allowsSelfClosing == allowsSelfClosing &&
      other.openSymbol == openSymbol &&
      other.closeSymbol == closeSymbol;

  @override
  int get hashCode => Object.hash(
      namePattern, allowsNesting, allowsSelfClosing, openSymbol, closeSymbol);
}

/// A parsed tag.
@immutable
class ZLTagInfo {
  const ZLTagInfo({
    required this.index,
    required this.name,
    required this.text,
    required this.raw,
    this.attributes = const <String, String>{},
    this.parent,
  });

  /// Position among all tags (all names counted together, from 0, outer tags
  /// first).
  final int index;

  /// Lower-case tag name: `h`, `h1`, `b`, `a` …
  final String name;

  /// Plain text inside the tag (inner tags removed).
  final String text;

  /// The whole raw tag, e.g. `<h1>User Agreement</h1>`.
  final String raw;

  /// Attributes with lower-case names. `<a href="x" target=_blank disabled>`
  /// gives `{href: x, target: _blank, disabled: ''}`.
  final Map<String, String> attributes;

  /// The enclosing tag when nested, `null` for outermost tags.
  final ZLTagInfo? parent;

  /// Nesting depth, 0 for outermost tags.
  int get depth => parent == null ? 0 : parent!.depth + 1;

  /// The number after `h` in `<hN>`: 1 for `<h1>`, `null` for `<h>` and other
  /// names.
  int? get level =>
      name.startsWith('h') ? int.tryParse(name.substring(1)) : null;

  /// Attribute value (case-insensitive name).
  String? attribute(String name) => attributes[name.toLowerCase()];

  /// Attribute value parsed as a colour, see [colorFromString].
  Color? colorAttribute(String name) {
    final String? value = attribute(name);
    return value == null ? null : colorFromString(value);
  }

  /// Parses `#rgb`, `#rrggbb`, `#rrggbbaa` (`#` optional) and common colour
  /// names (red, green, blue, orange, yellow, purple, pink, teal, gray, black,
  /// white, clear).
  static Color? colorFromString(String string) {
    final String value = string.trim().toLowerCase();
    const Map<String, Color> named = <String, Color>{
      'red': Color(0xFFFF3B30),
      'green': Color(0xFF34C759),
      'blue': Color(0xFF007AFF),
      'orange': Color(0xFFFF9500),
      'yellow': Color(0xFFFFCC00),
      'purple': Color(0xFFAF52DE),
      'pink': Color(0xFFFF2D55),
      'teal': Color(0xFF30B0C7),
      'gray': Color(0xFF8E8E93),
      'grey': Color(0xFF8E8E93),
      'black': Color(0xFF000000),
      'white': Color(0xFFFFFFFF),
      'clear': Color(0x00000000),
    };
    final Color? color = named[value];
    if (color != null) return color;
    String hex = value.startsWith('#') ? value.substring(1) : value;
    if (hex.length == 3) hex = hex.split('').map((String c) => '$c$c').join();
    if (hex.length != 6 && hex.length != 8) return null;
    final int? number = int.tryParse(hex, radix: 16);
    if (number == null) return null;
    if (hex.length == 6) return Color(0xFF000000 | number);
    // rrggbbaa → aarrggbb
    return Color(((number & 0xFF) << 24) | (number >> 8));
  }

  @override
  String toString() {
    final String attrs = attributes.isEmpty ? '' : ', attributes: $attributes';
    final String nested =
        parent == null ? '' : ', depth: $depth, parent: ${parent!.name}';
    return 'ZLTagInfo(index: $index, name: $name, text: $text, raw: $raw$attrs$nested)';
  }
}

/// Plain text (`tag == null`) or an `<h>` tag, see [ZLTagParser.parseHTags].
@immutable
class ZLTagSegment {
  const ZLTagSegment(this.text, this.tag);

  final String text;
  final ZLTagInfo? tag;

  bool get isTag => tag != null;
}

/// Node of the parsed tag tree.
sealed class ZLTagNode {
  const ZLTagNode();
}

/// Raw text between tags.
final class ZLTagTextNode extends ZLTagNode {
  const ZLTagTextNode(this.range);

  final TextRange range;
}

/// A tag element.
final class ZLTagElementNode extends ZLTagNode {
  const ZLTagElementNode(this.element);

  final ZLTagElement element;
}

/// A tag in the parsed tree.
class ZLTagElement {
  ZLTagElement(
      {required this.name,
      required this.attributes,
      required this.openRange,
      required this.isSelfClosing});

  final String name;
  final Map<String, String> attributes;

  /// Range of the opening tag (the whole tag when self-closing).
  final TextRange openRange;

  /// Range of the closing tag, `null` when self-closing.
  TextRange? closeRange;

  final bool isSelfClosing;
  final List<ZLTagNode> children = <ZLTagNode>[];
  ZLTagElement? parent;

  /// The whole tag, from the opening to the closing tag.
  TextRange get range =>
      TextRange(start: openRange.start, end: (closeRange ?? openRange).end);

  /// The content between the opening and closing tags.
  TextRange get contentRange => closeRange == null
      ? TextRange.collapsed(openRange.end)
      : TextRange(start: openRange.end, end: closeRange!.start);

  /// Plain text inside the tag (inner tags removed).
  String plainText(String source) {
    final StringBuffer buffer = StringBuffer();
    for (final ZLTagNode child in children) {
      switch (child) {
        case ZLTagTextNode(:final TextRange range):
          buffer.write(source.substring(range.start, range.end));
        case ZLTagElementNode(:final ZLTagElement element):
          buffer.write(element.plainText(source));
      }
    }
    return buffer.toString();
  }

  /// This element and all inner elements, outer first.
  List<ZLTagElement> get allElements => <ZLTagElement>[
        this,
        for (final ZLTagNode child in children)
          if (child is ZLTagElementNode) ...child.element.allElements,
      ];
}

/// Result of one parse.
class ZLTagDocument {
  const ZLTagDocument(this.source, this.roots);

  final String source;

  /// Outermost tags, by position.
  final List<ZLTagElement> roots;
}

/// Tag parser.
///
/// * [tags]: configurable parser — any tag name, attributes, nesting,
///   self-closing tags, error tolerance.
/// * [parseHTags]: the simple `<h>` tag parser.
///
/// Error tolerance:
/// * names not matching `namePattern` are plain text (`<hx>` by default);
/// * mismatched / unclosed tags: the opening tag is shown as text, its
///   content is still handled, later tags are not affected;
/// * without nesting a new opening tag drops the outer unclosed tag;
/// * `<name/>` closes an open tag with the same name (`<h1>text<h1/>`),
///   otherwise it is an empty tag when self-closing tags are allowed, else
///   plain text.
abstract final class ZLTagParser {
  static final Map<String, RegExp> _tokenRegexCache = <String, RegExp>{};

  /// Tag token regex for the given open / close symbols. With the default
  /// `<` / `>` it is identical to:
  /// `<(/)?([a-z][a-z0-9_:-]*)((?:\s+[^\s=/>"']+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'=<>`]+))?)*)\s*(/)?>`
  static RegExp _tokenRegex(String open, String close) {
    return _tokenRegexCache.putIfAbsent('$open\u0000$close', () {
      final String o = RegExp.escape(open);
      final String c = RegExp.escape(close);
      final String closeChars = _classChars(close);
      final String allChars = _classChars('$open$close');
      return RegExp(
        '$o(/)?([a-z][a-z0-9_:-]*)'
        '((?:\\s+[^\\s=/"\'$closeChars]+'
        '(?:\\s*=\\s*(?:"[^"]*"|\'[^\']*\'|[^\\s"\'=`$allChars]+))?)*)'
        '\\s*(/)?$c',
        caseSensitive: false,
      );
    });
  }

  /// Distinct characters of [symbols], escaped for a regex character class.
  static String _classChars(String symbols) {
    final StringBuffer buffer = StringBuffer();
    final Set<int> seen = <int>{};
    for (final int unit in symbols.codeUnits) {
      if (!seen.add(unit)) continue;
      final String char = String.fromCharCode(unit);
      buffer.write(r'\^-[]'.contains(char) ? '\\$char' : char);
    }
    return buffer.toString();
  }

  static final RegExp _attributeRegex = RegExp(
      r'''([^\s=/>"']+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?''');

  static final Map<String, RegExp?> _nameRegexCache = <String, RegExp?>{};

  static RegExp? _nameRegex(String pattern) {
    return _nameRegexCache.putIfAbsent(pattern, () {
      try {
        return RegExp('^(?:$pattern)\$', caseSensitive: false);
      } on FormatException {
        return null;
      }
    });
  }

  /// All tags, outer tags first (`index` follows the order of the opening
  /// tags).
  static List<ZLTagInfo> tags(String source,
      {ZLTagParserConfiguration configuration =
          ZLTagParserConfiguration.hTags}) {
    final ZLTagDocument document = parse(source, configuration: configuration);
    final List<ZLTagInfo> result = <ZLTagInfo>[];
    final Map<ZLTagElement, ZLTagInfo> infos = <ZLTagElement, ZLTagInfo>{};
    for (final ZLTagElement root in document.roots) {
      for (final ZLTagElement element in root.allElements) {
        final ZLTagInfo info =
            makeInfo(element, source, result.length, infos[element.parent]);
        infos[element] = info;
        result.add(info);
      }
    }
    return result;
  }

  /// Builds the [ZLTagInfo] of [element].
  static ZLTagInfo makeInfo(
      ZLTagElement element, String source, int index, ZLTagInfo? parent) {
    return ZLTagInfo(
      index: index,
      name: element.name,
      text: element.plainText(source),
      raw: source.substring(element.range.start, element.range.end),
      attributes: element.attributes,
      parent: parent,
    );
  }

  /// Parses [source] into a tag tree.
  static ZLTagDocument parse(String source,
      {ZLTagParserConfiguration configuration =
          ZLTagParserConfiguration.hTags}) {
    final ZLTagElement root = ZLTagElement(
        name: '',
        attributes: const <String, String>{},
        openRange: TextRange.collapsed(0),
        isSelfClosing: false);
    final List<ZLTagElement> stack = <ZLTagElement>[root];
    int cursor = 0;
    final RegExp? names = _nameRegex(configuration.namePattern);

    // Drops an unclosed tag: its opening tag becomes text, the content moves
    // to the parent.
    void abandon(ZLTagElement element) {
      final ZLTagElement? parent = element.parent;
      if (parent == null) return;
      final int index = parent.children.lastIndexWhere((ZLTagNode node) =>
          node is ZLTagElementNode && identical(node.element, element));
      if (index < 0) return;
      for (final ZLTagNode child in element.children) {
        if (child is ZLTagElementNode) child.element.parent = parent;
      }
      parent.children.replaceRange(index, index + 1,
          <ZLTagNode>[ZLTagTextNode(element.openRange), ...element.children]);
    }

    // Index in the stack of an open tag that can be closed by `name`
    // (without nesting only the innermost tag is considered).
    int? openIndex(String name) {
      if (stack.length <= 1) return null;
      if (!configuration.allowsNesting) {
        return stack.last.name == name ? stack.length - 1 : null;
      }
      for (int i = stack.length - 1; i >= 1; i--) {
        if (stack[i].name == name) return i;
      }
      return null;
    }

    void close(int index, TextRange range) {
      for (int j = stack.length - 1; j > index; j--) {
        abandon(stack[j]);
      }
      stack[index].closeRange = range;
      stack.removeRange(index, stack.length);
    }

    void append(ZLTagNode node) => stack.last.children.add(node);

    void appendElement(ZLTagElement element) {
      if (!configuration.allowsNesting && stack.length > 1) {
        abandon(stack.removeLast());
      }
      element.parent = stack.last;
      append(ZLTagElementNode(element));
    }

    for (final RegExpMatch token
        in _tokenRegex(configuration.openSymbol, configuration.closeSymbol)
            .allMatches(source)) {
      if (token.start > cursor) {
        append(ZLTagTextNode(TextRange(start: cursor, end: token.start)));
      }
      cursor = token.end;
      final TextRange range = TextRange(start: token.start, end: token.end);

      final String name = token.group(2)!.toLowerCase();
      final bool isClosing = token.group(1) != null;
      final bool isSelfClosing = token.group(4) != null;
      final bool nameMatches = names?.hasMatch(name) ?? false;
      if (!nameMatches || (isClosing && isSelfClosing)) {
        append(ZLTagTextNode(range));
        continue;
      }

      if (isClosing) {
        final int? index = openIndex(name);
        if (index != null) {
          close(index, range);
        } else {
          append(ZLTagTextNode(range));
        }
      } else if (isSelfClosing) {
        final int? index = openIndex(name);
        if (index != null) {
          close(index, range); // <h1>text<h1/>
        } else if (configuration.allowsSelfClosing) {
          appendElement(ZLTagElement(
              name: name,
              attributes: _attributes(token.group(3)),
              openRange: range,
              isSelfClosing: true));
        } else {
          append(ZLTagTextNode(range));
        }
      } else {
        final ZLTagElement element = ZLTagElement(
            name: name,
            attributes: _attributes(token.group(3)),
            openRange: range,
            isSelfClosing: false);
        appendElement(element);
        stack.add(element);
      }
    }
    if (cursor < source.length) {
      append(ZLTagTextNode(TextRange(start: cursor, end: source.length)));
    }
    // Tags still open at the end are dropped.
    while (stack.length > 1) {
      abandon(stack.removeLast());
    }

    final List<ZLTagElement> roots = <ZLTagElement>[];
    for (final ZLTagNode node in root.children) {
      if (node is ZLTagElementNode) {
        node.element.parent = null;
        roots.add(node.element);
      }
    }
    return ZLTagDocument(source, roots);
  }

  static Map<String, String> _attributes(String? source) {
    if (source == null || source.trim().isEmpty) {
      return const <String, String>{};
    }
    final Map<String, String> result = <String, String>{};
    for (final RegExpMatch match in _attributeRegex.allMatches(source)) {
      final String key = match.group(1)!.toLowerCase();
      final String value =
          match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
      result[key] = decodeEntities(value);
    }
    return result;
  }

  /// Decodes the common entities in attribute values.
  static String decodeEntities(String value) {
    if (!value.contains('&')) return value;
    return value
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }

  // MARK: Simple <h> tags

  /// `<h>` tags: group 1 is the name, group 2 the text. The content may not
  /// contain other h tags, so mismatched tags never swallow later content.
  static final RegExp hTagRegex = RegExp(
      r'<(h\d*)>((?:(?!</?h\d*/?>)[\s\S])*?)(?:</\1>|<\1/>)',
      caseSensitive: false);

  /// Splits [source] into text and `<h>` tags (no nesting; `</h1>` and
  /// `<h1/>` both close; mismatched / unclosed tags are text).
  static List<ZLTagSegment> parseHTags(String source) {
    final List<ZLTagSegment> segments = <ZLTagSegment>[];
    int cursor = 0;
    int index = 0;
    for (final RegExpMatch match in hTagRegex.allMatches(source)) {
      if (match.start > cursor) {
        segments.add(ZLTagSegment(source.substring(cursor, match.start), null));
      }
      final ZLTagInfo info = ZLTagInfo(
        index: index++,
        name: match.group(1)!.toLowerCase(),
        text: match.group(2) ?? '',
        raw: match.group(0)!,
      );
      segments.add(ZLTagSegment(info.text, info));
      cursor = match.end;
    }
    if (cursor < source.length) {
      segments.add(ZLTagSegment(source.substring(cursor), null));
    }
    return segments;
  }

  /// Only the `<h>` tags of [parseHTags].
  static List<ZLTagInfo> hTags(String source) => parseHTags(source)
      .map((ZLTagSegment s) => s.tag)
      .whereType<ZLTagInfo>()
      .toList();
}

/// Adapts the tag parser to a [Pattern] so it can be the pattern of a
/// [ZLRichRule]: every outermost tag is a match (group 1 is the tag name,
/// group 2 the content), resolved by priority together with other rules.
class ZLTagMarkupPattern implements Pattern {
  ZLTagMarkupPattern(this.configuration);

  final ZLTagParserConfiguration configuration;
  ZLTagDocument? _cached;

  /// Parse result of [source] (cached for the last string).
  ZLTagDocument document(String source) {
    final ZLTagDocument? cached = _cached;
    if (cached != null && cached.source == source) return cached;
    return _cached = ZLTagParser.parse(source, configuration: configuration);
  }

  @override
  Iterable<Match> allMatches(String string, [int start = 0]) {
    return document(string)
        .roots
        .where((ZLTagElement e) => e.range.start >= start)
        .map((ZLTagElement element) {
      final int nameStart =
          element.openRange.start + configuration.openSymbol.length;
      final TextRange nameRange = TextRange(
          start: nameStart, end: nameStart + element.name.length);
      return ZLPatternMatch(
        input: string,
        pattern: this,
        groups: <TextRange?>[element.range, nameRange, element.contentRange],
      );
    });
  }

  @override
  Match? matchAsPrefix(String string, [int start = 0]) {
    for (final Match match in allMatches(string, start)) {
      if (match.start == start) return match;
    }
    return null;
  }
}
