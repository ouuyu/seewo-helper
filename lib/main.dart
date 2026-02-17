import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'services/config_service.dart';
import 'services/event_listen_service.dart';
import 'services/tray_service.dart';
import 'services/wallpaper_service.dart';
import 'services/hotspot_service.dart';
import 'services/upload_service.dart';
import 'pages/home_page.dart';
import 'pages/event_listen_page.dart';
import 'pages/settings_page.dart';
import 'pages/settings_page.dart';
import 'pages/wallpaper_page.dart';
import 'pages/hotspot_page.dart';
import 'pages/upload_page.dart';

/// 检查是否已经有实例运行
bool _isSingleInstance() {
  try {
    final tempDir = Directory.systemTemp.path;
    final lockFile = File(path.join(tempDir, 'seewo_helper.lock'));
    
    if (lockFile.existsSync()) {
      return false; // 锁文件存在，认为已有实例
    }
    
    // 创建锁文件
    lockFile.writeAsStringSync('running');
    return true;
  } catch (e) {
    // 如果出错，允许运行
    return true;
  }
}

/// 创建开始菜单快捷方式
Future<void> _createStartMenuShortcut() async {
  if (!Platform.isWindows) return;
  
  try {
    final exePath = Platform.resolvedExecutable;
    final startMenuPath = '${Platform.environment['APPDATA']}\\Microsoft\\Windows\\Start Menu\\Programs\\Seewo Helper.lnk';
    
    // 使用PowerShell创建快捷方式
    final script = '''
\$WshShell = New-Object -comObject WScript.Shell
\$Shortcut = \$WshShell.CreateShortcut("$startMenuPath")
\$Shortcut.TargetPath = "$exePath"
\$Shortcut.WorkingDirectory = "${Directory(exePath).parent.path}"
\$Shortcut.IconLocation = "$exePath,0"
\$Shortcut.Description = "Seewo Helper"
\$Shortcut.Save()
''';
    
    final result = await Process.run('powershell', ['-Command', script], runInShell: true);
    if (result.exitCode != 0) {
      print('创建开始菜单快捷方式失败: ${result.stderr}');
    } else {
      print('开始菜单快捷方式创建成功');
    }
  } catch (e) {
    print('创建开始菜单快捷方式时出错: $e');
  }
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 检查单实例
  if (!_isSingleInstance()) {
    print('Seewo Helper 已在运行，只允许一个实例。');
    return;
  }

  // 创建开始菜单快捷方式（覆盖操作）
  await _createStartMenuShortcut();

  // 检查是否为静默启动（优先检查启动参数）
  final isSilentStart = args.contains('--silent');

  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  // 初始化配置服务
  final configService = ConfigService();
  await configService.initialize();
  final config = configService.getConfig();

  // 使用启动参数或配置决定是否隐藏窗口
  final shouldHideWindow = isSilentStart || config.silentStart;

  // 窗口配置
  final windowOptions = WindowOptions(
    size: const Size(1000, 700),
    minimumSize: const Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: shouldHideWindow,  // 静默启动时跳过任务栏
    titleBarStyle: TitleBarStyle.normal,
    title: 'Seewo Helper',
  );

  // 完成窗口初始化（不自动显示）
  await windowManager.waitUntilReadyToShow(windowOptions);
  
  // 如果是静默启动，立即隐藏窗口（防止窗口短暂显示）
  if (shouldHideWindow) {
    await windowManager.hide();
  }
  
  // 初始化托盘服务（在窗口显示/隐藏之前初始化托盘）
  final trayService = TrayService();
  await trayService.initialize();
  
  // 初始化事件监听服务
  final eventListenService = EventListenService();
  final wallpaperService = WallpaperService();
  final hotspotService = HotspotService();
  final uploadService = UploadService();

  // 初始化热点服务
  await hotspotService.initialize(config);

  // 如果配置了自动启动事件监听，则立即开始
  if (config.enableEventListen) {
    final eventListenDir = '${config.configDirectory}\\EventListen';
    final processes = config.eventListenProcesses
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    eventListenService.configure(
      eventListenDir: eventListenDir,
      processNames: processes,
    );
    eventListenService.startListening();
  }

  // 先启动应用
  runApp(
    MyApp(
      configService: configService,
      eventListenService: eventListenService,
      wallpaperService: wallpaperService,
      hotspotService: hotspotService,
      uploadService: uploadService,
      shouldHideWindow: shouldHideWindow,  // 传递静默启动标志
    ),
  );
}

class MyApp extends StatelessWidget {
  final ConfigService configService;
  final EventListenService eventListenService;
  final WallpaperService wallpaperService;
  final HotspotService hotspotService;
  final UploadService uploadService;
  final bool shouldHideWindow;

  const MyApp({
    super.key,
    required this.configService,
    required this.eventListenService,
    required this.wallpaperService,
    required this.hotspotService,
    required this.uploadService,
    required this.shouldHideWindow,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ConfigService>.value(value: configService),
        ChangeNotifierProvider<EventListenService>.value(
          value: eventListenService,
        ),
        ChangeNotifierProvider<WallpaperService>.value(value: wallpaperService),
        ChangeNotifierProvider<HotspotService>.value(value: hotspotService),
        ChangeNotifierProvider<UploadService>.value(value: uploadService),
      ],
      child: MaterialApp(
        title: 'Seewo Helper',
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: MainLayout(shouldHideWindow: shouldHideWindow),
      ),
    );
  }
}

/// 主布局 - 包含侧栏和内容区域
class MainLayout extends StatefulWidget {
  final bool shouldHideWindow;
  
  const MainLayout({super.key, required this.shouldHideWindow});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WindowListener {
  int _selectedIndex = 0;

  final List<({String label, IconData icon, Widget page})> _pages = [
    (label: '首页', icon: Icons.home, page: const HomePage()),
    (label: '监听', icon: Icons.hearing, page: const EventListenPage()),
    (label: '壁纸', icon: Icons.wallpaper, page: const WallpaperPage()),
    (label: '热点', icon: Icons.wifi_tethering, page: const HotspotPage()),
    (label: '上传', icon: Icons.cloud_upload, page: const UploadPage()),
    (label: '设置', icon: Icons.settings, page: const SettingsPage()),
  ];

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
    
    // 在 UI 构建后立即决定窗口显示状态
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.shouldHideWindow) {
        // 静默启动：确保窗口隐藏
        await windowManager.hide();
        await windowManager.setSkipTaskbar(true);
      } else {
        // 正常启动：显示窗口
        await windowManager.show();
        await windowManager.focus();
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // 点击关闭按钮时，隐藏窗口而不是退出
    if (await windowManager.isPreventClose()) {
      await TrayService().hideWindow(showNotification: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 侧栏
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: _pages
                .map(
                  (page) => NavigationRailDestination(
                    icon: Icon(page.icon),
                    label: Text(page.label),
                  ),
                )
                .toList(),
          ),
          // 分隔线
          const VerticalDivider(thickness: 1, width: 1),
          // 内容区域
          Expanded(child: _pages[_selectedIndex].page),
        ],
      ),
    );
  }
}
