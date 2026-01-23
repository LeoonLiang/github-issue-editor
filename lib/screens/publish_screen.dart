import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:async';
import '../providers/upload_provider.dart';
import '../providers/github_provider.dart';
import '../services/github.dart';
import '../services/music.dart';
import '../services/video.dart';
import '../widgets/image_grid_widget.dart';
import '../models/upload_models.dart';

/// 发布页面
class PublishScreen extends ConsumerStatefulWidget {
  final GitHubIssue? issue;
  const PublishScreen({Key? key, this.issue}) : super(key: key);

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  String _selectedLabel = 'note';
  bool _isSubmitting = false;
  bool _isMusicLoading = false;
  bool _isVideoLoading = false;

  Timer? _debounce;

  bool get _isEditing => widget.issue != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      _loadIssueData();
    } else {
      _loadDraft();
    }
    // 添加监听器以实现自动保存
    _titleController.addListener(_autoSaveDraft);
    _contentController.addListener(_autoSaveDraft);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.removeListener(_autoSaveDraft);
    _contentController.removeListener(_autoSaveDraft);
    _titleController.dispose();
    _contentController.dispose();

    // 如果是编辑模式，清空上传队列，避免覆盖新建文章的草稿
    if (_isEditing) {
      ref.read(uploadQueueProvider.notifier).state = [];
    }

    super.dispose();
  }

  /// 加载草稿
  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftTitle = prefs.getString('draft_title') ?? '';
      final draftContent = prefs.getString('draft_content') ?? '';
      final draftLabel = prefs.getString('draft_label') ?? 'note';
      final draftImagesJson = prefs.getString('draft_images') ?? '';

      if (draftTitle.isNotEmpty || draftContent.isNotEmpty) {
        setState(() {
          _titleController.text = draftTitle;
          _contentController.text = draftContent;
          _selectedLabel = draftLabel;
        });
      }

      // 先清空队列，确保不会有编辑页面遗留的图片
      ref.read(uploadQueueProvider.notifier).state = [];

      // 恢复草稿图片到上传队列
      if (draftImagesJson.isNotEmpty) {
        try {
          final List<dynamic> imagesData = jsonDecode(draftImagesJson);
          final List<ImageUploadState> restoredStates = [];

          // 将保存的图片URL转换为 ImageUploadState
          for (var imageData in imagesData) {
            final imageUrl = imageData['imageUrl'] as String?;
            final thumbnailUrl = imageData['thumbnailUrl'] as String?;
            final videoUrl = imageData['videoUrl'] as String?;

            if (imageUrl != null) {
              // 创建一个虚拟的 XFile（仅用于显示，不会实际使用）
              final file = XFile('');

              final uploadState = ImageUploadState(
                id: const Uuid().v4(),
                file: file,
                status: UploadStatus.success,
                progress: 1.0,
                result: UploadResult(
                  imageUrl: imageUrl,
                  videoUrl: videoUrl ?? '',
                  width: 0,
                  height: 0,
                  thumbhash: '',
                ),
                thumbnailUrl: thumbnailUrl,
              );

              restoredStates.add(uploadState);
            }
          }

          // 一次性设置所有图片状态
          if (restoredStates.isNotEmpty) {
            ref.read(uploadQueueProvider.notifier).state = restoredStates;
            print('✅ 已恢复 ${restoredStates.length} 张草稿图片');
          }
        } catch (e) {
          print('恢复草稿图片失败: $e');
        }
      }
    } catch (e) {
      print('加载草稿失败: $e');
    }
  }

  /// 加载已有 Issue 数据
  void _loadIssueData() {
    if (widget.issue == null) return;
    final issue = widget.issue!;

    _titleController.text = issue.title;

    // 从 body 中分离图片和纯文本
    final imageRegex = RegExp(r'!\[.*?\]\((.*?)\)(\{.*?\})?');
    final matches = imageRegex.allMatches(issue.body);
    String contentText = issue.body.replaceAll(imageRegex, '').trim();

    // 移除音乐和视频卡片
    final cardRegex = RegExp(r'\[(music|video)\]\(.*?\)\n');
    contentText = contentText.replaceAll(cardRegex, '').trim();

    _contentController.text = contentText;

    if (issue.labels.isNotEmpty) {
      _selectedLabel = issue.labels.first;
    }

    final List<ImageUploadState> imageStates = [];
    for (var match in matches) {
      final imageUrl = match.group(1);
      final attributesString = match.group(2) ?? ''; // 获取 {} 中的属性

      if (imageUrl != null) {
        // 解析属性：liveVideo, width, height, thumbhash
        String videoUrl = '';
        int width = 0;
        int height = 0;
        String thumbhash = '';

        if (attributesString.isNotEmpty) {
          // 提取 liveVideo
          final videoRegex = RegExp(r'liveVideo="([^"]*)"');
          final videoMatch = videoRegex.firstMatch(attributesString);
          if (videoMatch != null) {
            videoUrl = videoMatch.group(1) ?? '';
          }

          // 提取 width
          final widthRegex = RegExp(r'width=(\d+)');
          final widthMatch = widthRegex.firstMatch(attributesString);
          if (widthMatch != null) {
            width = int.tryParse(widthMatch.group(1) ?? '0') ?? 0;
          }

          // 提取 height
          final heightRegex = RegExp(r'height=(\d+)');
          final heightMatch = heightRegex.firstMatch(attributesString);
          if (heightMatch != null) {
            height = int.tryParse(heightMatch.group(1) ?? '0') ?? 0;
          }

          // 提取 thumbhash
          final thumbhashRegex = RegExp(r'thumbhash="([^"]*)"');
          final thumbhashMatch = thumbhashRegex.firstMatch(attributesString);
          if (thumbhashMatch != null) {
            thumbhash = thumbhashMatch.group(1) ?? '';
          }
        }

        final uploadState = ImageUploadState(
          id: const Uuid().v4(),
          file: XFile(''), // 虚拟文件
          status: UploadStatus.success,
          progress: 1.0,
          result: UploadResult(
            imageUrl: imageUrl,
            videoUrl: videoUrl,
            width: width,
            height: height,
            thumbhash: thumbhash,
          ),
          thumbnailUrl: imageUrl, // 使用原图作为缩略图
          isLivePhoto: videoUrl.isNotEmpty,
          enableLiveVideo: videoUrl.isNotEmpty, // 如果有视频URL，标记为启用live视频
        );
        imageStates.add(uploadState);
      }
    }

    // 设置图片状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(uploadQueueProvider.notifier).state = imageStates;
    });
  }

  /// 保存草稿
  Future<void> _saveDraft() async {
    if (_isEditing) return; // 编辑模式不保存草稿
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('draft_title', _titleController.text);
      await prefs.setString('draft_content', _contentController.text);
      await prefs.setString('draft_label', _selectedLabel);

      // 保存已上传成功的图片
      await _saveDraftImages(prefs);

      _showSuccessMessage('草稿已保存');
    } catch (e) {
      _showErrorMessage('保存草稿失败');
      print('保存草稿失败: $e');
    }
  }

  /// 自动保存草稿（防抖）
  void _autoSaveDraft() {
    if (_isEditing) return; // 编辑模式不自动保存
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _saveDraftSilently();
    });
  }

  /// 静默保存草稿（不显示提示信息）
  Future<void> _saveDraftSilently() async {
    if (_isEditing) return; // 编辑模式不保存
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('draft_title', _titleController.text);
      await prefs.setString('draft_content', _contentController.text);
      await prefs.setString('draft_label', _selectedLabel);

      // 保存已上传成功的图片
      await _saveDraftImages(prefs);
    } catch (e) {
      print('自动保存草稿失败: $e');
    }
  }

  /// 保存草稿图片到 SharedPreferences
  Future<void> _saveDraftImages(SharedPreferences prefs) async {
    if (_isEditing) return; // 编辑模式不保存草稿图片
    try {
      final uploadQueue = ref.read(uploadQueueProvider);

      // 获取所有上传成功的图片
      final successImages = uploadQueue
          .where((state) => state.isSuccess && state.result != null)
          .map((state) => {
                'imageUrl': state.result!.imageUrl,
                'thumbnailUrl': state.thumbnailUrl ?? '',
                'videoUrl': state.result!.videoUrl,
              })
          .toList();

      // 保存为 JSON
      final jsonString = jsonEncode(successImages);
      await prefs.setString('draft_images', jsonString);
    } catch (e) {
      print('保存草稿图片失败: $e');
    }
  }

  /// 确认并清空草稿
  Future<void> _confirmClearDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空内容'),
        content: const Text('确定要清空所有内容吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!_isEditing) {
        await _clearDraft();
      }
      setState(() {
        _titleController.clear();
        _contentController.clear();
      });
      // 清空上传队列中的图片
      ref.read(uploadQueueProvider.notifier).state = [];
      _showSuccessMessage('内容已清空');
    }
  }

  /// 清除草稿
  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('draft_title');
      await prefs.remove('draft_content');
      await prefs.remove('draft_label');
      await prefs.remove('draft_images');
    } catch (e) {
      print('清除草稿失败: $e');
    }
  }

  Future<void> _fetchMusicCardDataAndInsertToMarkdown(String input) async {
    if (_isMusicLoading) return;
    setState(() => _isMusicLoading = true);

    final musicService = MusicService();
    final idPattern = RegExp(r'[?&]id=(\d+)');
    final match = idPattern.firstMatch(input);

    if (match != null) {
      input = match.group(1)!;
    }

    try {
      final cardData = await musicService.fetchMusicCardData(input);
      _contentController.text += '\n$cardData';
    } catch (error) {
      _showErrorMessage('Failed to load music card data');
    } finally {
      setState(() => _isMusicLoading = false);
    }
  }

  Future<void> _fetchVideoCardDataAndInsertToMarkdown(String input) async {
    if (_isVideoLoading) return;
    setState(() => _isVideoLoading = true);

    final videoService = VideoCardService();
    final bvPattern = RegExp(r'/\b(BV\w+)\b');
    final match = bvPattern.firstMatch(input);

    if (match != null) {
      input = match.group(1)!;
    }

    try {
      final cardData = await videoService.fetchVideoCardData(input);
      _contentController.text += '\n$cardData';
    } catch (error) {
      _showErrorMessage('Failed to load video card data');
    } finally {
      setState(() => _isVideoLoading = false);
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
              onPressed: () => Navigator.of(context).pop(),
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
      },
    );
  }

  Future<void> _showVideoInputDialog() async {
    final TextEditingController idController = TextEditingController();
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('B站视频卡片'),
          content: TextField(
            controller: idController,
            decoration: const InputDecoration(hintText: '输入BVID'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(),
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
      },
    );
  }

  Future<void> _submitMarkdown() async {
    if (_isSubmitting) return;

    final uploadNotifier = ref.read(uploadQueueProvider.notifier);
    final editorState = ref.read(editorProvider);

    // 检查是否有正在上传的图片
    if (uploadNotifier.hasUploading) {
      _showErrorMessage('请等待图片上传完成');
      return;
    }

    setState(() => _isSubmitting = true);

    final githubService = ref.read(githubServiceProvider);
    if (githubService == null) {
      _showErrorMessage('请先配置 GitHub');
      setState(() => _isSubmitting = false);
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showErrorMessage('标题不能为空');
      setState(() => _isSubmitting = false);
      return;
    }

    String markdownText = _contentController.text;

    // 获取所有成功上传的图片结果
    final uploadResults = uploadNotifier.getSuccessResults();

    if (editorState.useGrid && uploadResults.isNotEmpty) {
      // 清掉原 Markdown 中的图片
      final imageRegex = RegExp(r'!\[.*?\]\(.*?\)(\{.*?\})?');
      markdownText = markdownText.replaceAll(imageRegex, '');

      // 在末尾追加九宫格图片（保持顺序）
      final gridMarkdown = uploadResults.map((r) => r.toMarkdown()).join('\n');
      markdownText = markdownText.trim() + '\n\n' + gridMarkdown;
    }

    try {
      if (_isEditing) {
        // 更新 Issue
        await githubService.updateGitHubIssue(
          widget.issue!.number,
          title,
          markdownText,
          [_selectedLabel], // 假设只支持单标签
        );
        _showSuccessMessage('更新成功！');
      } else {
        // 创建 Issue
        await githubService.createGitHubIssue(
          title,
          markdownText,
          _selectedLabel,
        );
        _showSuccessMessage('发布成功！');
        await _clearDraft(); // 发布成功后清除草稿
      }

      // 重置状态
      _titleController.clear();
      _contentController.clear();
      uploadNotifier.clear();

      // 返回上一页
      if (mounted) {
        Navigator.pop(context, true); // 返回 true 表示成功
      }
    } catch (e, stackTrace) {
      _showErrorMessage('提交失败，请重试');
      print('提交失败: $e');
      print(stackTrace);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelsAsync = ref.watch(labelsProvider);

    // 监听上传队列变化，当图片上传成功时自动保存草稿
    ref.listen<List<ImageUploadState>>(uploadQueueProvider, (previous, next) {
      if (_isEditing) return; // 编辑模式不自动保存

      final previousSuccess = previous?.where((s) => s.isSuccess).length ?? 0;
      final nextSuccess = next.where((s) => s.isSuccess).length;

      if (nextSuccess > previousSuccess) {
        _saveDraftSilently();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isEditing ? '编辑文章' : '发布文章',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // 保存草稿按钮（仅非编辑模式）
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.drafts_outlined),
              tooltip: '保存草稿',
              onPressed: _saveDraft,
            ),
          // 清空按钮
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '清空内容',
            onPressed: _confirmClearDraft,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题输入框
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: '文章标题',
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 内容输入框
                  TextField(
                    controller: _contentController,
                    maxLines: null, // 自动换行
                    minLines: 10,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                    decoration: const InputDecoration(
                      hintText: '开始写作...',
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 图片网格
                  ImageGridWidget(),
                ],
              ),
            ),
          ),

          // 底部操作区域
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Column(
              children: [
                // 标签和工具栏
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // 标签选择
                      Expanded(
                        child: labelsAsync.when(
                          data: (labels) {
                            if (labels.isEmpty) {
                              return const Text('无可用标签');
                            }
                            if (!labels.contains(_selectedLabel)) {
                              _selectedLabel = labels.first;
                            }
                            return DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedLabel,
                                items: labels.map((label) {
                                  return DropdownMenuItem(
                                    value: label,
                                    child: Text('# $label'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedLabel = value;
                                    });
                                  }
                                },
                              ),
                            );
                          },
                          loading: () => const Text('加载标签...'),
                          error: (e, s) => const Text('加载标签失败'),
                        ),
                      ),
                      // 媒体按钮
                      IconButton(
                        icon: const Icon(Icons.music_note_outlined),
                        tooltip: '添加音乐卡片',
                        onPressed: _showMusicInputDialog,
                      ),
                      IconButton(
                        icon: const Icon(Icons.videocam_outlined),
                        tooltip: '添加视频卡片',
                        onPressed: _showVideoInputDialog,
                      ),
                    ],
                  ),
                ),

                // 底部按钮
                Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submitMarkdown,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox.shrink()
                          : Icon(_isEditing ? Icons.save_alt_outlined : Icons.publish_outlined),
                      label: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : Text(
                              _isEditing ? '保存更新' : '确认发布',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
