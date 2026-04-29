import 'package:flutter/material.dart';

import 'theme.dart';
import 'workbench_page.dart';

class YuandexApp extends StatelessWidget {
  const YuandexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'yuandex',
      theme: buildTheme(),
      home: const WorkbenchPage(),
    );
  }
}
