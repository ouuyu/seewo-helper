import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as path;

/// 上传记录条目
class UploadRecord {
  final String fileName;
  final String md5;
  final String url;
  final DateTime uploadedAt;
  final int fileSize;

  const UploadRecord({
    required this.fileName,
    required this.md5,
    required this.url,
    required this.uploadedAt,
    required this.fileSize,
  });

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'md5': md5,
        'url': url,
        'uploadedAt': uploadedAt.toIso8601String(),
        'fileSize': fileSize,
      };

  factory UploadRecord.fromJson(Map<String, dynamic> json) => UploadRecord(
        fileName: json['fileName'] as String,
        md5: json['md5'] as String,
        url: json['url'] as String,
        uploadedAt: DateTime.parse(json['uploadedAt'] as String),
        fileSize: json['fileSize'] as int,
      );
}

/// 单个文件的上传状态
enum FileUploadStatus { pending, uploading, success, failed, skipped }

/// 文件上传进度项
class UploadFileItem {
  final String filePath;
  final String fileName;
  final int fileSize;
  final DateTime modifiedAt;
  FileUploadStatus status;
  String? errorMessage;
  String? url;
  String? md5;

  UploadFileItem({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.modifiedAt,
    this.status = FileUploadStatus.pending,
    this.errorMessage,
    this.url,
    this.md5,
  });
}

/// 上传服务 - 将 EventListen 文件夹中的文件上传到服务器
class UploadService extends ChangeNotifier {
  static const String _uploadUrl =
      'https://filesoss.yunzuoye.net/XHFileServer/file/upload/CA107011/';
  static const String _logFileName = r'Config\uploadlog.db';

  bool _isUploading = false;
  final List<UploadFileItem> _fileItems = [];
  final List<String> _logs = [];
  int _uploadedCount = 0;
  int _skippedCount = 0;
  int _failedCount = 0;
  int _totalCount = 0;

  /// 上传记录数据库（内存缓存）
  Map<String, UploadRecord> _uploadRecords = {};

  bool get isUploading => _isUploading;
  List<UploadFileItem> get fileItems => List.unmodifiable(_fileItems);
  List<String> get logs => List.unmodifiable(_logs);
  int get uploadedCount => _uploadedCount;
  int get skippedCount => _skippedCount;
  int get failedCount => _failedCount;
  int get totalCount => _totalCount;
  Map<String, UploadRecord> get uploadRecords =>
      Map.unmodifiable(_uploadRecords);

  // ─── 日志管理 ───

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(0, 19);
    final logEntry = '[$timestamp] $message';
    _logs.add(logEntry);
    log(logEntry, name: 'UploadService');
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  // ─── 上传日志数据库 ───

  /// 获取日志数据库文件路径
  String _getLogDbPath(String configDirectory) {
    return '$configDirectory\\$_logFileName';
  }

