import 'dart:convert';
import 'package:flutter/material.dart';
import 'setting_item.dart';

/// 应用配置模型 - 使用统一的配置项管理
class AppConfig {
  static const defaultConfigDir = r'D:\SeewoHelper';
  static const wallpaperSectionTitle = '壁纸';
  static const Set<String> wallpaperSettingKeys = {
    'wallpaperAutoRefresh',
    'wallpaperAutoSet',
    'wallpaperShowCountdown',
    'wallpaperCountdownDate',
    'wallpaperCountdownEventName',
    'wallpaperResolution',
    'wallpaperMarket',
    'wallpaperIndex',
    'wallpaperSaveDirectory',
  };

  static bool isWallpaperSettingKey(String key) {
    return wallpaperSettingKeys.contains(key);
  }

  /// 设置分区
  late final List<SettingSection> sections;

  /// 所有配置项（扁平化）
  late final List<SettingItem> settings;

  AppConfig({Map<String, dynamic>? initialData}) {
    // 初始化设置分区与分组
    sections = [
      SettingSection(
        title: '系统设置',
        groups: [
          SettingGroup(
            title: '配置存储',
            items: [
              SettingItem<String>(
                key: 'configDirectory',
                title: '配置目录',
                description: '应用配置文件保存的目录路径',
                type: SettingType.path,
                defaultValue: defaultConfigDir,
                icon: Icons.folder,
                validator: (dynamic value) {
                  if ((value as String).isEmpty) return '配置目录路径不能为空';
                  return null;
                },
              ),
            ],
          ),
          SettingGroup(
            title: '启动行为',
            items: [
              SettingItem<bool>(
                key: 'enableAutostart',
                title: '启用开机自启动',
                description: '应用将在系统启动时自动运行',
                type: SettingType.toggle,
                defaultValue: false,
                icon: Icons.power_settings_new,
              ),
              SettingItem<bool>(
                key: 'silentStart',
                title: '启用静默启动',
                description: '启动时隐藏主窗口，只在托盘显示',
                type: SettingType.toggle,
                defaultValue: false,
                icon: Icons.visibility_off,
              ),
            ],
          ),
        ],
      ),
      SettingSection(
        title: '事件监听',
        groups: [
          SettingGroup(
            title: '监听开关',
            items: [
              SettingItem<bool>(
                key: 'enableEventListen',
                title: '启用事件监听',
                description: '启动时自动开始监听指定进程打开的文件',
                type: SettingType.toggle,
                defaultValue: false,
                icon: Icons.hearing,
              ),
            ],
          ),
          SettingGroup(
            title: '监听目标',
            items: [
              SettingItem<String>(
                key: 'eventListenProcesses',
                title: '监听进程列表',
                description: '要监听的进程名称',
                type: SettingType.path,
                defaultValue: 'powerpnt.exe,winword.exe,excel.exe,msedge.exe',
                icon: Icons.apps,
              ),
            ],
          ),
        ],
      ),
      SettingSection(
        title: wallpaperSectionTitle,
        showInSettings: false, // 壁纸在壁纸页面管理，不在设置页面显示
        groups: [
          SettingGroup(
            title: '更新与应用',
            items: [
              SettingItem<bool>(
                key: 'wallpaperAutoRefresh',
                title: '启动时更新壁纸',
                description: '启动应用时从必应获取最新壁纸',
                type: SettingType.toggle,
                defaultValue: true,
                icon: Icons.refresh,
              ),
              SettingItem<bool>(
                key: 'wallpaperAutoSet',
                title: '自动设置为桌面壁纸',
                description: '更新后自动设置为系统桌面壁纸',
                type: SettingType.toggle,
                defaultValue: false,
                icon: Icons.wallpaper,
              ),
            ],
          ),
          SettingGroup(
            title: '倒计时',
            items: [
              SettingItem<bool>(
                key: 'wallpaperShowCountdown',
                title: '显示倒计时',
                description: '在壁纸页面显示倒数日',
                type: SettingType.toggle,
                defaultValue: true,
                icon: Icons.timer,
              ),
              SettingItem<String>(
                key: 'wallpaperCountdownDate',
                title: '倒计时目标日期',
                description: '格式: YYYY-MM-DD (可留空)',
                type: SettingType.text,
                defaultValue: '',
                icon: Icons.event,
                validator: (dynamic value) {
                  final text = (value as String).trim();
                  if (text.isEmpty) return null;
                  final match = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                  if (!match.hasMatch(text)) {
                    return '倒计时日期格式应为 YYYY-MM-DD';
                  }
                  return null;
                },
              ),
              SettingItem<String>(
                key: 'wallpaperCountdownEventName',
                title: '倒计时事件名称',
                description: '例如: 高考、生日、毕业 等',
                type: SettingType.text,
                defaultValue: '重要日子',
                icon: Icons.celebration,
              ),
            ],
          ),
          SettingGroup(
            title: '请求参数',
            items: [
              SettingItem<String>(
                key: 'wallpaperResolution',
                title: '壁纸分辨率',
                description: '例如 UHD / 1920x1080',
                type: SettingType.text,
                defaultValue: 'UHD',
                icon: Icons.hd,
              ),
              SettingItem<String>(
                key: 'wallpaperMarket',
                title: '市场',
                description: '例如 zh-CN / en-US',
                type: SettingType.text,
                defaultValue: 'zh-CN',
                icon: Icons.public,
              ),
              SettingItem<String>(
                key: 'wallpaperIndex',
                title: '索引',
                description: '0 表示最新壁纸',
                type: SettingType.text,
                defaultValue: '0',
                icon: Icons.format_list_numbered,
                validator: (dynamic value) {
                  final text = (value as String).trim();
                  if (text.isEmpty) return '索引不能为空';
                  final parsed = int.tryParse(text);
                  if (parsed == null || parsed < 0) {
                    return '索引必须是非负整数';
                  }
                  return null;
                },
              ),
            ],
          ),
          SettingGroup(
            title: '存储',
            items: [
              SettingItem<String>(
                key: 'wallpaperSaveDirectory',
                title: '壁纸保存目录',
                description: '下载的壁纸保存位置',
                type: SettingType.path,
                defaultValue: '$defaultConfigDir\\Wallpapers',
                icon: Icons.folder,
              ),
            ],
          ),
        ],
      ),
      SettingSection(
        title: '热点',
        showInSettings: false, // 热点在热点页面管理，不在设置页面显示
        groups: [
          SettingGroup(
            title: '热点配置',
            items: [
              SettingItem<String>(
                key: 'hotspotSSID',
                title: '网络名称 (SSID)',
                description: 'WiFi 热点的名称',
                type: SettingType.text,
                defaultValue: 'seewo helper',
                icon: Icons.wifi,
                validator: (dynamic value) {
                  final text = (value as String).trim();
                  if (text.isEmpty) return '网络名称不能为空';
                  return null;
                },
              ),
              SettingItem<String>(
                key: 'hotspotPassword',
                title: '密码',
                description: '热点连接密码，至少 8 位字符',
                type: SettingType.text,
                defaultValue: '11111111',
                icon: Icons.lock,
                validator: (dynamic value) {
                  final text = (value as String).trim();
                  if (text.isEmpty) return '密码不能为空';
                  if (text.length < 8) return '密码至少需要 8 位字符';
                  return null;
                },
              ),
              SettingItem<String>(
                key: 'hotspotIPAddress',
                title: 'IP 地址',
                description: '热点网络的 IP 地址',
                type: SettingType.text,
                defaultValue: '192.168.1.233',
                icon: Icons.location_on,
                validator: (dynamic value) {
                  final text = (value as String).trim();
                  if (text.isEmpty) return 'IP 地址不能为空';
                  // 验证 IP 地址格式
                  final ipPattern = RegExp(
                    r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
                  );
                  if (!ipPattern.hasMatch(text)) {
                    return 'IP 地址格式不正确';
                  }
                  return null;
                },
              ),
            ],
          ),
          SettingGroup(
            title: '自动启动',
            items: [
              SettingItem<bool>(
                key: 'enableHotspotAutoStart',
                title: '开机自动启动热点',
                description: '应用启动时自动打开 WiFi 热点',
                type: SettingType.toggle,
                defaultValue: false,
                icon: Icons.power_settings_new,
              ),
            ],
          ),
        ],
      ),
    ];

    settings = [
      for (final section in sections)
        for (final group in section.groups) ...group.items,
    ];

    // 从初始数据加载值
    if (initialData != null) {
      fromJson(initialData);
    }
  }

