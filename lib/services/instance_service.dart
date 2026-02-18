import 'dart:developer';
import 'dart:io';
import 'package:path/path.dart' as path;

/// 单实例管理服务：通过文件锁保证同一时刻仅运行一个实例。
class InstanceService {
  static final InstanceService _instance = InstanceService._internal();
  factory InstanceService() => _instance;
  InstanceService._internal();

  RandomAccessFile? _lockHandle;
  File? _lockFile;
  bool _isAcquired = false;
  bool _signalHooked = false;

  bool get isAcquired => _isAcquired;

  String get lockFilePath => path.join(Directory.systemTemp.path, 'seewo_helper.lock');

  Future<bool> acquire() async {
    if (_isAcquired) return true;

    try {
      final file = File(lockFilePath);
      if (!await file.exists()) {
        await file.create(recursive: true);
      }

      final handle = await file.open(mode: FileMode.append);

      try {
        await handle.lock(FileLock.exclusive);
      } on FileSystemException {
        await handle.close();
        return false;
      }

      await handle.truncate(0);
      await handle.writeString(pid.toString());

      _lockFile = file;
      _lockHandle = handle;
      _isAcquired = true;
      _hookSignalsOnce();
      return true;
    } catch (e) {
      log('实例锁获取失败: $e', name: 'InstanceService');
      return true;
    }
  }

  Future<void> release() async {
    if (!_isAcquired) return;

    try {
      await _lockHandle?.unlock();
    } catch (_) {}

    try {
      await _lockHandle?.close();
    } catch (_) {}

    try {
      final file = _lockFile;
      if (file != null && await file.exists()) {
        final content = (await file.readAsString()).trim();
        if (content == pid.toString()) {
          await file.delete();
        }
      }
    } catch (_) {}

    _lockHandle = null;
    _lockFile = null;
    _isAcquired = false;
  }

  void _hookSignalsOnce() {
    if (_signalHooked) return;
    _signalHooked = true;

    void bind(ProcessSignal signal) {
      try {
        signal.watch().listen((_) async {
          await release();
          exit(0);
        });
      } catch (_) {}
    }

    bind(ProcessSignal.sigint);
    bind(ProcessSignal.sigterm);
  }
}
