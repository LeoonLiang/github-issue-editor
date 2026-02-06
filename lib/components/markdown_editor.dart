import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:thumbhash/thumbhash.dart' as Thumbhash;
import 'package:motion_photos/motion_photos.dart';
import 'package:path_provider/path_provider.dart';
import 'package:reorderables/reorderables.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import '../services/github.dart';
import '../services/music.dart';
import '../services/video.dart';
import '../services/ossService.dart';
import '../providers/config_provider.dart';
import '../providers/github_provider.dart';

class MarkdownEditor extends ConsumerStatefulWidget {
  @override
  ConsumerState<MarkdownEditor> createState() => _MarkdownEditorState();
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

class _MarkdownEditorState extends ConsumerState<MarkdownEditor> {
  final quill.QuillController _controller = quill.QuillController.basic();
  final TextEditingController _titleController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  late MotionPhotos motionPhotos;
  bool _isLoading = false;
  bool _isUploadLoading = false;
  bool _isMusicLoading = false;
  bool _isVideoLoading = false;
  bool _useGrid = true; // 是否使用九宫格
  List<String> _labels = [];
  String _selectedLabel = '';
  List<String> _uploadedImages = []; // 存储上传的图片 URL
  List<_UploadResult> _uploadedImageResults = []; // 上传结果顺序列表

  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_labels.isEmpty) {
      _fetchLabels();
    }
  }

  Future<void> _fetchLabels() async {
    final githubService = ref.read(githubServiceProvider);
    if (githubService == null) {
      _showErrorMessage('请先配置 GitHub');
      return;
    }

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

    // 获取启用的 OSS 配置
    final enabledOssList = ref.read(configProvider).enabledOSSList;

    if (enabledOssList.isEmpty) {
      _showErrorMessage('请先在设置中配置并启用 OSS');
      return;
    }

    setState(() => _isUploadLoading = true);

    final ossService = OssService();
    final List<_UploadResult?> results = List.filled(images.length, null);

    await Future.wait(
      List.generate(images.length, (i) async {
        final image = images[i];
        try {
          final result = await _processImageAndReturnUrls(image, ossService, enabledOssList);
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
        _addUploadedImageResult(result);
      }
    }

    setState(() => _isUploadLoading = false);
  }

  Future<_UploadResult> _processImageAndReturnUrls(
      XFile image, OssService ossService, List enabledOssList) async {
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
        final imageUrls = await ossService.uploadFileToS3(
          motionImageFile.path,
          'img/$randomStr.jpg',
          enabledOssList,
        );
        imageUrl = imageUrls.values.first;
        finalImageFile = motionImageFile;
      }

      final videoUrls = await ossService.uploadFileToS3(
        motionVideoFile.path,
        'video/$randomStr.mp4',
        enabledOssList,
        fileType: 'video/mp4',
      );
      videoUrl = videoUrls.values.first;
    } else {
      final originalFile = File(image.path);
      final originalExtension = path.extension(originalFile.path);
      final originalFileName = '$randomStr$originalExtension';

      final imageUrls = await ossService.uploadFileToS3(
        originalFile.path,
        'img/$originalFileName',
        enabledOssList,
      );
      imageUrl = imageUrls.values.first;
      finalImageFile = originalFile;
    }

    int width = 0, height = 0;
    String thumbhash = '';

    if (finalImageFile != null) {
      final bytes = await finalImageFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage != null) {
        width = decodedImage.width;
        height = decodedImage.height;
        // 生成缩略图用于 ThumbHash（最大 100x100，等比缩放）
        final thumbWidth = width > height ? 100 : (100 * width ~/ height);
        final thumbHeight = height > width ? 100 : (100 * height ~/ width);
        final thumbnail = img.copyResize(
          decodedImage,
          width: thumbWidth,
          height: thumbHeight,
        );

        // RGBA 数据
        final rgbaBytes =
            Uint8List.fromList(thumbnail.getBytes(format: img.Format.rgba));

        final thumbhashBytes = Thumbhash.rgbaToThumbHash(
          thumbnail.width,
          thumbnail.height,
          rgbaBytes,
        );

        thumbhash = base64.encode(thumbhashBytes);
      }
    }
    return _UploadResult(imageUrl, videoUrl, width, height, thumbhash);
  }

  void _insertImageMarkdown(_UploadResult result) {
    final imageMarkdown = result.videoUrl.isNotEmpty
        ? '\n![image](${result.imageUrl}){liveVideo="${result.videoUrl}" width=${result.width} height=${result.height} thumbhash="${result.thumbhash}"}\n'
        : '\n![image](${result.imageUrl}){width=${result.width} height=${result.height} thumbhash="${result.thumbhash}"}\n';

    final int cursorPosition = _controller.selection.baseOffset;
    _controller.replaceText(
      cursorPosition,
      0,
      imageMarkdown,
      TextSelection.collapsed(offset: cursorPosition + imageMarkdown.length),
    );
  }

  void _addUploadedImageResult(_UploadResult result) {
    setState(() {
      _uploadedImageResults.add(result); // 顺序用
      _uploadedImages.add('${result.imageUrl}?fmt=webp&q=20&w=100'); // 显示用
    });
  }

  Future<void> _submitMarkdown() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final githubService = ref.read(githubServiceProvider);
    if (githubService == null) {
      _showErrorMessage('请先配置 GitHub');
      setState(() => _isLoading = false);
      return;
    }

    final title = _titleController.text;

    // 原编辑器内容
    String markdownText = _controller.document.toPlainText();

    if (_useGrid && _uploadedImageResults.isNotEmpty) {
      // 1️⃣ 清掉原 Markdown 中的图片 Markdown
      // 这里匹配 Markdown 图片语法 ![xxx](url) 或带 {} 的情况
      final imageRegex = RegExp(r'!\[.*?\]\(.*?\)(\{.*?\})?');
      markdownText = markdownText.replaceAll(imageRegex, '');

      // 2️⃣ 在末尾追加九宫格图片
      final gridMarkdown = _uploadedImageResults.map((img) {
        return img.videoUrl.isNotEmpty
            ? '\n![image](${img.imageUrl}){liveVideo="${img.videoUrl}" width=${img.width} height=${img.height} thumbhash="${img.thumbhash}"}\n'
            : '\n![image](${img.imageUrl}){width=${img.width} height=${img.height} thumbhash=${img.thumbhash}}\n';
      }).join();

      markdownText = markdownText.trim() + '\n' + gridMarkdown;
    }

    try {
      print('提交的 Markdown:\n$markdownText');
      await githubService.createGitHubIssue(
          title, markdownText, _selectedLabel);
      _showSuccessMessage();

      // 重置状态
      _controller.clear();
      _titleController.clear();
      setState(() {
        _uploadedImages.clear();
        _uploadedImageResults.clear();
      });
    } catch (e, stackTrace) {
      _showErrorMessage('提交失败，请重试');
      print('提交失败，请重试');
      print(stackTrace);
      print(e);
    } finally {
      setState(() => _isLoading = false);
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
            CheckboxListTile(
              title: Text('使用九宫格展示图片'),
              value: _useGrid,
              onChanged: (val) {
                setState(() {
                  _useGrid = val ?? false;
                });
              },
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
                  ReorderableWrap(
                    spacing: 8,
                    runSpacing: 8,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        final item = _uploadedImageResults.removeAt(oldIndex);
                        _uploadedImageResults.insert(newIndex, item);

                        // 同步显示用的 _uploadedImages
                        _uploadedImages = _uploadedImageResults
                            .map((e) => '${e.imageUrl}?fmt=webp&q=20&w=100')
                            .toList();
                      });
                    },
                    children: _uploadedImages.map((imageUrl) {
                      return Container(
                        key: ValueKey(imageUrl),
                        width: MediaQuery.of(context).size.width / 3 - 16,
                        child: Image.network(imageUrl, fit: BoxFit.cover),
                      );
                    }).toList(),
                  )
                ],
              ),
          ],
        ),
      ),
    );
  }
}
