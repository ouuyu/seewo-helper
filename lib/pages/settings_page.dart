import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_config.dart';
import '../models/setting_item.dart';
import '../services/config_service.dart';
import '../services/autostart_service.dart';

/// 设置页面 - 使用统一的配置项批量渲染
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppConfig _config;
  final Map<String, TextEditingController> _controllers = {};
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _config = context.read<ConfigService>().getConfig();

      // 为文本类型的配置项创建控制器
      for (var setting in _config.settings) {
        if (setting.type == SettingType.text ||
            setting.type == SettingType.path) {
          _controllers[setting.key] = TextEditingController(
            text: setting.value?.toString() ?? '',
          );
        }
      }
    }
  }

  @override
  void dispose() {
    // 释放所有控制器
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 选择文件夹
  Future<void> _selectFolder(SettingItem<String> setting) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: setting.value);
        return AlertDialog(
          title: Text(setting.title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: setting.description ?? setting.title,
              hintText: setting.value,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _controllers[setting.key]?.text = result;
        setting.value = result;
      });
    }
  }

  /// 构建设置项 Widget
  Widget _buildSettingWidget(SettingItem setting) {
    switch (setting.type) {
      case SettingType.text:
        return _buildTextSetting(setting as SettingItem<String>);

      case SettingType.path:
        return _buildPathSetting(setting as SettingItem<String>);

      case SettingType.toggle:
        return _buildToggleSetting(setting as SettingItem<bool>);
    }
  }

  /// 构建文本输入设置项
  Widget _buildTextSetting(SettingItem<String> setting) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (setting.icon != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      setting.icon,
                      size: 24,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                if (setting.icon != null) const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    setting.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controllers[setting.key],
              decoration: InputDecoration(
                hintText: setting.defaultValue,
                helperText: setting.description,
                helperMaxLines: 2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              onChanged: (value) {
                setting.value = value;
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 构建路径选择设置项
  Widget _buildPathSetting(SettingItem<String> setting) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: ListTile(
          leading: setting.icon != null
              ? Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    setting.icon,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : null,
          title: Text(
            setting.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              setting.key == 'configDirectory'
                  ? (_controllers[setting.key]?.text ?? setting.value)
                  : (setting.description ?? setting.value),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          trailing: IconButton(
            icon: Icon(
              setting.key == 'configDirectory' ? Icons.folder_open : Icons.edit,
            ),
            onPressed: () => _selectFolder(setting),
            tooltip: setting.key == 'configDirectory' ? '浏览文件夹' : '编辑',
          ),
        ),
      ),
    );
  }

  /// 构建开关设置项
  Widget _buildToggleSetting(SettingItem<bool> setting) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: ListTile(
          leading: setting.icon != null
              ? Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    setting.icon,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              : null,
          title: Text(
            setting.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          subtitle: setting.description != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    setting.description!,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                )
              : null,
          trailing: Switch(
            value: setting.value,
            onChanged: (value) {
              setState(() {
                setting.value = value;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    final configService = context.read<ConfigService>();

    // 更新文本字段的值
    for (var setting in _config.settings) {
      if ((setting.type == SettingType.text ||
              setting.type == SettingType.path) &&
          _controllers.containsKey(setting.key)) {
        (setting as SettingItem<String>).value = _controllers[setting.key]!.text
            .trim();
      }
    }

    // 验证配置
    for (var setting in _config.settings) {
      if (AppConfig.isWallpaperSettingKey(setting.key)) {
        continue;
      }
      if (setting.validator != null) {
        final error = setting.validator!(setting.value);
        if (error != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }
    }

    // 创建配置目录（如果不存在）
    try {
      final configPath = _config.configDirectory;
      final directory = Directory(configPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法创建目录: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final success = await configService.saveConfig(_config);

    if (success) {
      // 处理开机自启动设置
      if (_config.enableAutostart) {
        // 传递静默启动参数到注册表
        await AutostartService.enableAutostart(
          silentStart: _config.silentStart,
        );
      } else {
        await AutostartService.disableAutostart();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设置已保存'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('设置保存失败'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '设置',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 按分区与分组渲染配置项（根据 showInSettings 属性过滤）
                  for (final section in _config.sections)
                    if (section.showInSettings) ...[
                    _buildSectionHeader(section.title),
                    for (final group in section.groups) ...[
                      _buildGroupHeader(group.title),
                      for (final setting in group.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildSettingWidget(setting),
                        ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // 固定在底部的保存按钮
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text(
                    '保存设置',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
