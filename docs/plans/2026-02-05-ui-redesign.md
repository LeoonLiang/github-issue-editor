# UI 改版设计文档

**日期**: 2026-02-05
**版本**: v3.0.0
**状态**: 设计阶段

## 概述

本次 UI 改版将应用从红白配色改为蓝色系现代化设计，参考 stitch 文件夹中的设计原型。改版保持所有现有功能不变，重点优化视觉体验，并在文章列表页新增搜索和图片预览功能。

## 设计目标

- ✅ 采用蓝色系配色方案，替换原有红白配色
- ✅ 支持深色和浅色两种主题模式
- ✅ 实现现代化的卡片式设计语言
- ✅ 新增文章列表搜索功能
- ✅ 新增文章列表图片九宫格预览
- ✅ 保持所有现有功能不变（除列表页外）

## 技术方案

### 主题系统

创建统一的主题配置，支持深色和浅色模式切换。

**核心配色**

| 用途 | 浅色模式 | 深色模式 |
|------|---------|---------|
| 主色 | `#0d59f2` | `#0d59f2` |
| 背景色 | `#f5f6f8` | `#101622` |
| 卡片背景 | `#ffffff` | `#1b2333` / `#1a212e` |
| 文字主色 | `#1e293b` (slate-900) | `#ffffff` |
| 文字次要 | `#64748b` (slate-500) | `#9ca6ba` |
| 边框颜色 | `#e2e8f0` (slate-200) | `#334155` (slate-800) |

**设计规范**

- 圆角：默认 8px，卡片 12px，按钮 8-12px
- 阴影：轻微阴影提升层次感
- 毛玻璃：AppBar 使用半透明背景 + backdrop blur
- 图标：使用 Flutter Material Icons

### 文件结构

```
lib/
├── theme/
│   ├── app_theme.dart          # 主题配置
│   └── app_colors.dart         # 颜色定义
├── screens/
│   ├── issue_list_screen.dart  # 需要重构
│   ├── publish_screen.dart     # 仅改配色
│   └── settings_screen.dart    # 需要重构
└── widgets/
    ├── issue_card.dart         # 新建：Issue 卡片组件
    ├── image_grid_preview.dart # 新建：九宫格图片预览
    └── search_bar_widget.dart  # 新建：搜索栏组件
```

## 页面设计详情

### 1. 文章列表页 (Issue List Screen)

**布局结构**

```
┌─────────────────────────────────┐
│  [Repo Info]     Blog Feed   [+]│  ← AppBar (毛玻璃)
├─────────────────────────────────┤
│ [🔍 Search...]           [⚙️]  │  ← 搜索栏
│ [All] [Open] [Design] [Updates] │  ← 筛选 Chips
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │ [OPEN] [#124]    2 hours ago│ │
│ │ The Evolution of...         │ │
│ │ Exploring how simplicity... │ │
│ │ ┌───┬───┬───┐               │ │
│ │ │img│img│img│  九宫格图片   │ │
│ │ ├───┼───┼───┤               │ │
│ │ │img│img│img│               │ │
│ │ └───┴───┴───┘               │ │
│ │ [Share]      [View Issue]   │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ [CLOSED] [#121]   Yesterday │ │
│ │ ...                         │ │
│ └─────────────────────────────┘ │
├─────────────────────────────────┤
│    [Feed]          [Settings]   │  ← 底部导航
└─────────────────────────────────┘
```

**新增功能**

1. **搜索功能**
   - 实时搜索 Issue 标题和内容
   - 在现有的筛选参数基础上进行过滤
   - 搜索框使用圆角卡片样式，左侧带搜索图标

2. **九宫格图片预览**
   - 解析 Issue body 中的 Markdown 图片语法
   - 提取图片 URL 和 ThumbHash
   - 根据图片数量自动调整布局：
     - 1 张：16:9 横向大图
     - 2-4 张：2x2 网格
     - 5-9 张：3x3 网格
     - 超过 9 张：显示前 8 张 + "+N"蒙层
   - 使用 ThumbHash 实现模糊占位符
   - 支持点击预览大图

