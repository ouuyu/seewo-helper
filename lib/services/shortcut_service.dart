import 'dart:developer';
import 'dart:io';

/// Windows 快捷方式服务
class ShortcutService {
  /// 创建开始菜单快捷方式（覆盖操作）
  static Future<bool> createStartMenuShortcut() async {
    if (!Platform.isWindows) return false;

    try {
      final exePath = Platform.resolvedExecutable;
      final programsPath = '${Platform.environment['APPDATA']}\\Microsoft\\Windows\\Start Menu\\Programs';
      final startMenuPath = '$programsPath\\Seewo Helper.lnk';
      final oldStartMenuPath = '$programsPath\\seewo_helper.lnk';

      // 清理可能存在的旧名快捷方式
      try {
        final oldFile = File(oldStartMenuPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
          log('已清理旧版快捷方式: $oldStartMenuPath', name: 'ShortcutService');
        }
      } catch (_) {}

      // 使用PowerShell创建快捷方式，使用单引号包裹路径以处理空格
      final script = '''
\$WshShell = New-Object -comObject WScript.Shell
\$Shortcut = \$WshShell.CreateShortcut('$startMenuPath')
\$Shortcut.TargetPath = '$exePath'
\$Shortcut.WorkingDirectory = '${Directory(exePath).parent.path}'
\$Shortcut.IconLocation = '$exePath,0'
\$Shortcut.Description = 'Seewo Helper'
\$Shortcut.Save()
''';

      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', script],
      );

      if (result.exitCode != 0) {
        log('创建开始菜单快捷方式失败: ${result.stderr}',
            name: 'ShortcutService');
        return false;
      } else {
        log('开始菜单快捷方式已更新: $exePath', name: 'ShortcutService');
        return true;
      }
    } catch (e) {
      log('创建开始菜单快捷方式时出错: $e', name: 'ShortcutService');
      return false;
    }
  }

  /// 删除开始菜单快捷方式
  static Future<bool> removeStartMenuShortcut() async {
    if (!Platform.isWindows) return false;

    try {
      final programsPath = '${Platform.environment['APPDATA']}\\Microsoft\\Windows\\Start Menu\\Programs';
      final startMenuPath = '$programsPath\\Seewo Helper.lnk';
      final oldStartMenuPath = '$programsPath\\seewo_helper.lnk';

      final file = File(startMenuPath);
      if (await file.exists()) {
        await file.delete();
      }
      
      final oldFile = File(oldStartMenuPath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
      
      log('开始菜单快捷方式已成功清理', name: 'ShortcutService');
      return true;
    } catch (e) {
      log('删除开始菜单快捷方式时出错: $e', name: 'ShortcutService');
      return false;
    }
  }

  /// 检查开始菜单快捷方式是否存在
  static Future<bool> startMenuShortcutExists() async {
    if (!Platform.isWindows) return false;

    try {
      final programsPath = '${Platform.environment['APPDATA']}\\Microsoft\\Windows\\Start Menu\\Programs';
      final startMenuPath = '$programsPath\\Seewo Helper.lnk';
      return await File(startMenuPath).exists();
    } catch (e) {
      log('检查开始菜单快捷方式时出错: $e', name: 'ShortcutService');
      return false;
    }
  }
}
