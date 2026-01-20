# GitHub Issue Editor

一款采用网易云音乐风格设计的 GitHub Issue 编辑器移动应用，让你以朋友圈的方式管理 GitHub Issues。

## ✨ 特性

### 📱 核心功能
- **GitHub Issues 管理** - 查看、创建、编辑 GitHub Issues
- **标签筛选** - 按标签和状态（open/closed）筛选 Issues
- **无限滚动** - 自动加载更多 Issues，流畅浏览体验
- **富文本编辑** - 支持 Markdown 格式编辑

### 🎨 媒体支持
- **图片上传** - 支持多图上传至 AWS S3
- **九宫格展示** - 类朋友圈的图片网格布局
- **拖拽排序** - 自由调整图片顺序
- **视频支持** - 上传和预览视频内容
- **实况照片** - 支持 iOS Live Photos
- **ThumbHash 预览** - 图片加载前显示模糊占位图

### 💾 实用功能
- **草稿保存** - 自动保存未发布的内容
- **版本检查** - 自动检查并提示应用更新
- **自定义相册** - 内置照片选择器，支持多选和预览

### 🎨 设计风格
- 采用网易云音乐红白配色方案
- 简洁现代的 Material Design
- 流畅的交互动画

## 📸 截图

_待添加应用截图_

## 🚀 开始使用

### 前置要求

- Flutter SDK >= 3.5.2
- Dart SDK >= 3.5.2
- Android Studio / Xcode（用于移动端开发）

### 安装步骤

1. **克隆仓库**
   ```bash
   git clone https://github.com/leoonliang/github-issue-editor.git
   cd github-issue-editor
   ```

2. **安装依赖**
   ```bash
   flutter pub get
   ```

3. **配置 GitHub**

   启动应用后，在设置页面配置：
   - GitHub Token（需要 repo 权限）
   - 仓库所有者
   - 仓库名称

4. **配置 AWS S3（可选）**

   如需使用图片上传功能，需配置 AWS S3：
   - Access Key ID
   - Secret Access Key
   - Bucket 名称
   - Region

5. **运行应用**
   ```bash
   flutter run
   ```

## 📦 主要依赖

| 依赖包 | 用途 |
|-------|------|
| flutter_riverpod | 状态管理 |
| flutter_quill | 富文本编辑器 |
| image_picker | 图片/视频选择 |
| photo_manager | 相册管理 |
| video_player | 视频播放 |
| aws_s3_api | AWS S3 文件上传 |
| cached_network_image | 图片缓存 |
| thumbhash | 图片占位符 |
| reorderables | 拖拽排序 |
| package_info_plus | 应用版本信息 |
| url_launcher | 打开外部链接 |

## 🏗️ 项目结构

```
lib/
├── components/          # 可复用组件
│   └── markdown_editor.dart
├── models/             # 数据模型
├── providers/          # Riverpod 状态管理
│   ├── config_provider.dart
│   ├── github_provider.dart
│   └── upload_provider.dart
├── screens/            # 页面
│   ├── issue_list_screen.dart
│   ├── publish_screen.dart
│   └── settings_screen.dart
├── services/           # 业务逻辑
│   ├── github.dart
│   ├── imageProcessService.dart
│   └── version_service.dart
└── widgets/            # 自定义组件
    └── image_grid_widget.dart
```

## 🔧 配置说明

##***REMOVED*** 权限

需要创建具有以下权限的 GitHub Personal Access Token：
- `repo` - 完整的仓库访问权限（用于读写 Issues）

创建 Token：[GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens)

### AWS S3 配置

用于存储上传的图片和视频文件：
1. 创建 S3 Bucket 并设置为公开读取
2. 创建 IAM 用户并授予 S3 上传权限
3. 获取 Access Key 和 Secret Key

## 📱 支持平台

- ✅ Android
- ✅ iOS
- ⚠️ macOS（部分功能）
- ❌ Web（图片选择器不支持）

## 🔄 版本更新

应用内置版本检查功能，会从 GitHub Releases 自动检查更新：
- 在设置页面点击"检查更新"
- 如有新版本，会显示更新说明和下载链接
- 支持直接下载 APK 文件（Android）

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 👨‍💻 作者

**leoonliang**
- Email: dsleoon@gmail.com
- GitHub: [@leoonliang](https://github.com/leoonliang)

## 📄 许可证

本项目仅供个人学习和研究使用。


## 📝 更新日志

### v2.0.0 (2026-01-20)
- ✨ 新增草稿保存功能（自动保存和恢复）
- ✨ 新增版本检查和自动更新功能
- ✨ 优化图片网格布局，简化添加按钮设计
- ✨ 实现无限滚动加载，流畅浏览体验
- ✨ 优化文章列表展示（内容优先，彩色标签）
- ✨ 发布页面独立，移除底部导航
- ✨ 文章列表新增浮动发布按钮
- ✨ 新增关于页面（作者信息、版本信息）
- 🐛 修复视频预览页面显示实况按钮的问题
- 🐛 修复无限滚动分页失效的问题

### v1.0.0
- 🎉 初始版本发布
- ✨ GitHub Issues 基础管理功能
- ✨ 图片和视频上传
- ✨ 九宫格拖拽排序
- ✨ 实况照片支持

---

Made with ❤️ by leoonliang
