// Declarative usage: the port of the iOS `SwiftUIDemoPage.swift`.
//
// On iOS the UIKit label needs the SwiftUI wrapper `ZLRichText`. Flutter
// widgets are declarative already, so `ZLTagRichLabel` is used directly:
//   1. tag styles + taps
//   2. dynamic text: the height follows the content while typing
//   3. expand / collapse kept in sync with parent state (`expanded` +
//      `onExpandChanged`)
//   4. `maxLines` driven by a stepper (SwiftUI `.lineLimit`)
//   5. rules + capsule backgrounds + gradient text
//   6. labels with different heights in a `ListView`
//
import 'package:flutter/material.dart';
import 'package:zl_rich_label/zl_rich_label.dart';

import 'demo_common.dart';

const ZLTextStyle _style =
    ZLTextStyle(textStyle: TextStyle(fontSize: 15, color: Color(0xDE000000)));

class DeclarativeDemoPage extends StatefulWidget {
  const DeclarativeDemoPage({super.key});

  @override
  State<DeclarativeDemoPage> createState() => _DeclarativeDemoPageState();
}

class _DeclarativeDemoPageState extends State<DeclarativeDemoPage> {
  final ValueNotifier<String> _event =
      ValueNotifier<String>('点击标签 / 话题，或展开文字，这里显示回调');

  void _report(String text) => _event.value = text;

  @override
  void dispose() {
    _event.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('声明式用法')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          ValueListenableBuilder<String>(
            valueListenable: _event,
            builder: (BuildContext context, String event, _) => Container(
              key: const Key('declarativeEvent'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(8)),
              child: monoText(event, fontSize: 12, color: Colors.black),
            ),
          ),
          _Section('1. 基础用法：标签样式 + 点击', child: _BasicDemo(onEvent: _report)),
          const _Section('2. 动态文字：输入时高度实时变化', child: _DynamicTextDemo()),
          _Section('3. 展开 / 收起：与父组件状态双向同步',
              child: _ExpandDemo(onEvent: _report)),
          const _Section('4. maxLines（SwiftUI 的 .lineLimit）',
              child: _LineLimitDemo()),
          _Section('5. 规则 + 胶囊背景 + 渐变文字',
              child: _DecorationDemo(onEvent: _report)),
          const _Section('6. ListView 中自适应行高', child: _ListDemo()),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// MARK: - 1. 基础用法

class _BasicDemo extends StatelessWidget {
  const _BasicDemo({required this.onEvent});

  final ValueChanged<String> onEvent;

  @override
  Widget build(BuildContext context) {
    return ZLTagRichLabel(
      text: '我已阅读并同意<h1>《用户协议》</h1>和<h2>《隐私政策》</h2>，点击标签试试。',
      style: _style,
      tagStyles: <String, ZLTextStyle>{
        'h1': ZLTextStyle().color(Colors.blue),
        'h2': ZLTextStyle().color(Colors.red),
      },
      highlightStyle: ZLTextStyle().backgroundColor(const Color(0xFFD1D1D6)),
      onTagTap: (ZLTagInfo info) =>
          onEvent('onTagTap  <${info.name}> ${info.text}'),
    );
  }
}

// MARK: - 2. 动态文字

class _DynamicTextDemo extends StatefulWidget {
  const _DynamicTextDemo();

  @override
  State<_DynamicTextDemo> createState() => _DynamicTextDemoState();
}

class _DynamicTextDemoState extends State<_DynamicTextDemo> {
  static const String _initial = '输入文字，<h1>标签</h1>会实时高亮，高度跟着内容变化。';
  final TextEditingController _input = TextEditingController(text: _initial);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _set(String text) {
    _input.text = text;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(6)),
          child: ZLTagRichLabel(
            text: _input.text,
            style: _style,
            tagStyle: ZLTextStyle().color(Colors.purple).underline(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('dynamicTextField'),
          controller: _input,
          decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              hintText: '输入带 <h1>…</h1> 的文字'),
          onChanged: (_) => setState(() {}),
        ),
        Row(
          children: <Widget>[
            TextButton(
                onPressed: () => _set('${_input.text}再加一句很长的文字，看看换行后的高度。'),
                child: const Text('追加一句')),
            const Spacer(),
            TextButton(
                onPressed: () => _set('输入文字，<h1>标签</h1>会实时高亮。'),
                child: const Text('重置')),
          ],
        ),
      ],
    );
  }
}

// MARK: - 3. 展开 / 收起

class _ExpandDemo extends StatefulWidget {
  const _ExpandDemo({required this.onEvent});

  final ValueChanged<String> onEvent;

  @override
  State<_ExpandDemo> createState() => _ExpandDemoState();
}