**UI 组件**

- `AppBar`: 半透明毛玻璃效果
  - 中间：标题 "Blog Feed" + 仓库信息（小字）
  - 右侧：蓝色圆形加号按钮
- `SearchBar`: 圆角搜索框 + 筛选按钮
- `FilterChips`: 横向滚动的筛选条
- `IssueCard`: 卡片式 Issue 展示
  - 状态标签（绿色 Open / 灰色 Closed）
  - Issue 编号标签（蓝色）
  - 时间戳（右上角）
  - 标题（粗体，最多 2 行）
  - 内容预览（次要颜色，最多 2 行）
  - 九宫格图片预览（条件显示）
  - 底部操作栏：
    - 左侧：分享按钮（图标 + 文字）
    - 右侧：蓝色"View Issue"按钮
- `BottomNavigationBar`: 简化为 Feed 和 Settings 两项

**技术实现**

```dart
// 图片解析逻辑
List<ImageInfo> parseImagesFromMarkdown(String markdown) {
  // 正则匹配：![image](url){...thumbhash="..."...}
  // 提取：url, width, height, thumbhash, liveVideo
  // 返回图片信息列表
}

// 九宫格布局
Widget buildImageGrid(List<ImageInfo> images) {
  if (images.isEmpty) return SizedBox.shrink();

  int imageCount = images.length;
  if (imageCount == 1) {
    return buildSingleImage(images[0]);
  } else if (imageCount <= 4) {
    return buildGrid2x2(images);
  } else {
    return buildGrid3x3(images.take(9).toList(),
                        totalCount: imageCount);
  }
}
```

### 2. 发布/编辑页 (Publish Screen)

**改动范围**

仅更换配色，保持所有现有功能和布局不变。

**配色调整**

- 主色：红色 → 蓝色 `#0d59f2`
- 背景：适配浅色/深色主题
- 卡片背景：白色 / `#1b2333`
- 按钮：使用新的蓝色主题
- 边框：适配主题系统

**不改动的内容**

- 标题输入框
- 内容编辑器（Quill）
- 图片上传和编辑功能
- 拖拽排序
- Live Photo 标记
- 草稿保存
- 标签选择
- 所有业务逻辑

### 3. 设置页 (Settings Screen)

**布局结构**

```
┌─────────────────────────────────┐
│  [←]         Settings           │  ← AppBar
├─────────────────────────────────┤
│  核心配置                        │  ← 分组标题
│ ┌─────────────────────────────┐ │
│ │ [🔑] GitHub仓库          [>]│ │
│ │      user/repo              │ │
│ ├─────────────────────────────┤ │
│ │ [🌐] 显示域名            [>]│ │
│ │      未配置                 │ │
│ ├─────────────────────────────┤ │
│ │ [☁️] OSS配置              [>]│ │
│ │      配置云存储             │ │
│ └─────────────────────────────┘ │
│                                 │
│  数据管理                        │
│ ┌─────────────────────────────┐ │
│ │ [📥] 导入配置            [>]│ │
│ ├─────────────────────────────┤ │
│ │ [📤] 导出配置            [>]│ │
│ └─────────────────────────────┘ │
│                                 │
│  关于                           │
│ ┌─────────────────────────────┐ │
│ │ [ℹ️] 关于应用             [>]│ │
│ ├─────────────────────────────┤ │
│ │ [🔄] 检查更新      [New]  [>]│ │
│ │      Current: v2.0.2        │ │
│ ├─────────────────────────────┤ │
│ │ [💻] 源代码              [>]│ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```

**UI 组件**

每个设置项采用卡片式设计：
- 左侧：蓝色背景的圆角图标容器（48x48）
- 中间：标题（粗体）+ 副标题（次要颜色）
- 右侧：右箭头或状态指示器

**分组样式**
- 分组标题：蓝色小号粗体文字
- 卡片间距：分组内无间距，分组间有分隔线
- 背景：白色/深色卡片

