import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import '../models/app_config.dart';

/// 配置服务 - 负责加载和保存应用配置
class ConfigService {
  static const String _defaultConfigDir = r'D:\SeewoHelper';
  static const String _configFileName = 'Config\\Settings.json';

  late AppConfig _config;
  late File _configFile;

  /// 初始化配置服务
  Future<void> initialize() async {
    _loadConfig();
    
    // 确保配置目录存在
    await _ensureConfigDirectoryExists();
    
    // 保存一次配置，确保文件存在
    await saveConfig(_config);
  }

  /// 获取配置文件路径
  String _getConfigFilePath() {
    return '${_config.configDirectory}\\$_configFileName';
  }

  /// 加载配置
  void _loadConfig() {
    try {
      // 首先尝试从默认位置加载配置
      final defaultFile = File('$_defaultConfigDir\\$_configFileName');
      
      if (defaultFile.existsSync()) {
        final content = defaultFile.readAsStringSync();
        _config = AppConfig.fromJsonString(content);
        _configFile = File(_getConfigFilePath());
        log('Loaded config from: ${defaultFile.path}', name: 'ConfigService');
      } else {
        // 配置文件不存在，使用默认配置
        _config = AppConfig();
        _configFile = File(_getConfigFilePath());
        log('Using default config', name: 'ConfigService');
      }
    } catch (e) {
      log('Error loading config: $e', name: 'ConfigService');
      _config = AppConfig();
      _configFile = File(_getConfigFilePath());
    }
  }

  /// 确保配置目录存在
  Future<void> _ensureConfigDirectoryExists() async {
    try {
      final configFileDir = _configFile.parent;
      if (!await configFileDir.exists()) {
        await configFileDir.create(recursive: true);
        log('Created config directory: ${configFileDir.path}', 
            name: 'ConfigService');
      }
    } catch (e) {
      log('Error creating config directory: $e', name: 'ConfigService');
    }
  }

  /// 获取当前配置
  AppConfig getConfig() => _config;

  /// 保存配置
  Future<bool> saveConfig(AppConfig config) async {
    try {
      _config = config;
      
      // 更新配置文件路径（配置目录可能已更改）
      _configFile = File(_getConfigFilePath());
      
      // 确保配置目录存在
      final configFileDir = _configFile.parent;
      if (!await configFileDir.exists()) {
        await configFileDir.create(recursive: true);
      }
      
      // 写入配置文件，格式化 JSON 便于阅读
      final jsonString = const JsonEncoder.withIndent('  ').convert(config.toJson());
      await _configFile.writeAsString(jsonString);
      
      log('Saved config to: ${_configFile.path}', name: 'ConfigService');
      return true;
    } catch (e) {
      log('Error saving config: $e', name: 'ConfigService');
      return false;
    }
  }

  /// 获取配置目录
  String getConfigDirectory() {
    return _config.configDirectory;
  }

  /// 设置配置目录
  Future<bool> setConfigDirectory(String directory) async {
    _config.configDirectory = directory;
    return saveConfig(_config);
  }

  /// 是否启用开机自启
  bool isAutostartEnabled() {
    return _config.enableAutostart;
  }

  /// 设置开机自启
  Future<bool> setAutostartEnabled(bool enabled) async {
    _config.enableAutostart = enabled;
    return saveConfig(_config);
  }

  /// 是否静默启动
  bool isSilentStartEnabled() {
    return _config.silentStart;
  }

  /// 设置静默启动
  Future<bool> setSilentStartEnabled(bool enabled) async {
    _config.silentStart = enabled;
    return saveConfig(_config);
  }

  /// 重置为默认配置
  Future<bool> resetToDefault() async {
    _config.resetToDefault();
    return saveConfig(_config);
  }
}