  /// 获取配置项
  SettingItem<T>? getSetting<T>(String key) {
    try {
      return settings.firstWhere((s) => s.key == key) as SettingItem<T>;
    } catch (e) {
      return null;
    }
  }

  /// 获取配置值
  T? getValue<T>(String key) {
    return getSetting<T>(key)?.value;
  }

  /// 设置配置值
  void setValue<T>(String key, T value) {
    final setting = getSetting<T>(key);
    if (setting != null) {
      setting.value = value;
    }
  }

  // 便捷访问器
  String get configDirectory =>
      getValue<String>('configDirectory') ?? defaultConfigDir;
  set configDirectory(String value) => setValue('configDirectory', value);

  bool get enableAutostart => getValue<bool>('enableAutostart') ?? false;
  set enableAutostart(bool value) => setValue('enableAutostart', value);

  bool get silentStart => getValue<bool>('silentStart') ?? false;
  set silentStart(bool value) => setValue('silentStart', value);

  bool get enableEventListen => getValue<bool>('enableEventListen') ?? false;
  set enableEventListen(bool value) => setValue('enableEventListen', value);

  String get eventListenProcesses =>
      getValue<String>('eventListenProcesses') ??
      'powerpnt.exe,winword.exe,excel.exe,msedge.exe';
  set eventListenProcesses(String value) =>
      setValue('eventListenProcesses', value);

