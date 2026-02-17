# Seewo Helper

卓越的希沃大屏助手，K12 教育好帮手。

## 本地开发

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

## 工程化与 CI/CD

已内置以下 GitHub Actions：

- `.github/workflows/ci.yml`
	- Push/PR 自动执行：`analyze`、`test`
	- 自动构建 Windows Release 并上传构建产物（artifact）

- `.github/workflows/release.yml`
	- 当推送 tag（如 `v1.2.3`）时自动构建 Windows Release
	- 自动创建 GitHub Release，并上传 zip 包

- `.github/workflows/version-bump.yml`
	- 手动触发 `workflow_dispatch`，选择 `patch/minor/major`
	- 自动更新 `pubspec.yaml` 版本、写入 `CHANGELOG.md`
	- 自动提交并创建 tag（如 `v1.2.3`），随后触发 release 流程

## 版本管理约定

- 项目采用语义化版本（SemVer）：`MAJOR.MINOR.PATCH`
- `pubspec.yaml` 使用 Flutter 规范：`x.y.z+build`
- 版本升级脚本：`tool/bump_version.dart`

示例：

```bash
dart tool/bump_version.dart --type patch
dart tool/bump_version.dart --type minor
dart tool/bump_version.dart --type major
```

## 发布流程（推荐）

1. 在 GitHub Actions 手动执行 `Version Bump`
2. 选择版本升级类型（patch/minor/major）
3. Workflow 自动提交并打 tag
4. `Release` workflow 自动构建并发布二进制
