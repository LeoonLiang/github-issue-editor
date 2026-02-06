import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/github.dart';
import 'config_provider.dart';
import 'github_provider.dart';

/// 标签缓存状态
class LabelsState {
  final List<String> labels;
  final DateTime? lastFetchTime;
  final bool isLoading;
  final String? error;

  LabelsState({
    this.labels = const [],
    this.lastFetchTime,
    this.isLoading = false,
    this.error,
  });

  LabelsState copyWith({
    List<String>? labels,
    DateTime? lastFetchTime,
    bool? isLoading,
    String? error,
  }) {
    return LabelsState(
      labels: labels ?? this.labels,
      lastFetchTime: lastFetchTime ?? this.lastFetchTime,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// 标签缓存 Notifier
class LabelsNotifier extends StateNotifier<LabelsState> {
  final Ref ref;
  final GitHubService? githubService;

  LabelsNotifier(this.ref, this.githubService) : super(LabelsState()) {
    // 如果 service 可用，立即加载（就像 IssuesNotifier）
    if (githubService != null) {
      _loadLabels();
    }
  }

  /// 内部加载方法
  Future<void> _loadLabels() async {
    if (githubService == null) {
      return;
    }

    print('🏷️ 开始加载标签...');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final labels = await githubService!.fetchGitHubLabels();
      print('🏷️ 成功加载 ${labels.length} 个标签: $labels');

      state = state.copyWith(
        labels: labels,
        lastFetchTime: DateTime.now(),
        isLoading: false,
        error: null,
      );
    } catch (e) {
      print('🏷️ 加载失败: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 获取标签列表（带缓存）
  Future<List<String>> getLabels({bool forceRefresh = false}) async {
    // 如果有缓存且不强制刷新，直接返回缓存
    if (!forceRefresh && state.labels.isNotEmpty && state.lastFetchTime != null) {
      // 检查缓存是否过期（5分钟）
      final now = DateTime.now();
      final diff = now.difference(state.lastFetchTime!);
      if (diff.inMinutes < 5) {
        return state.labels;
      }
    }

    // 检查 service 是否可用
    if (githubService == null) {
      state = state.copyWith(isLoading: false, error: '请先配置 GitHub');
      return [];
    }

    // 开始加载
    state = state.copyWith(isLoading: true, error: null);

    try {
      final labels = await githubService!.fetchGitHubLabels();

      state = state.copyWith(
        labels: labels,
        lastFetchTime: DateTime.now(),
        isLoading: false,
        error: null,
      );

      return labels;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      // 如果获取失败但有缓存，返回缓存
      if (state.labels.isNotEmpty) {
        return state.labels;
      }
      return [];
    }
  }

  /// 预加载标签
  Future<void> preloadLabels() async {
    await getLabels(forceRefresh: true);
  }

  /// 清空缓存
  void clearCache() {
    state = LabelsState();
  }
}

/// 标签缓存 Provider
final labelsProvider = StateNotifierProvider<LabelsNotifier, LabelsState>((ref) {
  final githubService = ref.watch(githubServiceProvider);
  return LabelsNotifier(ref, githubService);
});
