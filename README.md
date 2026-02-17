# Seewo Helper

一个面向 Windows 的希沃辅助工具，聚合了文件监听、上传、壁纸与热点等常用能力，适合教室/办公设备的日常辅助管理。

## 功能简介

- 事件监听：监听指定进程（如 PPT/Word/Excel/浏览器）打开的文件，并复制到本地归档目录。
- 文件上传：扫描 `EventListen` 目录并批量上传，支持自动上传、日志查看、上传直链与二维码复制。
- 壁纸管理：获取最新壁纸、查看壁纸信息，并一键设置为桌面壁纸。
- 热点管理：在应用内配置并管理 Windows 热点（SSID、密码、IP），支持热点诊断。
- 系统托盘：关闭窗口后可驻留托盘，支持显示/隐藏与退出。
- 设置中心：统一管理配置目录、开机自启、静默启动、监听与自动上传等参数。

## 运行环境

- Windows（推荐）
- Flutter SDK 3.x+

## 快速启动

```bash
flutter pub get
flutter analyze
flutter run -d windows
```

## 发版流程（本地触发）

1. 在本地执行版本递增：

```bash
dart tool/bump_version.dart --type patch
```

可选参数：
- `--type major|minor|patch`：版本号递增类型（默认 `patch`）
- `--next-only`：仅输出下一版本号，不改文件
- `--print-only`：仅输出当前版本号，不改文件
- `--release`：递增后自动执行 `git add/commit/tag/push`

2. 若未使用 `--release`，手动提交并推送：

```bash
git add pubspec.yaml CHANGELOG.md
git commit -m "chore(release): bump version to x.y.z"
git tag vx.y.z
git push origin
git push origin vx.y.z
```

3. 推送 `v*` tag 后，GitHub Actions 会自动构建 Windows 包并发布 Release。

## 配置与数据目录

- 默认配置目录：`D:\SeewoHelper`
- 监听文件目录：`<配置目录>\EventListen`
- 壁纸默认保存目录：`<配置目录>\Wallpapers`

## 常用说明

- 首次使用建议先在“设置”页确认配置目录与启动行为。
- 若需要使用热点功能，请以管理员权限运行应用。
- 若启用静默启动，应用会隐藏主窗口并在托盘中运行。
