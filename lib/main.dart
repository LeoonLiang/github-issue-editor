import 'package:flutter/material.dart';
import 'components/markdown_editor.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Markdown Editor',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(title: Text('Markdown Editor')),
        body: MarkdownEditor(),
      ),
    );
  }
}
