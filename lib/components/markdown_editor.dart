import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../services/github.dart';
import '../services/image_processing.dart';
import 'dart:io';

class MarkdownEditor extends StatefulWidget {
  @override
  _MarkdownEditorState createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  final quill.QuillController _controller = quill.QuillController.basic();
  final ImagePicker _picker = ImagePicker();
  final imageProcessing = ImageProcessing();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      final githubService = GitHubService();

      final originalFile = File(image.path);
      final originalFileName = path.basename(originalFile.path);
      await githubService.uploadImageToGitHub(
          originalFile.path, 'img/$originalFileName');

      // 转换为 WebP 并上传
      final webpFile = await imageProcessing.convertToWebP(originalFile);
      final webpFileName = path.basename(webpFile.path);
      await githubService.uploadImageToGitHub(
          webpFile.path, 'img/$webpFileName');
    }
  }

  Future<void> _submitMarkdown() async {
    final markdownText = _controller.document.toPlainText();
    final githubService = GitHubService();

    await githubService.createGitHubIssue(
        'My GitHub Issue Title', markdownText);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: quill.QuillEditor.basic(controller: _controller),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: _pickImage,
              child: Text('Upload Image'),
            ),
            ElevatedButton(
              onPressed: _submitMarkdown,
              child: Text('Submit to GitHub'),
            ),
          ],
        ),
      ],
    );
  }
}
