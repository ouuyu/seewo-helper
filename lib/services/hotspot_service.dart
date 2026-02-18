import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/app_config.dart';

/// 热点状态枚举
enum HotspotStatus {
  stopped, // 已停止
  starting, // 正在启动
  started, // 已启动
  stopping, // 正在停止
  error, // 错误状态
}

/// Windows 热点管理服务 (Mobile Hotspot Version)
class HotspotService extends ChangeNotifier {
  HotspotStatus _status = HotspotStatus.stopped;
  String? _errorMessage;
  Timer? _statusCheckTimer;

  // 热点配置
  String _ssid = 'seewo_helper';
  String _password = 'password12345678';
  String _ipAddress = ''; // Mobile Hotspot 模式下由系统自动分配，此处仅作展示

  HotspotStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String get ssid => _ssid;
  String get password => _password;
  String get ipAddress => _ipAddress;

  /// 初始化服务
  Future<void> initialize(AppConfig config) async {
    _ssid = config.hotspotSSID;
    _password = config.hotspotPassword;
    // _ipAddress 不再强行设置为静态 IP，而是读取系统分配的

    // 检查当前状态
    await checkStatus();

    // 自动启动
    if (config.enableHotspotAutoStart) {
      await startHotspot();
    }

    // 定时检查状态
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => checkStatus(),
    );
  }

  /// 检查热点状态
  Future<void> checkStatus() async {
    try {
      final state = await _getMobileHotspotState();
      
      if (state == 'On') {
        if (_status != HotspotStatus.started) {
          _status = HotspotStatus.started;
          _errorMessage = null;
          await _refreshIpAddress(); // 尝试获取 IP
          notifyListeners();
        }
      } else {
        // 如果系统报告关闭，且当前并没有正在启动/停止的操作，则更新为停止
        if (_status != HotspotStatus.stopped &&
            _status != HotspotStatus.starting &&
            _status != HotspotStatus.stopping) {
          _status = HotspotStatus.stopped;
          _errorMessage = null;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('检查热点状态失败: $e');
    }
  }

  /// 启动热点
  Future<bool> startHotspot() async {
    if (_status == HotspotStatus.starting) return false;
    if (_status == HotspotStatus.started) {
      // 已经启动，检查配置是否一致，一致则无需重启
      final currentConfig = await _getMobileHotspotConfig();
      if (currentConfig != null && currentConfig['ssid'] == _ssid && currentConfig['password'] == _password) {
         return true;
      }
      // 不一致则需要重启，继续执行
    }

    _status = HotspotStatus.starting;
    _errorMessage = null;
    notifyListeners();

    try {
      // 尝试启用
      final result = await _enableMobileHotspot(_ssid, _password);
      
      if (result.success) {
        _status = HotspotStatus.started;
        _errorMessage = null;
        await _refreshIpAddress();
        notifyListeners();
        return true;
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
      _status = HotspotStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      debugPrint('启动热点失败: $e');
      return false;
    }
  }

  /// 停止热点
  Future<bool> stopHotspot() async {
    if (_status == HotspotStatus.stopping || _status == HotspotStatus.stopped) {
      return false;
    }

    _status = HotspotStatus.stopping;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _disableMobileHotspot();
      if (result.success) {
        _status = HotspotStatus.stopped;
        notifyListeners();
        return true;
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
      _status = HotspotStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      debugPrint('停止热点失败: $e');
      return false;
    }
  }

  /// 更新配置
  Future<void> updateConfiguration({
    String? ssid,
    String? password,
    String? ipAddress,
  }) async {
    bool configChanged = false;
    if (ssid != null && ssid != _ssid) {
      _ssid = ssid;
      configChanged = true;
    }
    if (password != null && password != _password) {
      _password = password;
      configChanged = true;
    }
    // ipAddress 忽略，不支持手动设置 Mobile Hotspot IP

    notifyListeners();

    // 如果配置变更且当前已启动，则重启以应用新配置
    if (configChanged && _status == HotspotStatus.started) {
      await stopHotspot();
      // 等待一点时间确保系统状态同步
      await Future.delayed(const Duration(milliseconds: 1000));
      await startHotspot();
    }
  }

  /// 尝试获取热点适配器 IP
  Future<void> _refreshIpAddress() async {
    try {
      // 这里使用简单的逻辑：Mobile Hotspot 通常会创建一个 "Microsoft Wi-Fi Direct Virtual Adapter"
      // 或者类似的接口，由于名称不固定，这里只运行 ipconfig 查找大致信息，暂不强求精确匹配
      // 为简化，暂设置为空或默认提示
      _ipAddress = '由系统自动分配';
      notifyListeners();
    } catch (e) {
      debugPrint('获取 IP 失败: $e');
    }
  }

  // --- PowerShell Helpers ---

  Future<String?> _getMobileHotspotState() async {
    final script = r'''
$ErrorActionPreference = 'Stop';
$profile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile();
if ($null -eq $profile) {
  Write-Output 'STATE:NoInternetProfile';
  exit 0;
}
try {
  $manager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($profile);
  Write-Output ('STATE:' + $manager.TetheringOperationalState);
} catch {
  Write-Output ('STATE:Error ' + $_.Exception.Message);
}
''';
    final result = await _runPowerShell(script);
    if (result.exitCode != 0) return null;
    return _parseKeyValue(result.stdout, 'STATE');
  }

  Future<Map<String, String>?> _getMobileHotspotConfig() async {
     // 获取当前配置的 SSID 和 密码，用于对比
     // 暂未实现，直接返回 null 让 toggle 逻辑判断
     return null;
  }

  Future<HotspotOperationResult> _enableMobileHotspot(String ssid, String key) async {
    final escapedSsid = _escape(ssid);
    final escapedKey = _escape(key);
    
    final script = r'''
$ErrorActionPreference = 'Stop';
try {
  $profile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile();
  if ($null -eq $profile) {
    throw '未检测到活跃的 Internet 连接 (Profile)，无法开启移动热点共享。';
  }
  
  $manager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($profile);
  
  # 1. 检查并配置 SSID/Password
  $currentConfig = $manager.GetCurrentAccessPointConfiguration();
  $newSsid = '___SSID___';
  $newPass = '___KEY___';
  
  if ($currentConfig.Ssid -ne $newSsid -or $currentConfig.Passphrase -ne $newPass) {
    $currentConfig.Ssid = $newSsid;
    $currentConfig.Passphrase = $newPass;
    $configOp = $manager.ConfigureAccessPointAsync($currentConfig);
    while ($configOp.Status -eq [Windows.Foundation.AsyncStatus]::Started) { Start-Sleep -Milliseconds 100 }
    if ($configOp.Status -eq [Windows.Foundation.AsyncStatus]::Error) {
       throw ("配置热点失败: " + $configOp.ErrorCode.Message);
    }
  }
  
  # 2. 启用热点
  $startOp = $manager.StartTetheringAsync();
  while ($startOp.Status -eq [Windows.Foundation.AsyncStatus]::Started) { Start-Sleep -Milliseconds 100 }
  if ($startOp.Status -eq [Windows.Foundation.AsyncStatus]::Error) {
    throw ("启动热点失败: " + $startOp.ErrorCode.Message);
  }
  
  $res = $startOp.GetResults();
  if ($res.Status -eq 'Success') {
    Write-Output "STATUS:Success";
  } else {
    Write-Output ("STATUS:Fail " + $res.Status);
    Write-Output ("DETAIL:" + $res.AdditionalErrorMessage);
  }
} catch {
  Write-Output ("STATUS:Error");
  Write-Output ("DETAIL:" + $_.Exception.Message);
}
'''
    .replaceAll('___SSID___', escapedSsid)
    .replaceAll('___KEY___', escapedKey);

    final result = await _runPowerShell(script);

    if (result.stdout.toString().isEmpty && result.stderr.toString().isNotEmpty) {
       return HotspotOperationResult(false, 'PowerShell Error: ${result.stderr}');
    }
    
    final status = _parseKeyValue(result.stdout, 'STATUS');
    final detail = _parseKeyValue(result.stdout, 'DETAIL');

    if (status == 'Success') {
      return const HotspotOperationResult(true, '启动成功');
    } else {
      return HotspotOperationResult(false, detail ?? '未知错误 (exitCode:${result.exitCode}, stderr:${result.stderr})');
    }
  }

  Future<HotspotOperationResult> _disableMobileHotspot() async {
    final script = r'''
$ErrorActionPreference = 'Stop';
try {
  $profile = [Windows.Networking.Connectivity.NetworkInformation,Windows.Networking.Connectivity,ContentType=WindowsRuntime]::GetInternetConnectionProfile();
  if ($null -eq $profile) {
    Write-Output "STATUS:Success"; # 无网络则认为已停止
    exit 0;
  }
  
  $manager = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager,Windows.Networking.NetworkOperators,ContentType=WindowsRuntime]::CreateFromConnectionProfile($profile);
  $stopOp = $manager.StopTetheringAsync();
  while ($stopOp.Status -eq [Windows.Foundation.AsyncStatus]::Started) { Start-Sleep -Milliseconds 100 }
  
  if ($stopOp.Status -eq [Windows.Foundation.AsyncStatus]::Error) {
    throw $stopOp.ErrorCode.Message;
  }
  
  $res = $stopOp.GetResults();
  if ($res.Status -eq 'Success') {
    Write-Output "STATUS:Success";
  } else {
    Write-Output ("STATUS:Fail " + $res.Status);
    Write-Output ("DETAIL:" + $res.AdditionalErrorMessage);
  }
} catch {
  Write-Output ("STATUS:Error");
  Write-Output ("DETAIL:" + $_.Exception.Message);
}
''';
    final result = await _runPowerShell(script);
    final status = _parseKeyValue(result.stdout, 'STATUS');
    final detail = _parseKeyValue(result.stdout, 'DETAIL');
    
    if (status == 'Success') {
      return const HotspotOperationResult(true, '停止成功');
    } else {
      return HotspotOperationResult(false, detail ?? '未知错误');
    }
  }

  Future<ProcessResult> _runPowerShell(String script) {
    return Process.run(
      'powershell',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
      runInShell: true,
    );
  }

  String _escape(String input) {
    return input.replaceAll("'", "''");
  }

  String? _parseKeyValue(String output, String key) {
    final lines = output.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      if (line.trim().startsWith('$key:')) {
        return line.trim().substring(key.length + 1).trim();
      }
    }
    return null;
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }
}

class HotspotOperationResult {
  final bool success;
  final String message;
  const HotspotOperationResult(this.success, this.message);
}
