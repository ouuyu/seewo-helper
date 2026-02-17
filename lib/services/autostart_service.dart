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
      // 如果启用静默启动，添加 --silent 参数
      final command = silentStart ? '"$exePath" --silent' : '"$exePath"';
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'New-ItemProperty -Path "$_regPath" -Name "$_appName" '
            '-Value "$command" -PropertyType String -Force | Out-Null',
      ]);
      return result.exitCode == 0;
    } catch (e) {
      log('Error enabling autostart: $e', name: 'AutostartService');
      return false;
    }
  }

  /// 禁用开机自启
  static Future<bool> disableAutostart() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Remove-ItemProperty -Path "$_regPath" -Name "$_appName" '
            '-ErrorAction SilentlyContinue',
      ]);
      return result.exitCode == 0;
    } catch (e) {
      log('Error disabling autostart: $e', name: 'AutostartService');
      return false;
    }
  }

  /// 检查是否已启用开机自启
  static Future<bool> isAutostartEnabled() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Get-ItemProperty -Path "$_regPath" -Name "$_appName" '
            '-ErrorAction SilentlyContinue | Select-Object -ExpandProperty "$_appName"',
      ]);
      return result.exitCode == 0 &&
          result.stdout.toString().trim().isNotEmpty;
    } catch (e) {
      log('Error checking autostart: $e', name: 'AutostartService');
      return false;
    }
  }
}
