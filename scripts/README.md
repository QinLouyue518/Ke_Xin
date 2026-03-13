# Flutter APK 自动打包工具

## 📦 功能说明

每次打包 APK 时自动递增版本号：
- **修订号 (patch)**：+1（例如：1.7.1 → 1.7.2）
- **构建号 (build)**：+1（例如：+26 → +27）

版本号格式：`major.minor.patch+build`
- `major` - 主版本号（手动修改）
- `minor` - 次版本号（保持不变）
- `patch` - 修订号（自动 +1）
- `build` - 构建号（自动 +1）

## 🚀 快速开始

### 方式一：一键打包（推荐）

双击运行或在命令行执行：

```bash
.\scripts\build_apk.bat
```

此脚本会自动：
1. ✅ 递增版本号（patch +1, build +1）
2. ✅ 构建 APK
3. ✅ 显示 APK 位置和大小
4. ✅ 询问是否打开 APK 所在文件夹

### 方式二：分步操作

#### 1. 仅更新版本号

```bash
.\scripts\build_apk.bat
```

或直接运行 PowerShell 脚本：
```bash
.\scripts\bump_version.ps1
```

#### 2. 手动构建 APK

```bash
flutter pub get
flutter build apk --release
```

## 📝 版本变更示例

### 打包前
```yaml
version: 1.7.1+26
```

### 运行打包脚本
```bash
.\scripts\build_apk.bat
```

### 打包后
```yaml
version: 1.7.2+27
```

APK 输出：
```
========================================
  Flutter APK Build Tool
========================================

Step 1/2: Updating version...

Starting version update...
Current version: 1.7.1+26
New version: 1.7.2+27
  - Version: 1.7.2 (+0.01)
  - Build number: +1 (current: 27)

Version updated successfully!
Saved to: pubspec.yaml

========================================

Step 2/2: Building APK...

Running Gradle task 'assembleRelease'...
√ Built build\app\outputs\flutter-apk\app-release.apk (56.0MB)

========================================
  Build Completed!
========================================

APK Location: build\app\outputs\flutter-apk\app-release.apk
APK Size: 56.0 MB

Open APK folder? (Y/N): y
```

## 📂 脚本说明

### build_apk.bat
- Windows 批处理版本（推荐）
- 自动处理编码问题
- 包含完整的错误处理
- 提供交互式提示

### bump_version.ps1
- PowerShell 版本递增脚本
- 读取并解析 `pubspec.yaml`
- 自动更新版本号
- UTF-8 编码保存

## 📌 使用流程

### 完整打包流程

```bash
# 1. 进入项目目录
cd C:\Users\20241\Desktop\my_first_diary\flutter_application_1

# 2. 运行一键打包脚本
.\scripts\build_apk.bat

# 3. 等待构建完成
# - 首次构建较慢（需要下载依赖）
# - 后续构建较快（使用缓存）

# 4. APK 生成在以下位置：
#    build\app\outputs\flutter-apk\app-release.apk
```

### 日常开发建议

1. **开发阶段**：手动构建，不更新版本
   ```bash
   flutter build apk --release
   ```

2. **测试版本**：使用脚本打包，自动递增版本
   ```bash
   .\scripts\build_apk.bat
   ```

3. **正式发布**：打包后提交版本变更到 Git
   ```bash
   git add pubspec.yaml
   git commit -m "chore: version bump to 1.8.1+27"
   git tag v1.8.1+27
   git push --tags
   ```

## ⚙️ 自定义版本规则

如果需要修改版本递增规则，编辑 `bump_version.ps1`：

### 当前规则（patch +1, build +1）
```powershell
$newPatch = $patch + 1
$newBuild = $build + 1
$newVersion = "$major.$minor.$newPatch+$newBuild"
```

### 修改为（minor +1, build +1）
```powershell
$newMinor = $minor + 1
$newBuild = $build + 1
$newVersion = "$major.$newMinor.$patch+$newBuild"
```

### 修改为（major +1, build +1）
```powershell
$newMajor = $major + 1
$newBuild = $build + 1
$newVersion = "$newMajor.$minor.$patch+$newBuild"
```

## 💡 常见问题

### Q1: 脚本执行失败，提示权限错误
**A**: 以管理员身份运行 PowerShell 或 CMD，或执行：
```bash
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Q2: 版本号格式错误
**A**: 确保 `pubspec.yaml` 中的版本号格式为 `major.minor.patch+build`
```yaml
version: 1.7.1+26  # ✅ 正确
version: 1.7.1     # ❌ 错误，缺少 build 号
```

### Q3: 构建失败，提示依赖缺失
**A**: 先运行 `flutter pub get` 安装依赖：
```bash
flutter pub get
.\scripts\build_apk.bat
```

### Q4: 如何回退版本号？
**A**: 手动编辑 `pubspec.yaml`，然后提交：
```yaml
version: 1.7.1+26  # 改回之前的版本
```

## 🎯 快速命令参考

```bash
# 查看当前版本
Get-Content pubspec.yaml | Select-String "version"

# 一键打包（推荐）
.\scripts\build_apk.bat

# 仅更新版本
.\scripts\bump_version.ps1

# 手动打包（不更新版本）
flutter build apk --release

# 清理构建缓存
flutter clean

# 完整打包流程
flutter clean
flutter pub get
.\scripts\build_apk.bat
```

## 📊 版本历史

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-03-13 | 1.7.2+27 | 自动版本管理上线（patch +1） |
| 2026-03-13 | 1.7.1+26 | 手动版本管理 |

## 🔗 相关资源

- [Flutter 版本管理文档](https://flutter.dev/docs/deployment/android#reviewing-the-build-configuration)
- [Pub 版本规范](https://dart.dev/tools/pub/versioning)
- [Android 版本控制](https://developer.android.com/studio/publish/versioning)

## 📞 问题反馈

如果脚本执行失败，请检查：
1. ✅ Flutter SDK 是否正确安装
2. ✅ 项目依赖是否完整 (`flutter pub get`)
3. ✅ PowerShell 执行策略是否允许脚本运行
4. ✅ 网络连接是否正常（需要下载 Gradle 依赖）

---

**提示**：建议在每次打包前提交 Git，方便版本回退和管理。
