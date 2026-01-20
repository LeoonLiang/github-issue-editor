# 安全配置指南

## ⚠️ 重要安全提示

**永远不要在代码中硬编码敏感信息！**

本应用使用应用内配置来管理所有敏感凭证。所有配置都保存在设备本地，不会提交到 Git 仓库。

## 配置方式

### 1. 应用内配置（推荐）

应用已经提供了完整的设置界面，您可以在应用内配置：

1. 打开应用
2. 进入"设置"页面
3. 配置以下信息：
   - **GitHub 配置**
     - Token: `ghp_xxxxx`（在 GitHub Settings → Developer settings → Personal access tokens 创建）
     - Owner: 您的 GitHub 用户名
     - Pic Repo: 图片仓库名称
     - Issue Repo: 文章仓库名称

   - **OSS 配置**（支持多个）
     - 名称: 配置名称（如"缤纷云"、"七牛云"）
     - Access Key ID
     - Secret Access Key
     - Region
     - Bucket
     - Endpoint URL

### 2. 数据存储

所有配置通过 `shared_preferences` 存储在设备本地：
- 配置文件路径由系统管理
- 不会同步到 Git 仓库
- 仅在当前设备有效

### 3. 开发者配置

如果您是开发者并需要测试，建议：

1. **不要创建测试配置文件**
2. **使用应用内配置界面**进行配置
3. **确保 `.gitignore` 包含**：
   ```
   *.env
   *.env.local
   **/credentials.json
   **/config.local.dart
   ```

## 凭证管理最佳实践

### GitHub Token

1. 访问 https://github.com/settings/tokens
2. 创建 Personal Access Token (classic)
3. 权限选择：
   - `repo` (完整仓库访问)
   - `write:packages` (如需上传包)
4. 将 Token 保存到应用配置中

### OSS 凭证

#### 缤纷云
1. 登录缤纷云控制台
2. 创建 Access Key
3. 在应用中添加 OSS 配置

#### 七牛云
1. 登录七牛云控制台
2. 个人中心 → 密钥管理
3. 在应用中添加 OSS 配置

## 安全检查清单

- [ ] 确认代码中没有硬编码的密钥
- [ ] 确认 `.gitignore` 配置正确
- [ ] 使用应用内配置管理所有凭证
- [ ] 定期轮换凭证
- [ ] 为每个应用使用独立的凭证
- [ ] 限制凭证的最小权限

## Git 历史清理

如果您之前不小心提交了敏感信息，请参考以下步骤：

1. **立即撤销暴露的凭证**
2. 使用 `git-filter-repo` 清理历史
3. 强制推送到远程仓库
4. 通知所有协作者重新克隆仓库

## 遇到问题？

如果您发现任何安全问题，请：
1. **不要公开披露**
2. 发送邮件到仓库维护者
3. 等待安全修复后再公开讨论
