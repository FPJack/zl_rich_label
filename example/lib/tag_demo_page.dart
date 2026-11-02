import 'package:flutter/material.dart';

import 'advanced_cases.dart';
import 'demo_common.dart';
import 'rule_cases.dart';
import 'tag_cases_basic.dart';

/// Home page: all features of `ZLTagRichLabel` / `ZLRichLabel` (cases 1 – 31
/// of the iOS example). [listMode] shows the same cards in a lazily built
/// `ListView` (the "TableView" page of the iOS example).
class TagDemoPage extends StatefulWidget {
  const TagDemoPage({super.key, this.listMode = false});

  final bool listMode;

  @override
  State<TagDemoPage> createState() => _TagDemoPageState();
}

class _TagDemoPageState extends State<TagDemoPage> {
  final TapLog _log = TapLog();
  late final List<Widget> _cases = <Widget>[
    ...basicTagCases(_log),
    ...ruleCases(_log),
    ...advancedCases(_log),
    HistoryCard(log: _log),
  ];

  @override
  void dispose() {
    _log.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      appBar: AppBar(
        backgroundColor: scheme.inversePrimary,
        title: Text(widget.listMode ? 'ListView Demo' : 'ZLRichLabel Demo'),
        actions: <Widget>[
          if (!widget.listMode) ...<Widget>[
            TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/list'),
                child: const Text('ListView')),
            TextButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/declarative'),
                child: const Text('声明式')),
            TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/base'),
                child: const Text('Base')),
          ],
          IconButton(
              tooltip: '清空点击记录',
              onPressed: _log.clear,
              icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body:
      Column(
        children: <Widget>[
          TapInfoPanel(log: _log),
          const Divider(height: 1),
          Expanded(
            child: widget.listMode
                ? ListView.builder(
                    key: const Key('richDemoList'),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: _cases.length,
                    itemBuilder: (BuildContext context, int index) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: KeepAliveCard(child: _cases[index]),
                    ),
                  )
                : SingleChildScrollView(
                    key: const Key('richDemoScroll'),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final Widget card in _cases) ...<Widget>[
                          card,
                          const SizedBox(height: 12)
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
