import 'dart:developer';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// 托盘服务 - 管理系统托盘图标和菜单
class TrayService with TrayListener {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  bool _isInitialized = false;
  bool _isNotifierInitialized = false;

  Future<void> _ensureNotifierInitialized() async {
    if (_isNotifierInitialized) return;
    await localNotifier.setup(
      appName: 'Seewo Helper',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );
    _isNotifierInitialized = true;
  }

  /// 获取图标路径
  String _getIconPath() {
    if (Platform.isWindows) {
      final exeDir = path.dirname(Platform.resolvedExecutable);
      final cwd = Directory.current.path;

      // Try common locations for debug and release builds.
      final possiblePaths = [
        path.join(exeDir, 'data', 'flutter_assets', 'assets', 'app_icon.ico'),
        path.join(exeDir, 'resources', 'app_icon.ico'),
        path.join(cwd, 'assets', 'app_icon.ico'),
        path.join(cwd, 'windows', 'runner', 'resources', 'app_icon.ico'),
      ];

      for (final iconPath in possiblePaths) {
        if (File(iconPath).existsSync()) {
          return iconPath;
        }
      }

      return path.join(cwd, 'windows', 'runner', 'resources', 'app_icon.ico');
    }
    return 'assets/app_icon.png';
  }

  /// 初始化托盘
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _ensureNotifierInitialized();
    } catch (e) {
      log('原生通知初始化失败: $e');
    }

    try {
      final iconPath = _getIconPath();
      await trayManager.setIcon(iconPath);
    } catch (e) {
      log('托盘图标设置失败: $e');
    }
    
    await _updateMenu();
    
    trayManager.addListener(this);
    _isInitialized = true;
  }

  /// 更新托盘菜单
  Future<void> _updateMenu() async {
    Menu menu = Menu(
      items: [
        MenuItem(
          key: 'show',
          label: '显示',
        ),
        MenuItem(
          key: 'hide',
          label: '隐藏',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: '退出',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  /// 显示窗口
  Future<void> showWindow() async {
    await windowManager.setSkipTaskbar(false);
    await windowManager.show();
    await windowManager.focus();
  }

  /// 隐藏窗口
  Future<void> hideWindow({bool showNotification = false}) async {
    await windowManager.setSkipTaskbar(true);
    await windowManager.hide();

    if (showNotification) {
      try {
        await _ensureNotifierInitialized();
        final notification = LocalNotification(
          title: 'Seewo Helper',
          body: '应用已最小化到托盘，点击托盘图标可恢复窗口。',
        );
        await notification.show();
      } catch (e) {
        log('发送原生通知失败: $e');
      }
    }
  }

  /// 退出应用
  Future<void> exitApp() async {
    await windowManager.destroy();
    exit(0);
  }

  @override
  void onTrayIconMouseDown() {
    // 左键点击托盘图标，显示窗口
    showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    // 右键点击，显示菜单
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        showWindow();
        break;
      case 'hide':
        hideWindow();
        break;
      case 'exit':
        exitApp();
        break;
    }
  }

  /// 销毁托盘
  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
    _isInitialized = false;
  }
}
