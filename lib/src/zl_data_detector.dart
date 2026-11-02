import 'dart:ui' show TextRange;

import 'zl_rule.dart';

/// Kinds of content recognised by [ZLDataDetector].
enum ZLDataDetectorType {
  /// `https://…`, `www.…`, bare domains with a path.
  link,

  /// Phone numbers such as `010-12345678`, `+86 138 0013 8000`, `(408) 555-0100`.
  phoneNumber,

  /// E-mail addresses.
  email,

  /// Dates such as `2026-10-01`, `2026/10/1`, `2026年10月1日 下午3点`, `Oct 1, 2026`.
  date,

  /// Simple street addresses: `1 Infinite Loop, Cupertino, CA 95014`, `北京市海淀区…路…号`.
  address,
}

/// One result of [ZLDataDetector].
class ZLDataDetectorResult implements ZLNamedGroupMatch {
  ZLDataDetectorResult(
      {required this.type,
      required this.input,
      required this.start,
      required this.end,
      this.pattern = const _NoPattern()});

  final ZLDataDetectorType type;

  @override
  final String input;

  @override
  final int start;

  @override
  final int end;

  @override
  final Pattern pattern;

  /// The matched text.
  String get text => input.substring(start, end);

  TextRange get range => TextRange(start: start, end: end);

  /// The URL of links (`https://` is added when missing) and e-mails (`mailto:`).
  Uri? get url {
    switch (type) {
      case ZLDataDetectorType.link:
        final String value = text;
        return Uri.tryParse(
            RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false)
                    .hasMatch(value)
                ? value
                : 'https://$value');
      case ZLDataDetectorType.email:
        return Uri.tryParse('mailto:$text');
      case ZLDataDetectorType.phoneNumber:
        return Uri.tryParse('tel:$phoneNumber');
      case ZLDataDetectorType.date:
      case ZLDataDetectorType.address:
        return null;
    }
  }

  /// Digits (and a leading `+`) of a phone number.
  String? get phoneNumber => type == ZLDataDetectorType.phoneNumber
      ? text.replaceAll(RegExp(r'[^\d+]'), '')
      : null;

  /// The parsed date of date results (time of day when given).
  DateTime? get date =>
      type == ZLDataDetectorType.date ? ZLDataDetector.parseDate(text) : null;

  @override
  int get groupCount => 0;

  @override
  String? group(int group) => group == 0 ? text : null;

  @override
  String? operator [](int group) => this.group(group);

  @override
  List<String?> groups(List<int> groupIndices) =>
      groupIndices.map(group).toList();

  @override
  String? namedGroup(String name) => name == 'type' ? type.name : null;

  @override
  String toString() =>
      'ZLDataDetectorResult(${type.name}, "$text", $start-$end)';
}

class _NoPattern implements Pattern {
  const _NoPattern();

  @override
  Iterable<Match> allMatches(String string, [int start = 0]) => const <Match>[];

  @override
  Match? matchAsPrefix(String string, [int start = 0]) => null;
}

/// Regular-expression based data detector (the Flutter counterpart of
/// `NSDataDetector`). It is a [Pattern], so it can be used as the pattern of
/// a [ZLRichRule]:
///
/// ```dart
/// ZLRichRule(name: 'link', pattern: ZLDataDetector({ZLDataDetectorType.link}), handler: (ctx) {
///   ctx.setText('🔗网页链接', ZLTextStyle().color(Colors.blue));
///   ctx.onTap = (match) => launch((match.result as ZLDataDetectorResult).url);
/// })
/// ```
class ZLDataDetector implements Pattern {
  ZLDataDetector(Set<ZLDataDetectorType> types)
      : types = Set<ZLDataDetectorType>.unmodifiable(types);

  final Set<ZLDataDetectorType> types;

  static final RegExp _link = RegExp(
    r'''(?:(?:https?|ftp)://|www\.)[^\s<>"'，。；、）】」』]+|\b(?:[a-z0-9-]+\.)+(?:com|net|org|cn|io|dev|app|edu|gov|co)(?:/[^\s<>"'，。；、）】」』]*)?''',
    caseSensitive: false,
  );
  static final RegExp _email =
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b');
  static final RegExp _phone = RegExp(
    r'(?<![\w/])(?:\+?\d{1,3}[\s-]?)?(?:\(\d{2,4}\)[\s-]?|\d{2,4}[\s-])?\d{3,4}[\s-]?\d{4}(?![\w/])|(?<!\d)1[3-9]\d{9}(?!\d)',
  );
  static final RegExp _date = RegExp(
    r'\d{4}年\d{1,2}月\d{1,2}[日号](?:\s*(?:上午|下午|晚上|中午)?\s*\d{1,2}(?:[点时:：]\d{0,2}分?)?)?'
    r'|\b\d{4}[-/.]\d{1,2}[-/.]\d{1,2}(?:[ T]\d{1,2}:\d{2}(?::\d{2})?)?\b'
    r'|\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}\b',
    caseSensitive: false,
  );
  static final RegExp _address = RegExp(
    r'\b\d{1,6}\s+(?:[A-Z][A-Za-z]*\s+){1,4}(?:St|Street|Rd|Road|Ave|Avenue|Blvd|Boulevard|Loop|Way|Dr|Drive|Ln|Lane|Ct|Court|Pkwy|Parkway)\.?'
    r'(?:,\s*[A-Z][A-Za-z]*(?:\s+[A-Z][A-Za-z]*)*)?(?:,\s*[A-Z]{2})?(?:\s+\d{5}(?:-\d{4})?)?'
    r'|[一-龥]{2,}(?:省|市)[一-龥]{1,}(?:区|县|市)[一-龥\d]{1,}(?:路|街|道|巷)[\d]+号',
  );

