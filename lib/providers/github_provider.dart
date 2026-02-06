import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/github.dart';
import 'config_provider.dart';

/// GitHub Service Provider
final githubServiceProvider = Provider<GitHubService?>((ref) {
  final config = ref.watch(configProvider);

  if (!config.github.isValid) {
    return null;
  }

  return GitHubService(config.github);
});

/// Issues Provider - 获取 Issues 列表（带标签和状态筛选）
class IssuesParams {
  final String label;
  final String state;

  IssuesParams({required this.label, required this.state});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IssuesParams &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          state == other.state;

  @override
  int get hashCode => label.hashCode ^ state.hashCode;
}

/// Issues 状态类
class IssuesState {
  final List<GitHubIssue> issues;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;

  IssuesState({
    this.issues = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
  });

  IssuesState copyWith({
    List<GitHubIssue>? issues,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
  }) {
    return IssuesState(
      issues: issues ?? this.issues,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

/// Issues Notifier - 支持分页加载
class IssuesNotifier extends StateNotifier<IssuesState> {
  final GitHubService? githubService;
  final IssuesParams params;

  IssuesNotifier(this.githubService, this.params) : super(IssuesState()) {
    loadIssues();
  }

  /// 加载第一页
  Future<void> loadIssues() async {
    if (githubService == null) {
      state = IssuesState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final issues = await githubService!.fetchGitHubIssues(
        label: params.label,
        state: params.state,
        page: 1,
        perPage: 30,
      );

      state = IssuesState(
        issues: issues,
        isLoading: false,
        hasMore: issues.length >= 30,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 加载更多
  Future<void> loadMore() async {
    if (githubService == null || !state.hasMore || state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.currentPage + 1;
      final newIssues = await githubService!.fetchGitHubIssues(
        label: params.label,
        state: params.state,
        page: nextPage,
        perPage: 30,
      );

      state = state.copyWith(
        issues: [...state.issues, ...newIssues],
        isLoading: false,
        hasMore: newIssues.length >= 30,
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 刷新列表
  Future<void> refresh() async {
    state = IssuesState();
    await loadIssues();
  }
}

/// Issues Provider
final issuesProvider = StateNotifierProvider.family<IssuesNotifier, IssuesState, IssuesParams>((ref, params) {
  final githubService = ref.watch(githubServiceProvider);
  return IssuesNotifier(githubService, params);
});
