import 'package:flutter/material.dart';

import 'attributed_label_demo_page.dart';
import 'declarative_demo_page.dart';
import 'tag_demo_page.dart';

void main() => runApp(const ZLRichLabelExampleApp());

class ZLRichLabelExampleApp extends StatelessWidget {
  const ZLRichLabelExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZLRichLabel Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple, brightness: Brightness.dark)),
      themeMode: ThemeMode.light,
      routes: <String, WidgetBuilder>{
        '/': (_) => const TagDemoPage(),
        '/list': (_) => const TagDemoPage(listMode: true),
        '/base': (_) => const AttributedLabelDemoPage(),
        '/declarative': (_) => const DeclarativeDemoPage(),
      },
    );
  }
}
