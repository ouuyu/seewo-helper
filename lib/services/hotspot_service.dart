import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/app_config.dart';

/// 热点状态枚举
enum HotspotStatus {
  stopped,  // 已停止
  starting, // 正在启动
  started,  // 已启动
  stopping, // 正在停止
  error,    // 错误状态
}

/// Windows 热点管理服务
class HotspotService extends ChangeNotifier {
  HotspotStatus _status = HotspotStatus.stopped;
  String? _errorMessage;
  Timer? _statusCheckTimer;
  
  // 热点配置
  String _ssid = 'seewo helper';
  String _password = '11111111';
  String _ipAddress = '192.168.1.233';
  
  HotspotStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String get ssid => _ssid;
  String get password => _password;
  String get ipAddress => _ipAddress;
  
  /// 初始化服务
  Future<void> initialize(AppConfig config) async {
    // 从配置加载热点设置
    _ssid = config.hotspotSSID;
    _password = config.hotspotPassword;
    _ipAddress = config.hotspotIPAddress;
    
    // 检查当前热点状态
    await checkStatus();
    
    // 如果启用了开机自启热点，则启动热点
    if (config.enableHotspotAutoStart) {
      await startHotspot();
    }
    
    // 启动定时检查状态（每 5 秒检查一次）
    _statusCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => checkStatus(),
    );
  }
  
  /// 检查热点状态
  Future<void> checkStatus() async {
    try {
      // 使用 netsh 命令检查热点状态
      final result = await Process.run(
        'netsh',
        ['wlan', 'show', 'hostednetwork'],
        runInShell: true,
      );
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        
        // 检查热点是否已启动
        if (output.contains('已启动') || output.contains('Started')) {
          if (_status != HotspotStatus.started) {
            _status = HotspotStatus.started;
            _errorMessage = null;
            notifyListeners();
          }
        } else {
          if (_status != HotspotStatus.stopped && 
              _status != HotspotStatus.starting &&
              _status != HotspotStatus.stopping) {
            _status = HotspotStatus.stopped;
            _errorMessage = null;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('检查热点状态失败: $e');
    }
  }
  
  /// 启动热点
  Future<bool> startHotspot() async {
    if (_status == HotspotStatus.starting || _status == HotspotStatus.started) {
      return false;
    }
    
    _status = HotspotStatus.starting;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // 1. 停止现有热点（如果有）
      debugPrint('========== 开始启动热点 ==========');
      debugPrint('SSID: $_ssid, 密码: $_password, IP: $_ipAddress');
      
      final stopResult = await Process.run(
        'netsh',
        ['wlan', 'stop', 'hostednetwork'],
        runInShell: true,
      );
      debugPrint('停止现有热点: exitCode=${stopResult.exitCode}');
      
      // 等待一下确保完全停止
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 2. 设置热点模式为允许（重要！）
      debugPrint('设置承载网络模式为允许...');
      final modeResult = await Process.run(
        'netsh',
        ['wlan', 'set', 'hostednetwork', 'mode=allow'],
        runInShell: true,
      );
      debugPrint('设置模式结果: exitCode=${modeResult.exitCode}');
      debugPrint('stdout: ${modeResult.stdout}');
      
      await Future.delayed(const Duration(milliseconds: 300));
      await Future.delayed(const Duration(milliseconds: 300));
      
      // 3. 配置热点 SSID 和密码
      debugPrint('正在配置热点 SSID 和密码...');
      final configResult = await Process.run(
        'netsh',
        [
          'wlan',
          'set',
          'hostednetwork',
          'ssid=$_ssid',
          'key=$_password',
        ],
        runInShell: true,
      );
      
      final configStdout = configResult.stdout.toString();
      final configStderr = configResult.stderr.toString();
      
      debugPrint('配置热点结果: exitCode=${configResult.exitCode}');
      debugPrint('配置热点 stdout: $configStdout');
      debugPrint('配置热点 stderr: $configStderr');
      
      // 检查配置是否成功（不仅看 exitCode，还要看输出内容）
      if (configResult.exitCode != 0 || 
          configStdout.contains('拒绝访问') || 
          configStdout.contains('Access is denied') ||
          configStdout.contains('失败') ||
          configStdout.contains('failed') ||
          configStdout.contains('不支持') ||
          configStdout.contains('not supported')) {
        
        String errorDetail = configStdout.trim();
        if (errorDetail.isEmpty) errorDetail = configStderr.trim();
        
        if (configStdout.contains('拒绝访问') || configStdout.contains('Access is denied')) {
          throw Exception('配置热点失败: 需要管理员权限\n详情: $errorDetail');
        } else if (configStdout.contains('不支持') || configStdout.contains('not supported')) {
          throw Exception('配置热点失败: 您的网卡可能不支持承载网络功能\n详情: $errorDetail');
        } else {
          throw Exception('配置热点失败\n详情: $errorDetail');
        }
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 4. 启动热点
      debugPrint('正在启动热点...');
      final startResult = await Process.run(
        'netsh',
        ['wlan', 'start', 'hostednetwork'],
        runInShell: true,
      );
      
      final startStdout = startResult.stdout.toString();
      final startStderr = startResult.stderr.toString();
      
      debugPrint('启动热点结果: exitCode=${startResult.exitCode}');
      debugPrint('启动热点 stdout: $startStdout');
      debugPrint('启动热点 stderr: $startStderr');
      
      // 检查启动是否成功
      if (startResult.exitCode != 0 || 
          startStdout.contains('拒绝访问') || 
          startStdout.contains('Access is denied') ||
          startStdout.contains('失败') ||
          startStdout.contains('failed') ||
          startStdout.contains('无线本地区域网络接口已关') ||
          startStdout.contains('wireless local area network interface is powered down')) {
        
        String errorDetail = startStdout.trim();
        if (errorDetail.isEmpty) errorDetail = startStderr.trim();
        
        if (startStdout.contains('拒绝访问') || startStdout.contains('Access is denied')) {
          throw Exception('启动热点失败: 需要管理员权限\n详情: $errorDetail');
        } else if (startStdout.contains('无线本地区域网络接口已关') || 
                   startStdout.contains('wireless local area network interface is powered down')) {
          throw Exception('启动热点失败: 请先打开 WiFi 适配器\n详情: $errorDetail');
        } else if (startStdout.contains('无法启动承载网络') || 
                   startStdout.contains('could not be started')) {
          throw Exception('启动热点失败: 无法启动承载网络\n\n可能原因：\n1. WiFi驱动需要更新\n2. 虚拟适配器未正确创建\n3. 需要重启电脑\n\n详情: $errorDetail');
        } else {
          throw Exception('启动热点失败\n详情: $errorDetail');
        }
      }
      
      debugPrint('热点启动命令执行完成，等待热点完全启动...');
      
      // 等待热点完全启动（增加等待时间）
      await Future.delayed(const Duration(milliseconds: 2000));
      
      // 5. 验证热点是否真正启动（多次检查）
      debugPrint('验证热点状态...');
      bool hotspotStarted = false;
      
      for (int i = 0; i < 3; i++) {
        final verifyResult = await Process.run(
          'netsh',
          ['wlan', 'show', 'hostednetwork'],
          runInShell: true,
        );
        
        final verifyOutput = verifyResult.stdout.toString();
        debugPrint('验证结果 (尝试 ${i + 1}/3):\n$verifyOutput');
        
        // 检查是否已启动
        if (verifyOutput.contains('已启动') || verifyOutput.contains('Started')) {
          debugPrint('✓ 热点已成功启动');
          hotspotStarted = true;
          break;
        }
        
        if (i < 2) {
          debugPrint('热点尚未启动，等待 1 秒后重试...');
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
      
      if (!hotspotStarted) {
        // 最后一次检查详细状态
        final finalCheck = await Process.run(
          'netsh',
          ['wlan', 'show', 'hostednetwork'],
          runInShell: true,
        );
        
        final finalOutput = finalCheck.stdout.toString();
        debugPrint('最终状态检查: $finalOutput');
        
        if (finalOutput.contains('不可用')) {
          throw Exception(
            '热点启动失败: 承载网络状态为"不可用"\n\n'
            '可能的解决方法:\n'
            '1. 更新 WiFi 网卡驱动程序\n'
            '2. 在设备管理器中禁用再启用 WiFi 适配器\n'
            '3. 重启电脑后再试\n'
            '4. 检查 Windows 服务中 "WLAN AutoConfig" 服务是否正在运行\n\n'
            '详细状态:\n$finalOutput'
          );
        } else {
          throw Exception(
            '热点启动失败: 未能确认热点已启动\n\n'
            '详细信息:\n$finalOutput'
          );
        }
      }
      
      // 6. 配置 IP 地址
      await _configureIPAddress();
      
      _status = HotspotStatus.started;
      _errorMessage = null;
      notifyListeners();
      
      // 立即检查一次状态
      await checkStatus();
      
      return true;
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
      final result = await Process.run(
        'netsh',
        ['wlan', 'stop', 'hostednetwork'],
        runInShell: true,
      );
      
      if (result.exitCode != 0) {
        throw Exception('停止热点失败: ${result.stderr}');
      }
      
      _status = HotspotStatus.stopped;
      _errorMessage = null;
      notifyListeners();
      
      return true;
    } catch (e) {
      _status = HotspotStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      debugPrint('停止热点失败: $e');
      return false;
    }
  }
  
  /// 配置 IP 地址
  Future<void> _configureIPAddress() async {
    try {
      debugPrint('开始配置 IP 地址...');
      
      // 获取热点网络适配器名称
      final adapterName = await _getHotspotAdapterName();
      if (adapterName == null) {
        debugPrint('警告: 未找到热点网络适配器，跳过 IP 配置');
        return;
      }
      
      debugPrint('找到热点适配器: $adapterName');
      
      // 设置静态 IP 地址
      debugPrint('正在设置 IP 地址为: $_ipAddress');
      final result = await Process.run(
        'netsh',
        [
          'interface',
          'ip',
          'set',
          'address',
          'name=$adapterName',
          'source=static',
          'addr=$_ipAddress',
          'mask=255.255.255.0',
        ],
        runInShell: true,
      );
      
      debugPrint('设置 IP 地址结果: exitCode=${result.exitCode}');
      debugPrint('stdout: ${result.stdout}');
      debugPrint('stderr: ${result.stderr}');
      
      if (result.exitCode == 0) {
        debugPrint('成功设置 IP 地址: $_ipAddress');
      } else {
        debugPrint('设置 IP 地址失败，但继续执行');
      }
    } catch (e) {
      debugPrint('配置 IP 地址异常: $e');
    }
  }
  
  /// 获取热点网络适配器名称
  Future<String?> _getHotspotAdapterName() async {
    try {
      // 获取所有网络适配器
      final result = await Process.run(
        'netsh',
        ['wlan', 'show', 'hostednetwork'],
        runInShell: true,
      );
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        
        // 从输出中提取适配器名称
        // 示例输出: "本地网络连接* 3" 或 "Local Area Connection* 3"
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.contains('接口名称') || line.contains('Interface name')) {
            final parts = line.split(':');
            if (parts.length >= 2) {
              return parts[1].trim();
            }
          }
        }
      }
      
      // 备用方案：尝试常见的热点适配器名称
      final commonNames = [
        '本地连接* 1',
        '本地连接* 2',
        'Local Area Connection* 1',
        'Local Area Connection* 2',
      ];
      
      for (final name in commonNames) {
        final checkResult = await Process.run(
          'netsh',
          ['interface', 'ip', 'show', 'config', 'name=$name'],
          runInShell: true,
        );
        
        if (checkResult.exitCode == 0) {
          return name;
        }
      }
    } catch (e) {
      debugPrint('获取热点适配器名称失败: $e');
    }
    
    return null;
  }
  
  /// 更新热点配置
  Future<void> updateConfiguration({
    String? ssid,
    String? password,
    String? ipAddress,
  }) async {
    bool needRestart = false;
    
    if (ssid != null && ssid != _ssid) {
      _ssid = ssid;
      needRestart = true;
    }
    
    if (password != null && password != _password) {
      _password = password;
      needRestart = true;
    }
    
    if (ipAddress != null && ipAddress != _ipAddress) {
      _ipAddress = ipAddress;
      needRestart = true;
    }
    
    notifyListeners();
    
    // 如果热点正在运行且配置有变化，需要重启热点
    if (needRestart && _status == HotspotStatus.started) {
      await stopHotspot();
      await Future.delayed(const Duration(milliseconds: 500));
      await startHotspot();
    }
  }
  
  /// 获取连接的设备列表
  Future<List<Map<String, String>>> getConnectedDevices() async {
    final devices = <Map<String, String>>[];
    
    try {
      final result = await Process.run(
        'netsh',
        ['wlan', 'show', 'hostednetwork'],
        runInShell: true,
      );
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final lines = output.split('\n');
        
        // 解析连接的客户端信息
        // 这部分可能需要根据实际输出格式调整
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.contains('客户端') || line.contains('Client')) {
            // 尝试提取设备信息
            final deviceInfo = <String, String>{};
            deviceInfo['status'] = '已连接';
            devices.add(deviceInfo);
          }
        }
      }
    } catch (e) {
      debugPrint('获取连接设备列表失败: $e');
    }
    
    return devices;
  }
  
  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }
}
