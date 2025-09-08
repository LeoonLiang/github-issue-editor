import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:thumbhash/thumbhash.dart' as Thumbhash;
import 'dart:ui' as ui;
import '../services/github.dart';
import '../services/music.dart';
import '../services/video.dart';
import '../services/ossService.dart';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:motion_photos/motion_photos.dart';
import 'package:path_provider/path_provider.dart';

class MarkdownEditor extends StatefulWidget {
  @override
  _MarkdownEditorState createState() => _MarkdownEditorState();
}

class _UploadResult {
  final String imageUrl;
  final String videoUrl;
  final int width;
  final int height;
  final String thumbhash;
  _UploadResult(
    this.imageUrl,
    this.videoUrl,
    this.width,
    this.height,
    this.thumbhash,
  );
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  final quill.QuillController _controller = quill.QuillController.basic();
  final TextEditingController _titleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  late MotionPhotos motionPhotos;
  bool _isLoading = false;
  bool _isUploadLoading = false;
  bool _isMusicLoading = false;
  bool _isVideoLoading = false;
  List<String> _labels = [];
  String _selectedLabel = 'note';
  List<String> _uploadedImages = []; // 存储上传的图片 URL

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

  Future<File?> extractStillImage(String originalPath, VideoIndex videoIndex,
      {String? outputFileName}) async {
    try {
      // 读取原始文件的所有字节
      File originalFile = File(originalPath);
      Uint8List originalBytes = await originalFile.readAsBytes();

      // 截取 JPEG 部分（去掉视频数据）
      int imageDataLength = videoIndex!.start; // Motion Photo 视频索引起始位置
      Uint8List imageBytes = originalBytes.sublist(0, imageDataLength);

      // 生成新图片文件路径
      Directory tempDir = await getTemporaryDirectory();
      String safeFileName = outputFileName ?? 'extracted_image.jpg';
      String newImagePath = path.join(tempDir.path, safeFileName);

      // 保存 JPEG 数据到新文件
      File newImageFile = File(newImagePath);
      await newImageFile.writeAsBytes(imageBytes);
      // **获取文件大小**
      int imageSize = await newImageFile.length(); // 以字节 (bytes) 计算
      double imageSizeKB = imageSize / 1024; // 转换为 KB
      double imageSizeMB = imageSizeKB / 1024; // 转换为 MB
      print('图片大小: ${imageSizeMB.toStringAsFixed(2)}MB');
      return newImageFile;
    } catch (e) {
      print('Error extracting still image: $e');
      return null;
    }
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

    final List<XFile>? images = await _picker.pickMultiImage();
    if (images == null || images.isEmpty) return;

    setState(() => _isUploadLoading = true);

    final ossService = OssService();
    final List<_UploadResult?> results = List.filled(images.length, null);

    await Future.wait(
      List.generate(images.length, (i) async {
        final image = images[i];
        try {
          final result = await _processImageAndReturnUrls(image, ossService);
          results[i] = result;
        } catch (e, stackTrace) {
          // 异常 e 和堆栈信息 stackTrace 都打印出来
          _showErrorMessage('第 ${i + 1} 张图片上传失败');
          print('第 ${i + 1} 张图片上传异常: $e');
          print(stackTrace);
        }
      }),
    );

    // 插入 markdown，保持顺序
    for (final result in results) {
      if (result != null) {
        _insertImageMarkdown(result);
        _addUploadedImage(result.imageUrl);
      }
    }

    setState(() => _isUploadLoading = false);
  }

  Future<_UploadResult> _processImageAndReturnUrls(
      XFile image, OssService ossService) async {
    final motionPhotos = MotionPhotos(image.path);
    final bool isMotionPhoto = await motionPhotos.isMotionPhoto();

    String imageUrl = '', videoUrl = '';
    final randomStr = _generateRandomString(12);
    File? finalImageFile;

    if (isMotionPhoto) {
      VideoIndex? videoIndex = await motionPhotos.getMotionVideoIndex();
      File? motionImageFile = await extractStillImage(
        image.path,
        videoIndex!,
        outputFileName: 'motion_image_$randomStr.jpg',
      );
      final tempDir = await getTemporaryDirectory();
      final motionVideoFile = await motionPhotos.getMotionVideoFile(
        tempDir,
        fileName: 'motion_video_$randomStr.mp4',
      );

      if (motionImageFile != null) {
        await ossService.uploadFileToS3(
            motionImageFile.path, 'img/$randomStr.jpg');
        imageUrl = 'https://bitiful.leoon.cn/img/$randomStr.jpg';
        finalImageFile = motionImageFile;
      }

      await ossService.uploadFileToS3(
          motionVideoFile.path, 'video/$randomStr.mp4');
      videoUrl = 'https://bitiful.leoon.cn/video/$randomStr.mp4';
    } else {
      final originalFile = File(image.path);
      final originalExtension = path.extension(originalFile.path);
      final originalFileName = '$randomStr$originalExtension';

      await ossService.uploadFileToS3(
          originalFile.path, 'img/$originalFileName');
      imageUrl = 'https://bitiful.leoon.cn/img/$originalFileName';
      finalImageFile = originalFile;
    }

    int width = 0, height = 0;
    String thumbhash = '';

    if (finalImageFile != null) {
      final bytes = await finalImageFile.readAsBytes();

      // 用 Flutter 自带的 decode API 拿宽高
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 100,
        targetHeight: 100,
      );
      final frame = await codec.getNextFrame();
      final ui.Image img = frame.image;
      width = img.width;
      height = img.height;

      // RGBA 数据
      final byteData = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData != null) {
        final rgbaBytes = byteData.buffer.asUint8List();
        final thumbhashBytes =
            Thumbhash.rgbaToThumbHash(width, height, rgbaBytes);
        thumbhash = base64.encode(thumbhashBytes);
      }
    }

    return _UploadResult(imageUrl, videoUrl, width, height, thumbhash);
  }

  void _insertImageMarkdown(_UploadResult result) {
    final imageMarkdown = result.videoUrl.isNotEmpty
        ? '\n![image](${result.imageUrl}){liveVideo="${result.videoUrl}" width=${result.width} height=${result.height} thumbhash=${result.thumbhash}}\n'
        : '\n![image](${result.imageUrl}){width=${result.width} height=${result.height} thumbhash="${result.thumbhash}"}\n';

    final int cursorPosition = _controller.selection.baseOffset;
    _controller.replaceText(
      cursorPosition,
      0,
      imageMarkdown,
      TextSelection.collapsed(offset: cursorPosition + imageMarkdown.length),
    );
  }

  void _addUploadedImage(String imageUrl) {
    setState(() {
      _uploadedImages.add('$imageUrl?fmt=webp&q=20&w=100');
    });
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
                        width: MediaQuery.of(context).size.width / 3 -
                            16, // 每行 3 个图片
                        child: Image.network(imageUrl,
                            fit: BoxFit.cover), // 图片适应容器大小
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
