import 'package:flutter/material.dart';

import 'theme.dart';
import 'workbench_page.dart';

class AICoderApp extends StatelessWidget {
  const AICoderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Mobile Coder',
      theme: buildTheme(),
      home: const WorkbenchPage(),
    );
  }
}