**不改动的内容**
- 所有现有配置项和功能
- 对话框和弹窗逻辑
- 配置导入导出功能
- 版本检查功能

## 实现计划

### Phase 1: 主题系统
1. 创建 `lib/theme/app_colors.dart` - 定义颜色常量
2. 创建 `lib/theme/app_theme.dart` - 定义 ThemeData
3. 在 `main.dart` 中应用主题

### Phase 2: 文章列表页
1. 创建 `lib/widgets/search_bar_widget.dart` - 搜索栏组件
2. 创建 `lib/widgets/image_grid_preview.dart` - 九宫格预览组件
3. 创建 `lib/widgets/issue_card.dart` - Issue 卡片组件
4. 重构 `lib/screens/issue_list_screen.dart`
   - 应用新主题
   - 集成搜索功能
   - 集成图片预览
   - 简化底部导航栏

### Phase 3: 发布页
1. 更新 `lib/screens/publish_screen.dart` 中的配色
2. 移除所有硬编码的红色，使用主题色
3. 测试所有功能正常工作

### Phase 4: 设置页
1. 重构 `lib/screens/settings_screen.dart`
2. 实现分组卡片式布局
3. 为每个设置项添加图标
4. 应用新主题样式

### Phase 5: 测试与优化
1. 深色/浅色模式切换测试
2. 图片预览功能测试
3. 搜索功能测试
4. 性能优化（图片加载、列表滚动）
5. 边界情况处理

## 技术细节

### 图片解析

```dart
class ImageInfo {
  final String url;
  final String? thumbhash;
  final int? width;
  final int? height;
  final String? liveVideo;
}

// 正则表达式匹配 Markdown 图片
// Pattern: ![image](url){width=... height=... thumbhash="..."}
RegExp imageRegex = RegExp(
  r'!\[image\]\((https?://[^\)]+)\)\{([^\}]+)\}'
);
```

### ThumbHash 占位符

使用现有的 `thumbhash` 包，在图片加载前显示模糊占位符：

```dart
// 解码 ThumbHash 并显示
ThumbHash.fromBase64(thumbhashString).toImage();
```

### 搜索实现

在现有的 `issuesProvider` 基础上添加客户端搜索过滤：

```dart
// 搜索逻辑
List<GitHubIssue> filterIssues(
  List<GitHubIssue> issues,
  String searchQuery
) {
  if (searchQuery.isEmpty) return issues;

  return issues.where((issue) {
    return issue.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
           issue.body.toLowerCase().contains(searchQuery.toLowerCase());
  }).toList();
}
```

## 兼容性

- Flutter SDK: >= 3.5.2
- Dart SDK: >= 3.5.2
- 所有现有依赖包保持不变
- 不引入新的第三方依赖（除非必要）

## 风险与注意事项

1. **图片解析性能**
   - Issue 列表可能包含大量图片链接
   - 需要缓存解析结果，避免重复解析
   - 使用 `cached_network_image` 缓存图片

2. **搜索性能**
   - 在大量 Issue 时可能有性能问题
   - 考虑添加防抖（debounce）
   - 仅搜索已加载的 Issue

3. **主题切换**
   - 确保所有页面正确响应主题变化
   - 避免硬编码颜色值
   - 测试深色模式下的对比度

4. **向后兼容**
   - 不破坏现有的草稿保存功能
   - 不影响现有的配置数据
   - 确保升级后用户数据完整

## 验收标准

- [ ] 深色和浅色主题均正常显示
- [ ] 文章列表搜索功能正常
- [ ] 九宫格图片预览正常显示
- [ ] ThumbHash 占位符正常工作
- [ ] 所有现有功能不受影响
- [ ] 性能无明显下降
- [ ] UI 符合 stitch 设计稿风格
- [ ] 在小米设备上测试通过

## 参考资料

- Stitch 设计文件：`stitch/` 目录
- 原项目 README：`README.md`
- 现有主题：Material Design（红白配色）
- 目标主题：现代化蓝色系设计
