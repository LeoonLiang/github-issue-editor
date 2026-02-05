# GitHub Issue Editor

这是一款增删差改 github issue 的 app，如果你是通过 issue 管理博客完整的话 ，他将可以帮助你快速发出图文风格的文章。

## ✨ 特性

### 📱 核心功能
- **GitHub Issues 管理** - 查看、创建、编辑 GitHub Issues
- **标签筛选** - 按标签和状态（open/closed）筛选 Issues
- **无限滚动** - 自动加载更多 Issues，流畅浏览体验
- **富文本编辑** - 支持 Markdown 格式编辑

### 🎨 媒体支持
- **图片上传** - 支持多图上传至 AWS S3
- **图片编辑** - 支持编辑已选择的图片（Pro Image Editor）
- **九宫格展示** - 类朋友圈的图片网格布局
- **拖拽排序** - 自由调整图片顺序
- **视频支持** - 上传和预览视频内容
- **实况照片** - 支持小米实况照片（编辑时保留原视频）
  > ⚠️ **注意**：Live Photo 功能目前仅支持小米手机的实况照片，其他品牌手机未经验证
- **ThumbHash 预览** - 图片加载前显示模糊占位图

### 💾 实用功能
- **草稿保存** - 自动保存文字和已上传图片
- **版本检查** - 自动检查并提示应用更新
- **自定义相册** - 内置照片选择器，支持多选和预览
- **配置导入导出** - 支持配置备份和恢复

### 🎨 设计风格
- 采用红白配色方案
- 简洁现代的 Material Design
- 流畅的交互动画


## 📝 输出格式

本应用发布的 GitHub Issue 内容采用增强的 Markdown 格式，包含标题、正文和富媒体信息。

### 文章结构

```markdown
# 文章标题

这是文章的正文内容，支持完整的 Markdown 语法。

可以包含多段文字、列表、引用等格式。

![image](https://example.com/image1.jpg){width=4096 height=3072 thumbhash="5xgOFYLHqZeKiHePdYZ4dhWCkDAG"}

![image](https://example.com/image2.jpg){liveVideo="https://example.com/video.mp4" width=4096 height=3072 thumbhash="XQgKDYL6mFiTybdFZnipeZPgIAgP"}
```

### 图片格式说明

图片使用扩展的 Markdown 语法，在标准图片语法后附加元数据：

**普通图片：**
```markdown
![image](https://your-cdn.com/img/example1.jpg){width=4096 height=3072 thumbhash="5xgOFYLHqZeKiHePdYZ4dhWCkDAG"}
```
- `width` / `height` - 图片原始尺寸
- `thumbhash` - 图片占位符哈希（用于加载前显示模糊预览）

**Live Photo（实况照片）：**
```markdown
![image](https://your-cdn.com/img/example2.jpg){liveVideo="https://your-cdn.com/video/example2.mp4" width=4096 height=3072 thumbhash="XQgKDYL6mFiTybdFZnipeZPgIAgP"}
```
- `liveVideo` - 实况视频的 URL（小米实况照片）
- 其他参数同普通图片

**竖图示例：**
```markdown
![image](https://your-cdn.com/img/example3.jpg){width=3072 height=4096 thumbhash="YhgOFQJpiZuH+JinhnR3h3pg+QgW"}
```

> 💡 **提示**：这些元数据虽然在标准 Markdown 渲染器中不会显示，但可以被支持的博客系统解析，用于优化图片加载体验和实现实况照片播放功能。

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

### 快速导入配置（推荐）

为了方便快速配置，我们提供了配置模板文件。按照以下步骤操作：

1. **复制配置模板**

   打开项目根目录下的 `config.template.json` 文件，复制其内容：

   ```json
   {
       "github": {
           "owner": "your-github-username",
           "repo": "your-repo-name",
           "token": "ghp_your_github_personal_access_token_here"
       },
       "ossList": [
           {
               "name": "bitiful",
               "endpoint": "https://s3.bitiful.net",
               "region": "cn-east-1",
               "accessKeyId": "your_bitiful_access_key_id",
               "secretAccessKey": "your_bitiful_secret_access_key",
               "bucket": "your-bucket-name",
               "publicDomain": "",
               "enabled": true
           },
           {
               "name": "qiniu",
               "endpoint": "https://s3.cn-south-1.qiniucs.com",
               "region": "cn-south-1",
               "accessKeyId": "your_qiniu_access_key_id",
               "secretAccessKey": "your_qiniu_secret_access_key",
               "bucket": "your-bucket-name",
               "publicDomain": "",
               "enabled": true
           }
       ],
       "displayDomain": "https://your-domain.com"
   }
   ```

2. **填写配置信息**

   将模板中的占位符替换为您的实际信息：
   - `your-github-username` → 您的 GitHub 用户名
   - `your-repo-name` → 您的仓库名称
   - `ghp_your_github_personal_access_token_here` → 您的 GitHub Token
   - `your_bitiful_access_key_id` → Bitiful Access Key ID
   - `your_bitiful_secret_access_key` → Bitiful Secret Access Key
   - `your_qiniu_access_key_id` → 七牛云 Access Key ID
   - `your_qiniu_secret_access_key` → 七牛云 Secret Access Key
   - `your-bucket-name` → 您的存储桶名称
   - `your-domain.com` → 您的图片回显域名

3. **导入配置**

   - 复制填写好的 JSON 配置
   - 打开应用，进入**设置** → **维护** → **备份与恢复** → **导入配置**
   - 粘贴 JSON 配置并导入

   > 💡 **提示**：您可以根据实际需求删除或添加 OSS 配置项，支持多个对象存储服务。

### GitHub 权限

需要创建具有以下权限的 GitHub Personal Access Token：
- `repo` - 完整的仓库访问权限（用于读写 Issues）

创建 Token：[GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens)

### 对象存储配置

本应用支持任何兼容 S3 API 的对象存储服务，包括但不限于：
- AWS S3
- Bitiful
- 七牛云 S3
- 阿里云 OSS（S3 兼容模式）
- MinIO
- 腾讯云 COS（S3 兼容模式）

**配置要点：**
1. 创建存储桶并设置为公开读取（或配置 CDN）
2. 创建访问密钥（Access Key 和 Secret Key）
3. 确保密钥具有上传文件的权限
4. 配置正确的 Endpoint 和 Region

## 📱 支持平台

> ⚠️ **重要提示**：本应用目前仅在**小米手机**上进行过完整测试和适配，其他品牌 Android 手机和 iOS 设备可能存在兼容性问题。

- ✅ Android（小米手机已测试）
- ⚠️ Android（其他品牌未验证）
- ⚠️ iOS（未充分测试）
- ❌ Web（图片选择器不支持）
- ❌ macOS（未适配）

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

### v2.0.1 (2026-01-22)
- ✨ 新增图片编辑功能，支持编辑已选择的图片
- ✨ 新增 Live Photo 编辑支持（编辑静态图片时保留原视频）
- ✨ 新增实时草稿保存（自动保存文字和已上传图片）
- ✨ 优化配置导入体验（改为弹窗输入，提供格式提示）
- 🐛 修复草稿加载时图片重复累加的问题
- 🐛 修复清空草稿时图片未清空的问题
- 🐛 修复导入配置点击取消时的报错
- ⚡ 优化发布页面键盘弹出性能

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
