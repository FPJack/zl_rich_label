/// Rich text labels for Flutter: regex rules with priorities, `<h1>` and
/// generic tag highlighting, inline widgets, press highlights, custom
/// truncation tokens with expand / collapse, capsule backgrounds, gradient
/// text, selection and copy, data detectors and RTL support.
///
/// * [ZLAttributedLabel]: low-level label for [ZLAttributedText] with links.
/// * [ZLRichLabel]: rule based label.
/// * [ZLTagRichLabel]: tag highlighting label on top of [ZLRichLabel].
library;

export 'src/zl_attributed_label.dart';
export 'src/zl_attributed_text.dart';
export 'src/zl_bracket_label.dart';
export 'src/zl_data_detector.dart';
export 'src/zl_label_core.dart'
    show ZLLabelController, ZLLabelGestureDetails, ZLLabelLink;
export 'src/zl_rich_label.dart';
export 'src/zl_rule.dart';
export 'src/zl_statistics.dart';
export 'src/zl_tag_parser.dart'
    show
        ZLTagInfo,
        ZLTagParser,
        ZLTagParserConfiguration,
        ZLTagSegment,
        ZLTagMarkupPattern,
        ZLTagDocument,
        ZLTagElement,
        ZLTagNode,
        ZLTagTextNode,
        ZLTagElementNode;
export 'src/zl_tag_rich_label.dart';
export 'src/zl_text_layout.dart'
    show
        ZLTruncationMode,
        ZLVerticalAlignment,
        ZLTextLayout,
        RenderZLText,
        ZLTextHit,
        ZLSemanticsLink;
export 'src/zl_text_style.dart';
