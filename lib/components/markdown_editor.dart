import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../services/github.dart';
import '../services/image_processing.dart';
import '../services/music.dart';
import 'dart:io';
import 'dart:math';

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
  bool _isUploadLoading = false;
  bool _isMusicLoading = false;
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

  void _insertTextToMarkdown(String text) {
    final int cursorPosition = _controller.selection.baseOffset;
    // 在当前光标位置插入数据
    _controller.replaceText(cursorPosition, 0, text,
        TextSelection.collapsed(offset: cursorPosition + text.length));
  }

  Future<void> _fetchMusicCardDataAndInsertToMarkdown(String input) async {
    if (_isMusicLoading) return;
    setState(() {
      _isMusicLoading = true;
    });
    final musicService = MusicService();
    // 检查输入内容是否包含域名
    final idPattern = RegExp(r'[?&]id=(\d+)');
    final match = idPattern.firstMatch(input);

    // 如果匹配到域名并提取出 ID
    if (match != null) {
      input = match.group(1)!; // 获取正则匹配到的第一个分组，即 ID
    }
    try {
      final cardData = await musicService.fetchMusicCardData(input);
      _insertTextToMarkdown('\n$cardData');
    } catch (error) {
      _showErrorMessage('Failed to load music card data');
    } finally {
      setState(() {
        _isMusicLoading = false;
      });
    }
  }

  Future<void> _showMusicInputDialog() async {
    final TextEditingController idController = TextEditingController();
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('网易云音乐卡片'),
            content: TextField(
              controller: idController,
              decoration: const InputDecoration(hintText: '输入ID或分享链接'),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('取消'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('确认'),
                onPressed: () {
                  final id = idController.text;
                  Navigator.of(context).pop();
                  _fetchMusicCardDataAndInsertToMarkdown(id);
                },
              ),
            ],
          );
        });
  }

  // 生成指定长度的随机字符串
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
      length,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ));
  }

  Future<void> _pickImage() async {
    if (_isUploadLoading) return;
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _isUploadLoading = true;
      });
      try {
        final githubService = GitHubService();

        final originalFile = File(image.path);
        final randomStr = _generateRandomString(12);
        final originalExtension = path.extension(originalFile.path); // 获取文件扩展名
        final originalFileName = randomStr + originalExtension; // 生成随机文件名
        await githubService.uploadImageToGitHub(
            originalFile.path, 'img/$originalFileName');

        // 转换为 WebP 并上传
        final webpFile = await imageProcessing.convertToWebP(originalFile);
        final webpExtension = path.extension(webpFile.path); // 获取文件扩展名
        final webpFileName =
            randomStr + originalExtension + webpExtension; // 生成随机文件名
        final webpImageUrl = await githubService.uploadImageToGitHub(
            webpFile.path, 'img/$webpFileName');
        // 获取上传后的图片 URL
        final imageUrl = webpImageUrl; // 选择 WebP 格式的 URL

        // 在 Markdown 编辑器中插入图片链接
        final imageMarkdown = '\n![image]($imageUrl)\n';

        // 获取当前光标位置
        final int cursorPosition = _controller.selection.baseOffset;

        // 在当前光标位置插入图片 Markdown
        _controller.replaceText(
            cursorPosition,
            0,
            imageMarkdown,
            TextSelection.collapsed(
                offset: cursorPosition + imageMarkdown.length));
      } catch (error) {
        _showErrorMessage('图片上传出错');
      } finally {
        setState(() {
          _isUploadLoading = false;
        });
      }
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
      await githubService.createGitHubIssue(
          title, markdownText, _selectedLabel);

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
            // Container(
            //   child: quill.QuillSimpleToolbar(
            //     controller: _controller,
            //     configurations: const quill.QuillSimpleToolbarConfigurations(),
            //   ),
            // ),
            // const SizedBox(height: 8.0), // 添加间距

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
                  onPressed: _isMusicLoading
                      ? null
                      : _showMusicInputDialog, // 显示输入ID的弹框
                  child: _isMusicLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('音乐'),
                ),
                ElevatedButton(
                  onPressed: _isUploadLoading ? null : _pickImage,
                  child: _isUploadLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('图片'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitMarkdown,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('提交'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
