# GitHub Issue Editor - 重构完成

## 架构概览

### 目录结构
```
lib/
├── main.dart                          # 入口文件（使用 Riverpod）
├── models/                            # 数据模型
│   └── upload_models.dart             # 上传状态模型
├── providers/                         # 状态管理
│   └── upload_provider.dart           # 上传队列和编辑器 Provider
├── services/                          # 服务层
│   ├── github.dart                    # GitHub API
│   ├── imageProcessService.dart       # 图片处理服务（新增）
│   ├── music.dart                     # 音乐卡片
│   ├── ossService.dart                # OSS 上传
│   └── video.dart                     # 视频卡片
├── widgets/                           # UI 组件
│   ├── image_upload_card.dart         # 单张图片卡片
│   └── image_grid_widget.dart         # 图片网格
├── screens/                           # 页面
│   ├── publish_screen.dart            # 主发布页面
│   └── custom_image_picker.dart       # 自定义图片选择器（朋友圈风格）
```

## 核心特性

### 1. 自定义图片选择器（朋友圈风格）
- ✅ **自定义选择界面**: 不使用系统图片选择器
- ✅ **实况照片识别**: 选择界面直接显示 Live 标记
- ✅ **选择顺序显示**: 显示 1、2、3... 数字角标
- ✅ **多选管理**: 支持取消选择、重新选择
- ✅ **最多 9 张**: 符合朋友圈风格的图片数量限制
- ✅ **相册权限管理**: 自动请求相册访问权限

### 2. 性能优化
- ✅ **并发控制**: 最多同时上传 3 张图片，避免内存峰值
- ✅ **队列管理**: 自动调度上传队列，失败图片可独立重试
- ✅ **缓存优化**: 使用 `cached_network_image` 缓存网络图片
- ✅ **内存管理**: 上传完成后自动释放原图内存

### 2. UI/UX 改进
- ✅ **朋友圈风格**: 现代化卡片式布局
- ✅ **实时进度**: 每张图片独立显示上传进度
- ✅ **状态反馈**: 清晰的等待、上传中、成功、失败状态
- ✅ **拖拽排序**: 支持长按拖拽重新排列图片顺序
- ✅ **图片预览**: 点击查看大图

### 3. 交互增强
- ✅ **删除确认**: 删除前弹出确认对话框
- ✅ **失败重试**: 失败图片显示重试按钮
- ✅ **最多 9 张**: 限制图片数量，符合朋友圈风格

### 4. Markdown 格式保持
最终生成的 Markdown 格式**完全保持不变**：
```markdown
![image](https://xxx.jpg){width=1920 height=1080 thumbhash="abc123"}
![image](https://xxx.jpg){liveVideo="https://xxx.mp4" width=1920 height=1080 thumbhash="abc123"}
```

## 使用说明

### 运行项目
```bash
flutter pub get
flutter run
```

### 上传图片流程
1. 点击 "添加图片" 按钮或网格中的 ➕ 图标
2. 进入自定义图片选择器（朋友圈风格）
3. 浏览相册，看到实况照片会显示 Live 标记
4. 点击图片选择，右上角显示选择顺序（1、2、3...）
5. 再次点击取消选择
6. 点击右上角"确定"按钮确认选择
7. 图片自动开始上传（最多 3 张并发）
8. 每张图片显示上传进度
9. 上传完成后可拖拽排序
10. 点击图片预览大图
11. 点击 × 删除图片

### 发布内容
1. 输入标题（必填）
2. 输入正文内容
3. 选择标签
4. 勾选 "使用九宫格展示图片"（默认勾选）
5. 点击右上角 "发布" 按钮
6. 等待所有图片上传完成后提交到 GitHub

## 技术亮点

### 状态管理（Riverpod）
- **uploadQueueProvider**: 管理图片上传队列
  - 自动调度上传任务
  - 控制并发数量
  - 处理重试逻辑

- **editorProvider**: 管理编辑器状态
  - 标题、内容、标签
  - 九宫格选项

### 图片处理流程
```
选择图片 → 创建 ImageUploadState
         ↓
      加入队列（pending）
         ↓
      自动调度上传（uploading）
         ↓
   处理实况照片/普通图片
         ↓
   生成 thumbhash + 上传 OSS
         ↓
      更新状态（success）
         ↓
      显示缩略图
```

### 并发控制策略
- 使用 `StateNotifier` 管理队列
- `_processQueue()` 方法自动调度
- 单个失败不影响其他上传
- 完成后自动触发下一批

## 待测试功能

- [x] 自定义图片选择器界面
- [x] 实况照片识别和显示
- [x] 选择顺序角标显示
- [x] 单张图片上传
- [x] 多张图片并发上传（3 张）
- [x] 超过 3 张图片的队列管理
- [ ] 实况照片（Motion Photo）处理和上传
- [ ] 上传失败重试
- [ ] 拖拽排序
- [ ] 图片预览
- [ ] 最终 Markdown 生成
- [ ] 提交到 GitHub

## 配置要求

### iOS 配置 (Info.plist)
需要添加相册访问权限：
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>需要访问您的相册以选择图片</string>
```

### Android 配置 (AndroidManifest.xml)
需要添加存储权限：
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

Android 13+ 需要添加：
```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
```

## 下一步优化建议

1. **性能监控**: 添加上传速度和内存使用监控
2. **离线支持**: 本地草稿保存
3. **批量操作**: 批量删除、批量重试
4. **图片编辑**: 裁剪、旋转、滤镜
5. **压缩选项**: 允许用户选择压缩质量

## 注意事项

- 保持原 `markdown_editor.dart` 文件作为备份
- Markdown 格式与原版本完全兼容
- 依赖 Flutter SDK 3.5.2+
- 需要配置 OSS 和 GitHub Token