  /// 加载上传记录
  Future<void> loadUploadRecords(String configDirectory) async {
    final dbPath = _getLogDbPath(configDirectory);
    final file = File(dbPath);

    if (!await file.exists()) {
      _uploadRecords = {};
      return;
    }

    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        _uploadRecords = {};
        return;
      }
      final json = jsonDecode(content) as Map<String, dynamic>;
      final records = json['files'] as Map<String, dynamic>? ?? {};
      _uploadRecords = records.map(
        (key, value) =>
            MapEntry(key, UploadRecord.fromJson(value as Map<String, dynamic>)),
      );
      _addLog('已加载 ${_uploadRecords.length} 条上传记录');
    } catch (e) {
      log('加载上传记录失败: $e', name: 'UploadService');
      _uploadRecords = {};
      _addLog('上传记录加载失败，将使用空记录');
    }

    notifyListeners();
  }

  /// 保存上传记录
  Future<void> _saveUploadRecords(String configDirectory) async {
    final dbPath = _getLogDbPath(configDirectory);
    final file = File(dbPath);

    try {
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final json = {
        'version': 1,
        'updatedAt': DateTime.now().toIso8601String(),
        'files': _uploadRecords.map(
          (key, record) => MapEntry(key, record.toJson()),
        ),
      };

      final content = const JsonEncoder.withIndent('  ').convert(json);
      await file.writeAsString(content);
    } catch (e) {
      log('保存上传记录失败: $e', name: 'UploadService');
      _addLog('保存上传记录失败: $e');
    }
  }

  /// 记录一次成功的上传
  void _recordUpload(
    String fileName,
    String md5,
    String url,
    int fileSize,
  ) {
    _uploadRecords[fileName] = UploadRecord(
      fileName: fileName,
      md5: md5,
      url: url,
      uploadedAt: DateTime.now(),
      fileSize: fileSize,
    );
  }

  // ─── 文件扫描 ───

  /// 扫描 EventListen 目录中的所有文件
  Future<void> scanFiles(String configDirectory) async {
    final eventListenDir = '$configDirectory\\EventListen';
    final dir = Directory(eventListenDir);

    _fileItems.clear();
    _resetCounters();

    if (!await dir.exists()) {
      _addLog('EventListen 目录不存在: $eventListenDir');
      notifyListeners();
      return;
    }

    try {
      final entities = dir.listSync(recursive: false);
      final files = entities
          .whereType<File>()
          .where((f) => !path.basename(f.path).startsWith('.'))
          .toList();

      files.sort((a, b) {
        final aModified = a.statSync().modified;
        final bModified = b.statSync().modified;
        return bModified.compareTo(aModified);
      });

      if (files.isEmpty) {
        _addLog('EventListen 目录中没有文件');
        notifyListeners();
        return;
      }

      // 加载上传记录以判断跳过
      await loadUploadRecords(configDirectory);

      for (final file in files) {
        final fileName = path.basename(file.path);
        final stat = await file.stat();
        final fileMd5 = await _calculateMD5(file.path);

        // 检查是否已上传（MD5 匹配则跳过）
        final existingRecord = _uploadRecords[fileName];
        final alreadyUploaded =
            existingRecord != null && existingRecord.md5 == fileMd5;

        _fileItems.add(UploadFileItem(
          filePath: file.path,
          fileName: fileName,
          fileSize: stat.size,
          modifiedAt: stat.modified,
          status:
              alreadyUploaded ? FileUploadStatus.skipped : FileUploadStatus.pending,
          md5: fileMd5,
          url: alreadyUploaded ? existingRecord.url : null,
        ));

        if (alreadyUploaded) {
          _skippedCount++;
        }
      }

      _totalCount = _fileItems.length;
      _addLog('扫描完成: 共 $_totalCount 个文件，'
          '$_skippedCount 个已上传（跳过），'
          '${_totalCount - _skippedCount} 个待上传');
    } catch (e) {
      _addLog('扫描文件失败: $e');
    }

    notifyListeners();
  }

  // ─── 上传核心 ───

  /// 开始上传所有待上传文件
  Future<void> startUpload(String configDirectory) async {
    if (_isUploading) return;

    final pendingItems = _fileItems
        .where((item) => item.status == FileUploadStatus.pending)
        .toList();

    if (pendingItems.isEmpty) {
      _addLog('没有待上传的文件');
      return;
    }

    _isUploading = true;
    _addLog('开始上传 ${pendingItems.length} 个文件...');
    notifyListeners();

    for (final item in pendingItems) {
      if (!_isUploading) {
        _addLog('上传已被用户取消');
        break;
      }
      await _uploadFile(item, configDirectory);
    }

    // 保存上传记录到数据库
    await _saveUploadRecords(configDirectory);

    _isUploading = false;
    _addLog('上传完成: 成功 $_uploadedCount，失败 $_failedCount，跳过 $_skippedCount');
    notifyListeners();
  }

  /// 停止上传
  void stopUpload() {
    if (!_isUploading) return;
    _isUploading = false;
    _addLog('正在停止上传...');
    notifyListeners();
  }

  /// 上传单个文件
  Future<void> _uploadFile(
    UploadFileItem item,
    String configDirectory,
  ) async {
    item.status = FileUploadStatus.uploading;
    notifyListeners();

    try {
      final file = File(item.filePath);
      if (!await file.exists()) {
        item.status = FileUploadStatus.failed;
        item.errorMessage = '文件不存在';
        _failedCount++;
        _addLog('上传失败 [${item.fileName}]: 文件不存在');
        notifyListeners();
        return;
      }

      final fileMd5 = item.md5 ?? await _calculateMD5(item.filePath);

      // 构建忽略证书校验的 HttpClient
      final ioClient = HttpClient()
        ..badCertificateCallback = (_, _, _) => true;
      final client = IOClient(ioClient);

      // 构建 multipart 请求
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.headers['xuehai-md5'] = fileMd5;
      request.files.add(
        await http.MultipartFile.fromPath('files', item.filePath),
      );

      // 发送请求
      final streamedResponse = await client.send(request).timeout(
            const Duration(minutes: 5),
          );
      final response = await http.Response.fromStream(streamedResponse);
      client.close();

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final status = body['status'] as int?;

        if (status == 1000) {
          final fileId = (body['uploadFileDTO']
              as Map<String, dynamic>?)?['fileId'] as String?;

          item.status = FileUploadStatus.success;
          item.url = fileId;
          item.md5 = fileMd5;
          _uploadedCount++;

          // 记录到数据库
          _recordUpload(item.fileName, fileMd5, fileId ?? '', item.fileSize);

          _addLog('上传成功 [${item.fileName}] → ${fileId ?? '无URL'}');
        } else {
          final message = body['message'] as String? ?? '未知错误';
          item.status = FileUploadStatus.failed;
          item.errorMessage = message;
          _failedCount++;
          _addLog('上传失败 [${item.fileName}]: $message');
        }
      } else {
        item.status = FileUploadStatus.failed;
        item.errorMessage = 'HTTP ${response.statusCode}';
        _failedCount++;
        _addLog('上传失败 [${item.fileName}]: HTTP ${response.statusCode}');
      }
    } on TimeoutException {
      item.status = FileUploadStatus.failed;
      item.errorMessage = '上传超时';
      _failedCount++;
      _addLog('上传超时 [${item.fileName}]');
    } catch (e) {
      item.status = FileUploadStatus.failed;
      item.errorMessage = e.toString();
      _failedCount++;
      _addLog('上传异常 [${item.fileName}]: $e');
    }

    notifyListeners();
  }

  // ─── 工具方法 ───

  /// 计算文件 MD5
  Future<String> _calculateMD5(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      return md5.convert(bytes).toString();
    } catch (e) {
      log('计算 MD5 失败: $e', name: 'UploadService');
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// 重置计数器
  void _resetCounters() {
    _uploadedCount = 0;
    _skippedCount = 0;
    _failedCount = 0;
    _totalCount = 0;
  }

  /// 重置所有状态（刷新用）
  void reset() {
    _fileItems.clear();
    _resetCounters();
    _isUploading = false;
    notifyListeners();
  }

  /// 格式化文件大小
  static String formatSize(int bytes) {
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
    stopUpload();
    super.dispose();
  }
}