  bool get wallpaperAutoRefresh =>
      getValue<bool>('wallpaperAutoRefresh') ?? true;
  set wallpaperAutoRefresh(bool value) =>
      setValue('wallpaperAutoRefresh', value);

  bool get wallpaperAutoSet => getValue<bool>('wallpaperAutoSet') ?? false;
  set wallpaperAutoSet(bool value) => setValue('wallpaperAutoSet', value);

  bool get wallpaperShowCountdown =>
      getValue<bool>('wallpaperShowCountdown') ?? true;
  set wallpaperShowCountdown(bool value) =>
      setValue('wallpaperShowCountdown', value);

  String get wallpaperCountdownDate =>
      getValue<String>('wallpaperCountdownDate') ?? '';
  set wallpaperCountdownDate(String value) =>
      setValue('wallpaperCountdownDate', value);

  String get wallpaperCountdownEventName =>
      getValue<String>('wallpaperCountdownEventName') ?? '重要日子';
  set wallpaperCountdownEventName(String value) =>
      setValue('wallpaperCountdownEventName', value);

  String get wallpaperResolution =>
      getValue<String>('wallpaperResolution') ?? 'UHD';
  set wallpaperResolution(String value) =>
      setValue('wallpaperResolution', value);

  String get wallpaperMarket => getValue<String>('wallpaperMarket') ?? 'zh-CN';
  set wallpaperMarket(String value) => setValue('wallpaperMarket', value);

  String get wallpaperIndex => getValue<String>('wallpaperIndex') ?? '0';
  set wallpaperIndex(String value) => setValue('wallpaperIndex', value);

  String get wallpaperSaveDirectory =>
      getValue<String>('wallpaperSaveDirectory') ??
      '$defaultConfigDir\\Wallpapers';
  set wallpaperSaveDirectory(String value) =>
      setValue('wallpaperSaveDirectory', value);

  // 热点配置访问器
  String get hotspotSSID => getValue<String>('hotspotSSID') ?? 'seewo helper';
  set hotspotSSID(String value) => setValue('hotspotSSID', value);

  String get hotspotPassword =>
      getValue<String>('hotspotPassword') ?? '11111111';
  set hotspotPassword(String value) => setValue('hotspotPassword', value);

  String get hotspotIPAddress =>
      getValue<String>('hotspotIPAddress') ?? '192.168.1.233';
  set hotspotIPAddress(String value) => setValue('hotspotIPAddress', value);

  bool get enableHotspotAutoStart =>
      getValue<bool>('enableHotspotAutoStart') ?? false;
  set enableHotspotAutoStart(bool value) =>
      setValue('enableHotspotAutoStart', value);

  /// 从 JSON 加载
  void fromJson(Map<String, dynamic> json) {
    for (var setting in settings) {
      if (json.containsKey(setting.key)) {
        setting.fromJson(json[setting.key]);
      }
    }
  }

  /// 从 JSON 字符串创建
  factory AppConfig.fromJsonString(String s) {
    final json = jsonDecode(s) as Map<String, dynamic>;
    return AppConfig(initialData: json);
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    for (var setting in settings) {
      map[setting.key] = setting.toJson();
    }
    return map;
  }

  /// 转换为 JSON 字符串
  String toJsonString() => jsonEncode(toJson());

  /// 重置所有配置为默认值
  void resetToDefault() {
    for (var setting in settings) {
      setting.reset();
    }
  }

  /// 复制配置
  AppConfig copyWith({Map<String, dynamic>? updates}) {
    final json = toJson();
    if (updates != null) {
      json.addAll(updates);
    }
    return AppConfig(initialData: json);
  }

  @override
  String toString() => 'AppConfig${toJson()}';
}