class _ExpandDemoState extends State<_ExpandDemo> {
  static const String _text =
      '在 Flutter 中直接使用 ZLTagRichLabel：label 内部点击「全文」展开后，'
      '通过 onExpandChanged 回调同步到父组件的状态；外部开关修改状态后，通过 expanded 参数同步回 label。'
      '无论哪一边改变，高度都会自动重新计算。<h1>标签</h1>照常可以点击。'
      '这里再多写一些文字，保证收起时一定会被截断。';

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ZLTextStyle token = ZLTextStyle().color(Colors.orange);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.topCenter,
          child: ZLTagRichLabel(
            text: _text,
            style: _style,
            maxLines: 2,
            expandToken: ZLAttributedText('… 全文', style: token),
            collapseToken: ZLAttributedText(' 收起', style: token),
            tagStyle: ZLTextStyle().color(Colors.blue),
            onTagTap: (ZLTagInfo info) =>
                widget.onEvent('onTagTap  ${info.text}'),
            // 父组件状态 → label（设置 expanded 不会触发 onExpandChanged，不会循环）
            expanded: _expanded,
            // label → 父组件状态
            onExpandChanged: (bool expanded) {
              setState(() => _expanded = expanded);
              widget.onEvent('onExpandChanged($expanded)');
            },
          ),
        ),
        SwitchRow(
          key: const Key('expandSwitch'),
          label: 'expanded（父组件状态）',
          value: _expanded,
          onChanged: (bool value) => setState(() => _expanded = value),
        ),
      ],
    );
  }
}

// MARK: - 4. maxLines

class _LineLimitDemo extends StatefulWidget {
  const _LineLimitDemo();

  @override
  State<_LineLimitDemo> createState() => _LineLimitDemoState();
}

class _LineLimitDemoState extends State<_LineLimitDemo> {
  int _limit = 2;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ZLTagRichLabel(
          text: 'maxLines 和 SwiftUI 的 .lineLimit(_:) 一样限制行数。'
              '<h1>这段文字比较长</h1>，用下面的步进器调整显示的行数，0 表示不限制。'
              '超出的部分显示省略号，高度跟着行数变化。',
          style: _style,
          tagStyle: ZLTextStyle().color(Colors.teal),
          maxLines: _limit == 0 ? null : _limit,
        ),
        Row(
          children: <Widget>[
            Expanded(
                child: Text('maxLines = ${_limit == 0 ? 'null' : '$_limit'}',
                    style: const TextStyle(fontSize: 13))),
            IconButton(
              onPressed: _limit > 0 ? () => setState(() => _limit--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              onPressed: _limit < 5 ? () => setState(() => _limit++) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ],
    );
  }
}

// MARK: - 5. 规则 + 胶囊 + 渐变

class _DecorationDemo extends StatelessWidget {
  const _DecorationDemo({required this.onEvent});

  final ValueChanged<String> onEvent;

  @override
  Widget build(BuildContext context) {
    return ZLTagRichLabel(
      text: '<grad>ZLRichLabel for Flutter</grad>\n'
          '话题 #Flutter# #Dart# 可以点击，@alice 是提及，`label.text` 是行内代码。',
      style: _style.withLineSpacing(6),
      tagConfiguration: const ZLTagParserConfiguration(namePattern: 'grad'),
      tagStyles: <String, ZLTextStyle>{
        'grad': ZLTextStyle()
            .boldFont(20)
            .gradientColors(<Color>[Colors.pink, Colors.orange, Colors.purple]),
      },
      rules: <ZLRichRule>[
        ZLRichRule.regex('topic', r'#[^#\s]+#',
            handler: (ZLRichRuleContext ctx) {
          ctx.addStyle(
              ZLTextStyle().color(Colors.purple).capsule(Colors.purple));
          ctx.highlightStyle = ZLTextStyle().withBackground(ZLTextBackground(
              fillColor: Colors.purple.withValues(alpha: 0.3)));
          ctx.onTap = (ZLRichMatch m) => onEvent('话题 ${m.text}');
        }),
        ZLRichRule.regex('mention', r'@\w+', handler: (ZLRichRuleContext ctx) {
          ctx.setText('👤${ctx.matchedText.substring(1)}',
              ZLTextStyle().color(Colors.indigo));
          ctx.onTap = (ZLRichMatch m) => onEvent('提及 ${m.text}');
        }),
        ZLRichRule.regex('code', r'`([^`]+)`',
            handler: (ZLRichRuleContext ctx) {
          ctx.setText(
              ctx.group(1)!, ZLTextStyle().monospacedFont(13).codeBackground());
        }),
      ],
    );
  }
}

// MARK: - 6. ListView

class _ListDemo extends StatelessWidget {
  const _ListDemo();

  static final List<String> _rows = <String>[
    for (int i = 1; i <= 8; i++) '<h1>第 $i 行</h1> ${'列表行内容，' * (i * 2)}每行高度不同。',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 360,
      child: ListView.separated(
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ZLTagRichLabel(
            text: _rows[index],
            style: _style,
            tagStyle: ZLTextStyle().color(Colors.green).bold(),
          ),
        ),
      ),
    );
  }
}
