import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../providers/upload_provider.dart';
import '../providers/github_provider.dart';
import '../services/github.dart';
import '../services/music.dart';
import '../services/video.dart';
import '../widgets/image_grid_widget.dart';

/// 发布页面（网易云风格）
class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({Key? key}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// 加载草稿
  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftTitle = prefs.getString('draft_title') ?? '';
      final draftContent = prefs.getString('draft_content') ?? '';
      final draftLabel = prefs.getString('draft_label') ?? 'note';

      if (draftTitle.isNotEmpty || draftContent.isNotEmpty) {
        setState(() {
          _titleController.text = draftTitle;
          _contentController.text = draftContent;
          _selectedLabel = draftLabel;
        });
      }
    } catch (e) {
      print('加载草稿失败: $e');
    }
  }

  /// 保存草稿
  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('draft_title', _titleController.text);
      await prefs.setString('draft_content', _contentController.text);
      await prefs.setString('draft_label', _selectedLabel);

      _showSuccessMessage('草稿已保存');
    } catch (e) {
      _showErrorMessage('保存草稿失败');
      print('保存草稿失败: $e');
    }
  }

  /// 清除草稿
  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('draft_title');
      await prefs.remove('draft_content');
      await prefs.remove('draft_label');
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
      markdownText = markdownText.trim() + '\n' + gridMarkdown;
    }

    try {
      await githubService.createGitHubIssue(
        title,
        markdownText,
        _selectedLabel,
      );

      // 发布成功后清除草稿
      await _clearDraft();

      _showSuccessMessage('发布成功！');

      // 重置状态
      _titleController.clear();
      _contentController.clear();
      uploadNotifier.clear();

      // 返回上一页
      Navigator.pop(context);
    } catch (e, stackTrace) {
      _showErrorMessage('提交失败，请重试');
      print('提交失败: $e');
      print(stackTrace);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showErrorMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelsAsync = ref.watch(labelsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('发布笔记', style: TextStyle(color: Colors.black)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // 图片网格 - 放在最上面
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ImageGridWidget(),
                    ),
                    const SizedBox(height: 20),

                    // 标题输入框
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _titleController,
                        style: const TextStyle(fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: '添加标题',
                          hintStyle: TextStyle(
                            color: Color(0xFFBBBBBB),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const Divider(height: 1, color: Color(0xFFEEEEEE)),

                    // 内容输入框
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: TextField(
                        controller: _contentController,
                        maxLines: 8,
                        style: const TextStyle(fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: '添加正文',
                          hintStyle: TextStyle(
                            color: Color(0xFFBBBBBB),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          // 底部操作区域
          Container(
            color: Colors.white,
            child: Column(
              children: [
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                // 添加内容按钮
                InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.music_note,
                                  color: Color(0xFFEC4141)),
                              title: const Text('添加音乐'),
                              onTap: () {
                                Navigator.pop(context);
                                _showMusicInputDialog();
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.videocam,
                                  color: Color(0xFFEC4141)),
                              title: const Text('添加视频'),
                              onTap: () {
                                Navigator.pop(context);
                                _showVideoInputDialog();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.music_note, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '添加内容',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFFBBBBBB)),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFEEEEEE)),

                // 标签区域
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        '标签',
                        style: TextStyle(fontSize: 15, color: Colors.black87),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: labelsAsync.when(
                          data: (labels) {
                            if (labels.isEmpty) {
                              return const Text(
                                '请先在设置中配置 GitHub',
                                style: TextStyle(
                                    color: Color(0xFFBBBBBB), fontSize: 14),
                              );
                            }
                            // 确保 _selectedLabel 在列表中
                            if (!labels.contains(_selectedLabel)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                setState(() {
                                  _selectedLabel = labels.first;
                                });
                              });
                            }
                            return DropdownButton<String>(
                              value: labels.contains(_selectedLabel)
                                  ? _selectedLabel
                                  : labels.first,
                              isExpanded: true,
                              underline: Container(),
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
                            );
                          },
                          loading: () => const Text(
                            '加载中...',
                            style: TextStyle(color: Color(0xFFBBBBBB)),
                          ),
                          error: (error, stack) => Text(
                            '加载失败',
                            style: TextStyle(color: Colors.red[300]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFEEEEEE)),

                // 底部按钮
                Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 12,
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                  ),
                  child: Row(
                    children: [
                      // 存草稿按钮
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saveDraft,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF666666),
                            side: const BorderSide(color: Color(0xFFDDDDDD)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            '存草稿',
                            style: TextStyle(
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 发布按钮
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitMarkdown,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC4141),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  '发布笔记',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),
                    ],
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
