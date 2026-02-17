import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

/// 事件监听服务 - 监听指定进程打开的文件并复制到 EventListen 文件夹
class EventListenService extends ChangeNotifier {
  Timer? _timer;
  bool _isListening = false;
  final Map<String, String> _copiedFiles = {}; // sourcePath -> MD5
  final List<String> _logs = [];
  int _copiedCount = 0;
  String _eventListenDir = '';
  List<String> _processNames = [
    'powerpnt.exe',
    'winword.exe',
    'excel.exe',
    'msedge.exe',
  ];

  /// 扫描间隔（秒）
  static const int _scanIntervalSeconds = 5;

  bool get isListening => _isListening;
  List<String> get logs => List.unmodifiable(_logs);
  int get copiedCount => _copiedCount;
  String get eventListenDir => _eventListenDir;
  List<String> get processNames => List.unmodifiable(_processNames);

  /// 配置服务参数
  void configure({
    required String eventListenDir,
    List<String>? processNames,
  }) {
    _eventListenDir = eventListenDir;
    if (processNames != null && processNames.isNotEmpty) {
      final normalized = processNames
          .expand((p) => p.split(RegExp(r'[,，;；\s]+')))
          .map((p) => p.trim().toLowerCase())
          .where((p) => p.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        _processNames = normalized;
      }
    }
  }

  /// 开始监听
  Future<void> startListening() async {
    if (_isListening) return;

    // 确保输出目录存在
    final dir = Directory(_eventListenDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    _isListening = true;
    _addLog('开始监听进程: ${_processNames.join(', ')}');
    _addLog('输出目录: $_eventListenDir');

    // 立即执行一次扫描
    await _scan();

    // 定时扫描
    _timer = Timer.periodic(
      Duration(seconds: _scanIntervalSeconds),
      (_) => _scan(),
    );

    notifyListeners();
  }

  /// 停止监听
  void stopListening() {
    _timer?.cancel();
    _timer = null;
    _isListening = false;
    _addLog('已停止监听');
    notifyListeners();
  }

  /// 清空日志
  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  /// 添加日志
  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(0, 19);
    final logEntry = '[$timestamp] $message';
    _logs.add(logEntry);
    log(logEntry, name: 'EventListenService');
    notifyListeners();
  }

