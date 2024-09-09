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
  final TextEditingController _titleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final imageProcessing = ImageProcessing();
  bool _isLoading = false;
  List<String> _labels = [];
  String _selectedLabel = 'note';

  void initState() {
    super.initState();
    _fetchLabels();
  }

  Future<void> _fetchLabels() async {
    final githubService = GitHubService();
    try {
      final labels = await githubService.fetchGitHubLabels();
      setState(() {
        _labels = labels;
      });
    } catch (error) {
      _showErrorMessage('Failed to load labels');
    }
  }


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
    // 如果正在加载，直接返回，避免重复提交
    if (_isLoading) return;
    final markdownText = _controller.document.toPlainText();
    final githubService = GitHubService();
    final title = _titleController.text;

    try {
      // 在这里执行提交到 GitHub 的逻辑
      await githubService.createGitHubIssue(title, markdownText, _selectedLabel);

      // 提交成功后
      _showSuccessMessage();
      _controller.clear(); // 清空编辑器内容
      _titleController.clear();
    } catch (error) {
      // 处理错误
      _showErrorMessage('提交失败，请重试');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

  }


  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('提交成功!')),
    );
  }

  void _showErrorMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            // 标题输入框
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8.0), // 添加间距

            // 工具栏
            Container(
              child: quill.QuillSimpleToolbar(
                controller: _controller,
                configurations: const quill.QuillSimpleToolbarConfigurations(),
              ),
            ),
            const SizedBox(height: 8.0), // 添加间距

            // 编辑器
            Container(
              height: 300.0, // 调整编辑器高度
              padding: const EdgeInsets.all(12.0), // 设置 padding
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey), // 设置边框颜色
                borderRadius: BorderRadius.circular(8.0), // 设置圆角边框
              ),
              child: quill.QuillEditor.basic(controller: _controller),
            ),
            const SizedBox(height: 8.0), // 添加间距

            // 标签选择器
            DropdownButton<String>(
              value: _selectedLabel,
              items: _labels.map((label) {
                return DropdownMenuItem(
                  value: label,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedLabel = value as String;
                });
              },
              hint: const Text('Select a label'),
            ),
            const SizedBox(height: 8.0), // 添加间距

            // 按钮行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _pickImage,
                  child: const Text('Upload Image'),
                ),
                ElevatedButton(
                  onPressed: _submitMarkdown,
                  child: const Text('Submit to GitHub'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
