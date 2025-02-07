import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../services/github.dart';
import '../services/music.dart';
import '../services/video.dart';
import '../services/ossService.dart';
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
  bool _isLoading = false;
  bool _isUploadLoading = false;
  bool _isMusicLoading = false;
  bool _isVideoLoading = false;
  List<String> _labels = [];
  String _selectedLabel = 'note';
  List<String> _uploadedImages = [];  // 存储上传的图片 URL

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

  Future<void> _fetchVideoCardDataAndInsertToMarkdown(String input) async {
    if (_isVideoLoading) return;
    setState(() {
      _isVideoLoading = true;
    });
    final videoService = VideoCardService();
    // 检查输入内容是否包含域名
    final bvPattern = RegExp(r'/\b(BV\w+)\b'); // 捕获以 BV 开头的 ID
    final match = bvPattern.firstMatch(input);

    // 如果匹配到域名并提取出 ID
    if (match != null) {
      input = match.group(1)!; // 获取正则匹配到的第一个分组，即 ID
    }
    try {
      print(input);
      final cardData = await videoService.fetchVideoCardData(input);
      _insertTextToMarkdown('\n$cardData');
    } catch (error) {
      _showErrorMessage('Failed to load video card data');
    } finally {
      setState(() {
        _isVideoLoading = false;
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

  Future<void> _showVideoInputDialog() async {
    final TextEditingController idController = TextEditingController();
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('b站视频卡片'),
            content: TextField(
              controller: idController,
              decoration: const InputDecoration(hintText: '输入BVID'),
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
                  _fetchVideoCardDataAndInsertToMarkdown(id);
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

  Future<void> _pickImages() async {
    if (_isUploadLoading) return;

    // Select multiple images
    final List<XFile>? images = await _picker.pickMultiImage();

    if (images != null && images.isNotEmpty) {
      setState(() {
        _isUploadLoading = true;
      });

      final ossService = OssService();

      for (final image in images) {
        try {
          final originalFile = File(image.path);
          final randomStr = _generateRandomString(12);
          final originalExtension = path.extension(originalFile.path);
          final originalFileName = randomStr + originalExtension;

          // Upload original image
          await ossService.uploadFileToS3(
              originalFile.path, 'img/$originalFileName');


          final imageUrl = 'https://bitiful.leoon.cn/img/${originalFileName}'; // Choose WebP format URL

          // Insert image link into Markdown
          final imageMarkdown = '\n![image]($imageUrl)\n';
          final int cursorPosition = _controller.selection.baseOffset;
          _controller.replaceText(
              cursorPosition,
              0,
              imageMarkdown,
              TextSelection.collapsed(
                  offset: cursorPosition + imageMarkdown.length));
          // 将图片 URL 添加到数组中
          setState(() {
            _uploadedImages.add('${imageUrl}?fmt=webp&q=20&w=100');
          });
        } catch (error) {
          _showErrorMessage('图片上传出错');
        }
      }
      setState(() {
        _isUploadLoading = false;
      });
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
      setState(() {
        _uploadedImages.clear(); // 清空已上传的图片列表
      });
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
                  onPressed: _isVideoLoading
                      ? null
                      : _showVideoInputDialog, // 显示输入ID的弹框
                  child: _isVideoLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('视频'),
                ),
                ElevatedButton(
                  onPressed: _isMusicLoading
                      ? null
                      : _showMusicInputDialog, // 显示输入ID的弹框
                  child: _isMusicLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('音乐'),
                ),
                ElevatedButton(
                  onPressed: _isUploadLoading ? null : _pickImages,
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
            // 展示已上传的图片
            if (_uploadedImages.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '已上传的图片：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0, // 图片间的水平间距
                    runSpacing: 8.0, // 图片行间的垂直间距
                    children: _uploadedImages.map((imageUrl) {
                      return SizedBox(
                        width: MediaQuery.of(context).size.width / 3 - 16, // 每行 3 个图片
                        child: Image.network(imageUrl, fit: BoxFit.cover), // 图片适应容器大小
                      );
                    }).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