  /// 扫描进程打开的文件
  Future<void> _scan() async {
    try {
      final processNames = _processNames
          .map((p) => p.trim().toLowerCase())
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList();
      if (processNames.isEmpty) {
        return;
      }

      final quotedProcessNames = processNames
          .map((p) => "'${p.replaceAll("'", "''")}'")
          .join(', ');
      final command = "\$targets = @($quotedProcessNames); "
          "Get-CimInstance Win32_Process | "
          "Where-Object { \$_.Name -and (\$targets -contains \$_.Name.ToLower()) } | "
          "Select-Object Name, ProcessId, CommandLine | "
          "ConvertTo-Json -Compress";

      final result = await _runPowerShell(command);

      if (result.exitCode != 0) {
        // 静默失败，不刷屏
        return;
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty) return;

      // 解析 JSON 结果
      dynamic json;
      try {
        json = jsonDecode(output);
      } catch (e) {
        return; // 无匹配进程或 JSON 解析失败
      }

      List<dynamic> processes;
      if (json is List) {
        processes = json;
      } else if (json is Map) {
        processes = [json];
      } else {
        return;
      }

      for (var proc in processes) {
        final name = proc['Name']?.toString() ?? '';
        final cmdLine = proc['CommandLine']?.toString() ?? '';

        if (cmdLine.isEmpty) continue;

        // 从命令行提取文件路径
        final filePaths = _extractFilePaths(cmdLine);

        for (var filePath in filePaths) {
          await _processFile(filePath, name);
        }
      }
    } catch (e) {
      // 避免重复的扫描错误日志刷屏
      log('扫描异常: $e', name: 'EventListenService');
    }
  }

  Future<ProcessResult> _runPowerShell(String command) async {
    try {
      return await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        command,
      ]);
    } on ProcessException {
      return Process.run('pwsh', [
        '-NoProfile',
        '-Command',
        command,
      ]);
    }
  }

  /// 从命令行参数中提取文件路径
  List<String> _extractFilePaths(String commandLine) {
    final paths = <String>[];

    // 匹配带引号的 Windows 文件路径 (如 "C:\Users\...\file.docx")
    final quotedPattern = RegExp(r'"([A-Za-z]:\\[^"]+)"');
    for (var match in quotedPattern.allMatches(commandLine)) {
      final p = match.group(1)!;
      if (_isDocumentFile(p)) {
        paths.add(p);
      }
    }

    // 如果没有引号路径，尝试匹配不带引号的路径（无空格路径）
    if (paths.isEmpty) {
      final unquotedPattern = RegExp(r'([A-Za-z]:\\[^\s"]+\.[a-zA-Z0-9]{2,5})');
      for (var match in unquotedPattern.allMatches(commandLine)) {
        final p = match.group(1)!;
        if (_isDocumentFile(p)) {
          paths.add(p);
        }
      }
    }

    return paths;
  }

  /// 判断是否为文档/媒体文件
  bool _isDocumentFile(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    const docExts = [
      '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
      '.pdf', '.txt', '.rtf', '.csv',
      '.html', '.htm', '.mht', '.mhtml',
      '.odt', '.ods', '.odp',
      '.wps', '.et', '.dps',
      '.png', '.jpg', '.jpeg', '.gif', '.bmp', '.svg', '.webp',
      '.mp4', '.avi', '.mkv', '.wmv', '.flv',
      '.mp3', '.wav', '.wma', '.flac',
      '.zip', '.rar', '.7z',
    ];
    return docExts.contains(ext);
  }

  /// 计算文件的MD5值
  Future<String> _calculateMD5(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final digest = md5.convert(bytes);
      return digest.toString();
    } catch (e) {
      log('计算MD5失败: $e', name: 'EventListenService');
      // 如果计算失败，返回时间戳作为标识
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// 处理检测到的文件 - 复制到 EventListen 文件夹
  Future<void> _processFile(String sourcePath, String processName) async {
    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return;

      // 计算当前文件的MD5
      final currentMD5 = await _calculateMD5(sourcePath);

      // 如果MD5没变则不重复复制
      if (_copiedFiles.containsKey(sourcePath) &&
          _copiedFiles[sourcePath] == currentMD5) {
        return;
      }

      final originalName = path.basenameWithoutExtension(sourcePath);
      final ext = path.extension(sourcePath);
      
      String targetName;
      String targetPath;
      
      // 判断是否为首次保存
      final isFirstSave = !_copiedFiles.containsKey(sourcePath);
      
      if (isFirstSave) {
        // 首次保存使用原始文件名
        targetName = path.basename(sourcePath);
        targetPath = path.join(_eventListenDir, targetName);
      } else {
        // MD5变化，保存新版本，附加时间戳
        final now = DateTime.now();
        final timestamp =
            '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
        targetName = '${originalName}_$timestamp$ext';
        targetPath = path.join(_eventListenDir, targetName);
      }

      // 尝试以只读共享模式复制文件
      bool copied = false;

      // 方法1: 直接 Dart 复制（适用于非独占锁定的文件）
      try {
        await sourceFile.copy(targetPath);
        copied = true;
      } catch (e) {
        log('Dart copy failed, trying PowerShell: $e',
            name: 'EventListenService');
      }

      // 方法2: 使用 PowerShell 以共享读模式复制（适用于被 Office 锁定的文件）
      if (!copied) {
        try {
          final escapedSource = sourcePath.replaceAll("'", "''");
          final escapedTarget = targetPath.replaceAll("'", "''");
          final psResult = await _runPowerShell(
            "\$fs = [IO.File]::Open('$escapedSource', 'Open', 'Read', 'ReadWrite,Delete'); "
            "\$buf = New-Object byte[] \$fs.Length; "
            "[void]\$fs.Read(\$buf, 0, \$fs.Length); "
            "\$fs.Close(); "
            "[IO.File]::WriteAllBytes('$escapedTarget', \$buf)",
          );
          if (psResult.exitCode == 0) {
            copied = true;
          } else {
            _addLog('PowerShell 复制失败: ${psResult.stderr}');
          }
        } catch (e) {
          _addLog('PowerShell 复制异常: $e');
        }
      }

      if (!copied) {
        _addLog('无法复制文件: $originalName (文件可能被独占锁定)');
        return;
      }

      // 将复制的文件设为只读
      try {
        final escapedTarget = targetPath.replaceAll("'", "''");
        await Process.run('attrib', ['+R', escapedTarget]);
      } catch (e) {
        log('设置只读属性失败: $e', name: 'EventListenService');
      }

      // 获取文件大小
      final stat = await sourceFile.stat();
      final fileSize = stat.size;

      // 记录已复制的文件MD5
      _copiedFiles[sourcePath] = currentMD5;
      _copiedCount++;
      
      if (isFirstSave) {
        _addLog('已复制: $originalName ← $processName (${_formatSize(fileSize)})');
      } else {
        _addLog('已保存新版本: $targetName ← $processName (${_formatSize(fileSize)})');
      }

      notifyListeners();
    } catch (e) {
      _addLog('处理文件失败 ($sourcePath): $e');
    }
  }

  /// 格式化文件大小
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
