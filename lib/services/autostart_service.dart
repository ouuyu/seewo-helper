// ignore_for_file: unused_local_variable, unused_field

import 'dart:developer';
import 'dart:io';

/// Windows 开机自启动服务
class AutostartService {
  static const _regPath =
      r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _appName = 'SeewoHelper';

  /// 启用开机自启（带静默启动参数）
  static Future<bool> enableAutostart({bool silentStart = false}) async {
    try {
      final exePath = Platform.resolvedExecutable;
      // 构造启动命令，确保路径被双引号包裹以处理空格
      final command = silentStart ? '"$exePath" --silent' : '"$exePath"';
      
      // 使用 reg.exe 设置注册表项，比 PowerShell 处理引导引号更稳健
      final result = await Process.run('reg', [
        'add',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run',
        '/v',
        _appName,
        '/t',
        'REG_SZ',
        '/d',
        command,
        '/f',
      ]);
      
      if (result.exitCode == 0) {
        log('已启用开机自启: $command', name: 'AutostartService');
        return true;
      } else {
        log('启用开机自启失败: ${result.stderr}', name: 'AutostartService');
        return false;
      }
    } catch (e) {
      log('Error enabling autostart: $e', name: 'AutostartService');
      return false;
    }
  }

  /// 禁用开机自启
  static Future<bool> disableAutostart() async {
    try {
      // 使用 reg.exe 删除注册表项
      final result = await Process.run('reg', [
        'delete',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run',
        '/v',
        _appName,
        '/f',
      ]);
      
      // 注意：如果键本来就不存在，reg delete 返回 1，但这不代表操作出错（因为目标已达成）
      log('已尝试禁用开机自启', name: 'AutostartService');
      return true;
    } catch (e) {
      log('Error disabling autostart: $e', name: 'AutostartService');
      return false;
    }
  }

  /// 检查是否已启用开机自启
  static Future<bool> isAutostartEnabled() async {
    try {
      final result = await Process.run('reg', [
        'query',
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run',
        '/v',
        _appName,
      ]);
      return result.exitCode == 0;
    } catch (e) {
      log('Error checking autostart state: $e', name: 'AutostartService');
      return false;
    }
  }
}
