# zl_rich_label

[![pub package](https://img.shields.io/pub/v/zl_rich_label.svg)](https://pub.dev/packages/zl_rich_label)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Rich text labels for Flutter — the Flutter version of the iOS library
[ZLRichLabel](https://github.com/FPJack/ZLRichLabel): regex rules with priorities,
`<h1>` / generic tag highlighting, inline widgets, press highlight, rich truncation
tokens with expand / collapse, capsule backgrounds, gradient text, selection & copy,
data detectors and RTL support. Pure Dart, no dependencies besides Flutter.

**zl_rich_label 是一个 Flutter 富文本 Label：用正则规则（或内置的 `<h1>…</h1>` 标签）从普通字符串里识别出关键内容，再由你决定每段内容怎么显示、点了做什么。**

一行带标记的字符串，就能渲染出带样式、图标、任意 Widget、可点击、支持按下高亮的富文本，不需要手动拼 `TextSpan`、维护 `GestureRecognizer` 或计算点击区域。

适用场景：

- **协议 / 隐私政策勾选文案**：`我已阅读并同意<h1>用户协议</h1>和<h2>隐私政策</h2>`，不同标签不同颜色、不同跳转
- **社交内容**：@提及、#话题#、链接识别与点击，链接替换为「🔗网页链接」
- **表情与模板**：`[smile]` 替换为图标，`{{name}}` 替换为变量值
- **行内控件**：文字中嵌入按钮、徽章、勾选框、计数器等任意 Widget，尺寸变化后自动重新排版
- **多语言**：阿拉伯语 / 希伯来语等 RTL 文本与双向混排
- **轻量标记**：简易 Markdown（加粗、删除线、行内代码），或 `<b>`、`<color value="#f00">`、`<a href="…">` 这类可嵌套的 HTML 风格标签

| Widget | 作用 |
| --- | --- |
| `ZLAttributedLabel` | 底层富文本 Label：显示 `ZLAttributedText`（或纯文本），内边距、垂直对齐、行数限制与富文本截断符（头 / 中 / 尾）；链接（手动添加、`linkTo` 样式、数据识别），默认 / 按下 / 失活样式，点击 / 长按回调，扩大点击热区；字号自适应；每个链接是单独的无障碍节点 |
| `ZLRichLabel` | 用**正则规则**解析文本，命中内容交给规则 handler 渲染（样式 / 替换文字 / Widget / 点击 / 按下高亮），重叠时按优先级取舍 |
| `ZLTagRichLabel` | 继承 `ZLRichLabel`，内置标签规则：默认识别 `<h>`、`<h1>`、`<h2>` …，也可以识别任意标签名、读取属性、支持嵌套；按标签名区分样式、按下高亮与点击 |

```text
"I agree to the <h1>User Agreement</h1> and <h2>Privacy Policy</h2>. cc @alice"
                 ^^^^^^^^^^^^^^^^^^^^^^^     ^^^^^^^^^^^^^^^^^^^^^^^      ^^^^^^
                 ZLTagRichLabel 内置标签      ZLTagRichLabel 内置标签       自定义规则
```

## 功能

- 正则规则：任意 `RegExp`（支持捕获组、命名捕获组），或任意 `Pattern`（例如内置的 `ZLDataDetector`）
- 规则优先级：命中范围重叠时按 `priority` → 位置 → 长度 → 规则顺序取舍
- 命中内容完全由外部决定：加样式、替换文字、插入图标 / 任意 Widget
- 行内 Widget 尺寸 / 内容变化后自动重新排版（Flutter 布局天然支持，无需手动通知）
- 点击与按下高亮：整段可点击（包括其中可点击的 Widget），可按规则 / 标签名设置不同的高亮样式
- `<h>` 标签：`<h>`、`<h1>`…`<hN>`，`</h1>` 和 `<h1/>` 两种闭合写法，不区分大小写
- 通用标签：任意标签名、属性（`<a href="…">`、`<color value="#f00">`），嵌套（内层继承外层样式、点击内层优先），自闭合（`<br/>`、`<icon name="star"/>`）
- 容错：开闭不匹配、未闭合的标签原样显示，不影响后面的标签
- `ZLTextStyle` 链式配置：`ZLTextStyle().fontSize(15).color(Colors.black87).withLineSpacing(4)`
- 胶囊背景（圆角背景 / 边框 / 内边距，适合 #话题#、`code`、徽章）与渐变文字，跨行时逐行绘制
- 多行截断（富文本截断符，可包含 Widget），单行头 / 中 / 尾截断
- 展开 / 收起：截断时末尾显示可点击的「… 全文」，展开后显示「收起」；`collapseThreshold`；外部接管点击
- 长按（整体 / 按命中 / 按标签）、双击、扩大点击热区，可按坐标查询字符、命中、矩形
- 选中复制：长按选词、拖柄调整范围，可复制展示文字或对应的原文
- 渲染缓存：改按下高亮 / 追加文字时只重新执行变化的命中
- RTL：阿拉伯语 / 希伯来语等从右到左文本自动识别方向，支持双向混排
- 跟随深色模式与系统字号（`MediaQuery.textScaler`）；字号自适应（`adjustsFontSizeToFit`）
- 无障碍：链接 / 「全文」按钮是单独的语义节点

## 安装

```yaml
dependencies:
  zl_rich_label: ^1.0.0
```

```dart
import 'package:zl_rich_label/zl_rich_label.dart';
```

要求 Dart 3.6+ / Flutter 3.27+，纯 Dart 实现，支持所有平台。

## 快速开始

### 标签高亮：ZLTagRichLabel

```dart
ZLTagRichLabel(
  text: 'I agree to the <h1>User Agreement</h1> and <h2>Privacy Policy</h2>.',
  style: ZLTextStyle().fontSize(14).color(Colors.grey),                     // 普通文本
  tagStyle: ZLTextStyle().color(Colors.blue),                                 // 所有标签
  tagStyles: {'h2': ZLTextStyle().color(Colors.red)},                         // 按标签名
  highlightStyle: ZLTextStyle().backgroundColor(const Color(0xFFE6E6E6)),    // 按下高亮
  tagTapHandlers: {
    'h1': (_) => openAgreement(),
    'h2': (_) => openPrivacy(),
  },
  onTagTap: (info) => print('${info.name} ${info.text}'),   // 没有对应 handler 的标签走这里
)
```

### 自定义规则：ZLRichLabel

```dart
ZLRichLabel(
  text: 'Hi @alice, see https://flutter.dev',
  style: ZLTextStyle().fontSize(15),
  rules: [
    // @提及
    ZLRichRule.regex('mention', r'@\w+', priority: 10, handler: (ctx) {
      ctx.addStyle(ZLTextStyle().color(Colors.purple));
      ctx.onTap = (match) => print('open ${match.text}');   // 参数是这次点击的命中
    }),
    // 链接：ZLDataDetector 也可以作为规则的 pattern，替换展示文字
    ZLRichRule(
      name: 'link',
      pattern: ZLDataDetector({ZLDataDetectorType.link}),
      priority: 10,
      handler: (ctx) {
        ctx.setText('🔗网页链接', ZLTextStyle().color(Colors.blue));
        ctx.onTap = (match) => launch((match.result as ZLDataDetectorResult).url!);
      },
    ),
  ],
)
```

### 富文本与链接：ZLAttributedLabel

```dart
ZLAttributedLabel(
  '阅读并同意《用户协议》，或访问 https://flutter.dev',
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  dataDetectorTypes: const {ZLDataDetectorType.link},      // 自动识别网址
  links: [
    ZLLabelLink(range: const TextRange(start: 5, end: 11), onTap: (_) => openAgreement()),
  ],
  onLinkTap: (link) => launch(link.url!),                  // 没有自己 onTap 的链接走这里
)
```

## 自定义规则

### 创建规则

```dart
// 正则字符串（非法时抛 FormatException）
final topic = ZLRichRule.regex('topic', r'#[^#\s]+#', priority: 5, handler: (ctx) { ... });

// 任意 Pattern：RegExp、ZLDataDetector、自定义 Pattern
final link = ZLRichRule(name: 'link', pattern: ZLDataDetector({ZLDataDetectorType.link}), handler: (ctx) { ... });

ZLRichLabel(text: text, rules: [topic, link]);
```

### ZLRichRuleContext

handler 通过 `ctx` 读取命中信息，并写入要展示的内容：

| 成员 | 说明 |
| --- | --- |
| `match` / `matchedText` / `ruleName` | 命中信息（`match.result` 为原始 `Match`，`match.range` 相对原始字符串） |
| `group(i)` / `namedGroup(name)` | 捕获组 / 命名捕获组 |
| `baseStyle` | 普通文本样式（`DefaultTextStyle` + label 的 `style`） |
| `context` | label 的 `BuildContext`，可读取 `Theme` 等（深色模式 / 字号变化时 handler 会重新执行） |
| `content` | 要展示的内容（`ZLAttributedTextBuilder`），初始为「命中文字 + baseStyle」，可任意修改；为空则不显示 |
| `addStyle(style)` | 给整段内容追加样式 |
| `setText(text, [style])` | 用新文字替换（默认带 baseStyle） |
| `setWidget(widget, [style])` / `widgetText(widget)` | 替换为行内 Widget / 生成 Widget 占位富文本，可以拼进 `content` |
| `onTap` | `(ZLRichMatch) → void`，设置后整段可点击（含其中 `tappable` 的 Widget） |
| `onLongPress` | 长按这段内容时回调（设置后不再回调 label 的 `onLongPress`） |
| `addLink(range, highlightStyle:, onTap:, onLongPress:)` | 给内容中的一段单独设置点击 / 长按 / 按下高亮；可以互相包含，重叠时后添加的优先 |
| `highlightStyle` | 按下高亮，`null` 使用 label 的 `highlightStyle`，`ZLTextStyle.none` 不高亮 |

插入图标 / 任意 Widget：

```dart
ZLRichRule.regex('emoji', r'\[(smile|heart)\]', handler: (ctx) {
  ctx.setWidget(ZLRichWidget.icon(ctx.group(1) == 'smile' ? Icons.mood : Icons.favorite, size: 17));
  ctx.addStyle(ZLTextStyle().color(Colors.orange));   // 没有指定颜色的 Icon 跟随文字颜色（含按下高亮颜色）
  ctx.onTap = (match) => print('emoji ${match.group(1)}');
});

ZLRichRule.regex('vip', r'\[vip\]', handler: (ctx) {
  ctx.setWidget(const ZLRichWidget(
    child: Badge(label: Text('VIP')),
    size: Size(30, 16),                        // 为 null 时按 Widget 自身尺寸
    alignment: PlaceholderAlignment.middle,    // 与文字的对齐方式
  ));
});
```

`ZLRichWidget` 参数：

| 参数 | 说明 |
| --- | --- |
| `child` | 要显示的 Widget，通过 `DefaultTextStyle` / `IconTheme` 继承所在位置的文字样式 |
| `size` | 固定尺寸，`null` 时按 Widget 自身尺寸（最大为可用宽度）；尺寸 / 内容变化后自动重新排版 |
| `position` | `replace`（默认）/ `before` / `after`，仅 `tagWidgetBuilder` 生效 |
| `alignment` | `PlaceholderAlignment`：`middle`（默认）/ `baseline` / `aboveBaseline` / `belowBaseline` / `top` / `bottom` |
| `tappable` | 是否把 Widget 的点击当作所在命中 / 标签的点击。Widget 自己处理交互（如勾选框）时设为 `false` |

### 优先级

多条规则的命中范围重叠时：

1. `priority` 大的优先
2. 同优先级：位置靠前的优先 → 匹配更长的优先 → 规则顺序靠前的优先（`ZLTagRichLabel` 的内置规则排在外部规则之前）
3. 被淘汰的命中**整体作废**，其中的文字按普通文本或其他规则处理，不做嵌套解析

```dart
// "Call <h1>13800138000</h1>"
ZLTagRichLabel(text: s, tagPriority: 0, rules: [phone /* priority 20 */]);   // phone 优先 → <h1> 作废，原样显示
ZLTagRichLabel(text: s, tagPriority: 100, rules: [phone]);                   // <h1> 优先 → 里面的手机号不再被处理
```

不创建 label、单独解析：

```dart
ZLRichParser.resolve(text, rules);    // List<ZLRichMatch>
ZLRichParser.segments(text, rules);   // 普通文本 + 命中，按位置排序
```

## 标签（ZLTagRichLabel）

默认只识别 `<h>` / `<hN>`：

| 写法 | 结果 |
| --- | --- |
| `<h>文字</h>`、`<h1>文字</h1>`、`<h12>文字</h12>` | 标签，`name` 为小写标签名 |
| `<h1>文字<h1/>` | 同上（另一种闭合写法） |
| `<H4>文字</H4>` | 不区分大小写，`name == 'h4'` |
| `<h1>文字</h2>`、`<h2>未闭合` | 原样显示，不影响后面的标签 |
| `<h1>a<h2>b</h2>c</h1>` | 默认不支持嵌套，只识别最内层 `<h2>b</h2>` |
| `<hx>文字</hx>` | 不是 h 标签，原样显示 |

### ZLTagInfo

| 属性 | 说明 |
| --- | --- |
| `index` | 第几个标签（从 0 开始，所有标签名统一计数，外层在前） |
| `name` | 小写标签名 |
| `level` | `h` 后的数字，`<h>` 为 `null` |
| `text` | 标签内纯文字（去掉内层标签） |
| `raw` | 完整原始标签字符串 |
| `attributes` / `attribute(name)` | 标签属性（名称小写）：`<a href="x" target=_blank disabled>` → `{href: x, target: _blank, disabled: ''}` |
| `colorAttribute(name)` | 属性值解析为颜色：`#rgb`、`#rrggbb`、`#rrggbbaa` 或 red、blue 等颜色名 |
| `parent` / `depth` | 外层标签 / 嵌套深度 |

### 样式、自定义内容、点击

```text
DefaultTextStyle → style → tagStyle → tagStyles[name] → tagStyleBuilder(info)   （后面的覆盖前面的）
```

```dart
ZLTagRichLabel(
  text: text,
  tagStyle: ZLTextStyle().color(Colors.blue),
  tagStyles: {'h1': ZLTextStyle().underline()},
  tagStyleBuilder: (info) => info.index == 0 ? ZLTextStyle().bold() : null,
  // 优先级：tagSpanBuilder > tagWidgetBuilder > 默认文字
  tagSpanBuilder: (info, style) => info.name == 'h1'
      ? ZLAttributedText.widget(ZLRichWidget.icon(Icons.description)) + ZLAttributedText('《${info.text}》', style: style)
      : null,
  tagWidgetBuilder: (info, style) => info.name == 'h3'
      ? ZLRichWidget(child: const RedDot(), size: const Size(6, 6), position: ZLRichWidgetPosition.after)
      : null,
  tagTapHandlers: {'h1': (info) => openAgreement()},   // 按标签名
  onTagTap: (info) => print(info),                      // 兜底
  onTagLongPress: (info) => copy(info.text),
  highlightStyle: ZLTextStyle().backgroundColor(Colors.black12),
  tagHighlightStyles: {'h1': ZLTextStyle().backgroundColor(Colors.yellow), 'h3': ZLTextStyle.none},
  onParsed: (tags) => print(tags),                      // 解析完成后（下一帧）回调
)
```

`tagTapHandlers` 和 `onTagTap` 都没有处理的标签不可点击。

### 通用标签（任意标签名 / 属性 / 嵌套 / 自闭合）

```dart
ZLTagRichLabel(
  text: '<b>粗体里 <color value="#2196F3">蓝色 <a href="https://github.com">链接</a></color></b><br/><icon name="star"/>',
  tagConfiguration: ZLTagParserConfiguration.anyTags,   // 或 ZLTagParserConfiguration(namePattern: 'b|i|u|color|a', allowsNesting: true)
  tagStyles: {'b': ZLTextStyle().bold(), 'a': ZLTextStyle().color(Colors.blue).underline()},
  tagStyleBuilder: (info) {
    final Color? color = info.colorAttribute('value');
    return color == null ? null : ZLTextStyle().color(color);
  },
  tagSpanBuilder: (info, style) => info.name == 'br' ? ZLAttributedText('\n', style: style) : null,
  tagWidgetBuilder: (info, style) => info.name == 'icon' ? ZLRichWidget.icon(Icons.star, color: Colors.orange) : null,
  tagTapHandlers: {'a': (info) => launch(info.attribute('href')!)},
)
```

- **样式**：内层在外层样式的基础上继续合并，所以蓝色的链接同时是粗体
- **点击 / 长按 / 按下高亮**：每个标签单独响应，点在内层范围内只触发内层
- `tagSpanBuilder` 返回非 null 时替换整个标签（包括内层标签）
- `onParsed` / `ZLTagParser.tags(…)` 按先序排列（外层在前），内层的 `parent` 指向外层

| 容错 | 结果 |
| --- | --- |
| `<b>a <i>b</b>` | `<i>` 未闭合，原样显示；`<b>` 正常 |
| `</u>`、`<b>x</i>` | 多余或不匹配的闭合标签原样显示 |
| `<br/>`（未开启自闭合） | 原样显示 |
| 属性值 | 支持双引号、单引号、无引号、无值；解码 `&quot;` `&#39;` `&lt;` `&gt;` `&amp;` |

```dart
ZLTagParser.tags(source, configuration: ZLTagParserConfiguration.anyTags);   // 单独解析
ZLTagParser.parseHTags('<h1>a</h1>');                                         // 简单的 <h> 解析
```

## ZLAttributedLabel（底层富文本 Label）

`ZLAttributedText` 是不可变的富文本（对应 iOS 的 `NSAttributedString`），由 `ZLTextRun` 组成：

```dart
final text = ZLAttributedText('颜色', style: ZLTextStyle().color(Colors.pink)) +
    ZLAttributedText('、粗体', style: ZLTextStyle().bold()) +
    ZLAttributedText.widget(ZLRichWidget.icon(Icons.star)) +
    ZLAttributedText('Apple', style: ZLTextStyle().linkTo(Uri.parse('https://apple.com')));   // 自动成为链接

ZLAttributedLabel.rich(text, onLinkTap: (link) => launch(link.url!));
ZLAttributedText.fromSpan(const TextSpan(text: '...'));   // 也可以从 Flutter 的 InlineSpan 转换
```

| 参数 | 说明 |
| --- | --- |
| `style` | 文本样式（合并在 `DefaultTextStyle` 之上） |
| `padding` | 内边距；尺寸、点击、截断、字符定位都在内边距以内 |
| `verticalAlignment` | label 比文字高时的垂直对齐：`center`（默认）/ `top` / `bottom` |
| `maxLines` / `truncationMode` / `truncationToken` | 行数限制；单行支持头 / 中 / 尾截断，多行截断最后一行尾部；截断符是富文本，可包含 Widget |
| `links` | 手动添加的链接（`ZLLabelLink`：`range`、`url`、`style` / `activeStyle` / `inactiveStyle`、`onTap` / `onLongPress`、`semanticsHint`），后添加的优先 |
| `dataDetectorTypes` | 自动识别网址 / 电话 / 邮箱 / 日期 / 地址，识别结果在 `link.result` |
| `linkStyle` / `activeLinkStyle` / `inactiveLinkStyle` | 链接默认 / 按下 / 失活（被弹窗、底部弹层覆盖时）样式 |
| `onLinkTap` / `onLinkLongPress` | 没有自己回调的链接走这里（对应 iOS 的 delegate） |
| `extendsLinkTouchArea` | 手指没有按在文字上时向四周最多 15pt 查找链接；按在普通文字上时不会命中旁边的链接 |
| `highlighted` / `highlightedTextColor` | 高亮时全部文字使用 `highlightedTextColor` |
| `adjustsFontSizeToFit` / `minimumScaleFactor` | 放不下时按同一比例缩小所有字体（单行按宽度，多行按行数与高度），不缩放行内 Widget |
| `textDirection` | 为 null 时按第一个强方向字符自动识别 RTL |

## ZLTextStyle 链式配置

`ZLTextStyle` 包装 Flutter 的 `TextStyle`，并加上 `TextStyle` 表达不了的属性：胶囊背景、渐变、基线偏移、行距、首行缩进、链接。每一步都返回新的样式：

```dart
final base = ZLTextStyle().fontSize(15).color(Colors.black87).withLineSpacing(6);
final title = base.boldFont(20).gradientColors([Colors.pink, Colors.orange]);
final badge = ZLTextStyle().boldFont(11).color(Colors.white).baseline(3)
    .withBackground(const ZLTextBackground(fillColor: Colors.deepOrange, cornerRadius: 4));
final merged = base.merge(ZLTextStyle().color(Colors.red));
final fromFlutter = const TextStyle(fontSize: 15).zl;
```

| 分类 | 方法 |
| --- | --- |
| 字体 | `font(TextStyle)`、`fontSize`、`fontWeight`、`fontFamily`、`systemFont(size, weight:)`、`boldFont`、`monospacedFont`、`bold()`、`italic()`、`fontFeatures` |
| 颜色与装饰 | `color`、`backgroundColor`、`underline(style:, color:)`、`strikethrough(style:, color:)`、`kern`、`wordSpacing`、`baseline(offset)`、`shadow(color, offset:, blur:)`、`linkTo(url)` |
| label 绘制的装饰 | `withBackground(ZLTextBackground)`、`capsule(color)`、`codeBackground()`、`withGradient(Gradient)`、`gradientColors(colors, vertical:)` |
| 段落 | `withLineSpacing`、`lineHeightMultiple`、`indent`（首行缩进）、`alignment` |
| 通用 | `merge` / `adding`、`copyWith`、`ZLTextStyle.none`（空样式 / 不高亮） |

## 胶囊背景 / 渐变文字

```dart
ZLRichRule.regex('topic', r'#[^#\s]+#', handler: (ctx) {
  ctx.addStyle(ZLTextStyle().color(Colors.purple).capsule(Colors.purple));
  ctx.highlightStyle = ZLTextStyle().withBackground(ZLTextBackground(fillColor: Colors.purple.withValues(alpha: 0.3)));
});
ZLRichRule.regex('code', r'`([^`]+)`', handler: (ctx) {
  ctx.setText(ctx.group(1)!, ZLTextStyle().monospacedFont(13).codeBackground());
});
```

`ZLTextBackground`：`fillColor`、`strokeColor` / `strokeWidth`、`cornerRadius`（小于 0 为高度的一半）、`padding`（默认左右 6、上下 1）、`margin`（默认 2）。渐变可以是任意 Flutter `Gradient`。

- 水平内边距占用排版空间（不会和相邻文字重叠），展示文字、原文、点击范围、选中都不受影响；垂直内边距只影响绘制，多行时适当设置 `withLineSpacing`
- 胶囊和渐变按行分段绘制；相邻的两个命中即使样式相同，也是两个独立的胶囊
- 渐变文字的原颜色（含下划线 / 删除线）变为透明

## 长按 / 双击 / 点击热区

```dart
ZLTagRichLabel(
  text: text,
  onLongPress: (info) => copy(info.rawText),   // info：location / characterIndex / match / matchDisplayText / rawText / displayText
  onTagLongPress: (tag) => copy(tag.text),     // 标签自己的长按
  onDoubleTap: (info) => like(),               // 设置后单击链接要等双击判定失败才触发（约 300ms）
  extendsLinkTouchArea: true,
  rules: [
    ZLRichRule.regex('mention', r'@\w+', handler: (ctx) {
      ctx.onTap = (m) => openProfile(m.text);
      ctx.onLongPress = (m) => showMenu(m.text);   // 优先于 onLongPress
    }),
  ],
)
```

## 选中复制

```dart
ZLRichLabel(
  text: text,
  rules: rules,
  selectable: true,
  onCopy: (text, isRaw) => print(isRaw ? '原文 $text' : '展示文字 $text'),
  onSelectionChanged: (range) => print(controller.selectedText),
  controller: controller,
)
```

- 长按文字选中一个词（中文按系统分词），长按在规则命中上则选中整个命中；不松手拖动扩展范围，松手后可拖动两端的拖柄
- 菜单：**复制**（展示文字）、**复制原文**、**全选**（标题可通过 `copyLabel` 等参数修改）
- 点击 label 或其它位置时取消选中；内容变化后自动取消选中
- 展示文字与原文的对应：普通文字逐字对应；规则命中只要选中一部分，就对应整个命中的原文

```text
原文      Hi [smile] @alice, hello world
展示文字  Hi  😊   👤alice, hello world
选中 "ali"   → selectedText "ali"，selectedRawText "@alice"
```

## 展开 / 收起

```dart
ZLTagRichLabel(
  text: text,
  maxLines: 3,                                                                     // 收起时的行数
  expandToken: ZLAttributedText('… 全文', style: ZLTextStyle().color(Colors.blue)),
  collapseToken: ZLAttributedText(' 收起', style: ZLTextStyle().color(Colors.blue)),
  expanded: model.isExpanded,                                                      // 可选：由外部驱动（例如列表复用）
  onExpandChanged: (expanded) => setState(() => model.isExpanded = expanded),
  collapseThreshold: 5,                                                            // 可选：超过 5 行才折叠
  onExpandTokenTap: (wantsExpand) => wantsExpand ? openDetail() : controller.toggleExpanded(),  // 可选：外部接管
  controller: controller,
)
```

- 内容不足 `maxLines` 行时不显示「全文」；展开 / 收起只重新排版，不会重新执行规则 handler
- 设置了 `onExpandTokenTap` 后点击按钮不自动切换，由外部调用 `controller.toggleExpanded()` 或修改 `expanded`

## 控制器

`ZLRichLabelController`（`ZLAttributedLabel` 用 `ZLLabelController`）对应 iOS 版 label 实例上的方法：

| API | 说明 |
| --- | --- |
| `isExpanded` / `toggleExpanded()` / `isTruncated` / `expandTokenRect` | 展开状态（直接设置不回调）、切换（回调 `onExpandChanged`）、是否截断、「全文」区域 |
| `characterIndexAt(offset)` / `rectsForRange` / `boundingRectForRange` / `linkAt` / `matchAt` / `gestureInfoAt` | 坐标查询（label 坐标系） |
| `selectedRange` / `selectedText` / `selectedRawText` / `select` / `selectAll` / `clearSelection` / `copySelection(raw:)` / `rawTextForDisplayRange` | 选中复制 |
| `segments` / `matches` / `tags` / `rawText` / `displayText` | 解析结果 |
| `rebuild()` / `setNeedsRebuild(ruleName)` / `statistics` | 渲染缓存与统计 |
| `currentFontScale` / `lineCount` | 字号自适应比例 / 总行数 |

## 性能与缓存

**渲染缓存**：每个命中的 handler 输出（内容、Widget、点击）会被缓存，规则对象、命中文字、位置都不变时直接复用：

| 操作 | 重新执行 handler 的范围 |
| --- | --- |
| `highlightStyle`、截断符、展开状态、按下 / 选中 | 不执行，全部复用 |
| 修改 `text` | 只有位置、序号或内容变化的命中（在末尾追加时前面的全部复用） |
| 新的规则对象 | 这条规则的命中（规则对象放在 State 字段中即可复用） |
| `ZLTagRichLabel` 的标签配置（`tagStyle`、builder 等） | 只有标签，自定义规则复用 |
| `controller.setNeedsRebuild(name)` | 只有这条规则 |
| `style`、`DefaultTextStyle`、深色模式、字号变化、`controller.rebuild()` | 全部 |

handler 依赖的外部数据变化而规则对象不变时，调用 `controller.rebuild()` / `setNeedsRebuild(name)`。`controller.statistics` 记录渲染次数、handler 执行次数、复用次数、排版次数与排版缓存命中。

**解析**：多条规则重叠时的取舍为 O(n log n)，上万个命中也能很快完成。

## 继承 ZLRichLabel 实现自己的规则组件

`ZLTagRichLabel` 就是这样实现的：重写 State 的 `builtInRules` 提供内置规则。

```dart
class MentionLabel extends ZLRichLabel {
  const MentionLabel({super.key, required super.text, this.onMentionTap});

  final ValueChanged<String>? onMentionTap;

  @override
  State<ZLRichLabel> createState() => _MentionLabelState();
}

class _MentionLabelState extends ZLRichLabelState<MentionLabel> {
  late final ZLRichRule _mention = ZLRichRule.regex('mention', r'@\w+', handler: (ctx) {
    ctx.addStyle(ZLTextStyle().color(Colors.blue));
    ctx.onTap = (m) => widget.onMentionTap?.call(m.text);
  });

  @override
  List<ZLRichRule> get builtInRules => [_mention];

  @override
  void didParse() {
    super.didParse();
    // 可以在这里整理 matches
  }
}
```

## 与 iOS 版的对应关系

| iOS（UIKit） | Flutter |
| --- | --- |
| `ZLAttributedLabel` / `ZLRichLabel` / `ZLTagRichLabel` | 同名 Widget |
| SwiftUI `ZLRichText` | 不需要：Flutter Widget 本身就是声明式的，直接使用 `ZLTagRichLabel` |
| `NSAttributedString` / `NSTextAttachment` / `ZLRichWidget(view:)` | `ZLAttributedText` / `ZLRichWidget.icon` / `ZLRichWidget(child:)` |
| `ZLTextStyle`（属性字典） | `ZLTextStyle`（`TextStyle` + 装饰属性），链式方法基本同名 |
| `NSRegularExpression` / `NSDataDetector` | `RegExp` / `ZLDataDetector`（基于正则） |
| `textInsets` | `padding` |
| `numberOfLines` / `lineBreakMode` | `maxLines` / `truncationMode` |
| `ctx.addAttributes` / `ctx.attributedString` / `ctx.attachmentString(for:)` | `ctx.addStyle` / `ctx.content` / `ctx.widgetText` |
| `delegate` | `onLinkTap` / `onLinkLongPress` |
| `isExpanded`、`select(range:)`、`characterIndex(at:)`、`rebuild()` 等实例方法 | `ZLRichLabelController` |
| `view.zl_setNeedsRichLabelLayout()` | 不需要：Widget 尺寸变化自动重新排版 |
| `adjustsFontForContentSizeCategory` | 默认跟随 `MediaQuery.textScaler`，不需要时传 `textScaler: TextScaler.noScaling` |
| `tintAdjustmentMode == .dimmed`（失活） | label 所在路由被弹窗 / 底部弹层覆盖时 |
| Objective-C API | 无 |

已知差异：

- `ZLTextStyle.lineSpacing` 只取 label 基础样式中的值（Flutter 按段落排版，不支持逐段行距）；`headIndent` / `tailIndent` 不支持，首行缩进支持
- `baseline(offset)` 的文字以行内 Widget 实现：可以显示、点击、绘制胶囊，选中时按整体处理
- 数据识别基于正则，覆盖常见格式，不如 `NSDataDetector` 全面

## Example

```bash
cd example
flutter run
```

| 页面 | 入口 | 内容 |
| --- | --- | --- |
| `TagDemoPage` | 首页 | `ZLTagRichLabel` / `ZLRichLabel` 全部功能，对应 iOS 首页用例 1 – 31 |
| `TagDemoPage(listMode: true)` | 右上角「ListView」 | 同样的卡片放在懒加载的 `ListView` 中 |
| `DeclarativeDemoPage` | 右上角「声明式」 | 对应 iOS 的 SwiftUI 页面：动态文字、展开状态双向同步、`maxLines`、规则 + 胶囊 + 渐变、列表自适应高度 |
| `AttributedLabelDemoPage` | 右上角「Base」 | 底层 `ZLAttributedLabel` 用例 1 – 14 |

页面顶部显示最近一次点击得到的完整信息，底部有点击历史。

## License

MIT，见 [LICENSE](LICENSE)。