  /// All results, sorted by position, without overlaps (earlier / longer
  /// results win).
  List<ZLDataDetectorResult> detect(String string) {
    final List<ZLDataDetectorResult> all = <ZLDataDetectorResult>[];
    void collect(ZLDataDetectorType type, RegExp regex) {
      if (!types.contains(type)) return;
      for (final RegExpMatch m in regex.allMatches(string)) {
        int end = m.end;
        // Trailing punctuation does not belong to links.
        if (type == ZLDataDetectorType.link) {
          while (end > m.start && '.,;:!?)'.contains(string[end - 1])) {
            end--;
          }
        }
        if (end > m.start) {
          all.add(ZLDataDetectorResult(
              type: type,
              input: string,
              start: m.start,
              end: end,
              pattern: this));
        }
      }
    }

    // Order matters for equal positions: e-mail before link, date before phone.
    collect(ZLDataDetectorType.email, _email);
    collect(ZLDataDetectorType.link, _link);
    collect(ZLDataDetectorType.date, _date);
    collect(ZLDataDetectorType.address, _address);
    collect(ZLDataDetectorType.phoneNumber, _phone);

    all.sort((ZLDataDetectorResult a, ZLDataDetectorResult b) {
      if (a.start != b.start) return a.start.compareTo(b.start);
      return (b.end - b.start).compareTo(a.end - a.start);
    });
    final List<ZLDataDetectorResult> result = <ZLDataDetectorResult>[];
    for (final ZLDataDetectorResult r in all) {
      if (result.isNotEmpty && result.last.end > r.start) continue;
      result.add(r);
    }
    return result;
  }

  @override
  Iterable<Match> allMatches(String string, [int start = 0]) =>
      detect(string).where((ZLDataDetectorResult r) => r.start >= start);

  @override
  Match? matchAsPrefix(String string, [int start = 0]) {
    for (final Match match in allMatches(string, start)) {
      if (match.start == start) return match;
    }
    return null;
  }

  /// Parses the date formats recognised by the detector.
  static DateTime? parseDate(String text) {
    final RegExpMatch? cn = RegExp(
            r'(\d{4})年(\d{1,2})月(\d{1,2})[日号]\s*(上午|下午|晚上|中午)?\s*(\d{1,2})?(?:[点时:：](\d{1,2})?)?')
        .firstMatch(text);
    if (cn != null) {
      int hour = int.tryParse(cn.group(5) ?? '') ?? 0;
      final String? period = cn.group(4);
      if ((period == '下午' || period == '晚上') && hour < 12) hour += 12;
      return DateTime(int.parse(cn.group(1)!), int.parse(cn.group(2)!),
          int.parse(cn.group(3)!), hour, int.tryParse(cn.group(6) ?? '') ?? 0);
    }
    final RegExpMatch? iso =
        RegExp(r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?')
            .firstMatch(text);
    if (iso != null) {
      return DateTime(
          int.parse(iso.group(1)!),
          int.parse(iso.group(2)!),
          int.parse(iso.group(3)!),
          int.tryParse(iso.group(4) ?? '') ?? 0,
          int.tryParse(iso.group(5) ?? '') ?? 0);
    }
    final RegExpMatch? en = RegExp(
            r'([a-z]{3})[a-z]*\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})',
            caseSensitive: false)
        .firstMatch(text);
    if (en != null) {
      const List<String> months = <String>[
        'jan',
        'feb',
        'mar',
        'apr',
        'may',
        'jun',
        'jul',
        'aug',
        'sep',
        'oct',
        'nov',
        'dec'
      ];
      final int month = months.indexOf(en.group(1)!.toLowerCase()) + 1;
      if (month > 0) {
        return DateTime(
            int.parse(en.group(3)!), month, int.parse(en.group(2)!));
      }
    }
    return null;
  }
}
