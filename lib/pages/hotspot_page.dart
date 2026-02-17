import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/hotspot_service.dart';
import '../services/config_service.dart';

/// 热点管理页面
class HotspotPage extends StatefulWidget {
  const HotspotPage({super.key});

  @override
  State<HotspotPage> createState() => _HotspotPageState();
}

class _HotspotPageState extends State<HotspotPage> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ipController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    
    // 从服务加载当前配置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hotspotService = context.read<HotspotService>();
      _ssidController.text = hotspotService.ssid;
      _passwordController.text = hotspotService.password;
      _ipController.text = hotspotService.ipAddress;
    });
  }
  
  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _ipController.dispose();
    super.dispose();
  }
  
  /// 应用配置更改
  Future<void> _applyChanges() async {
    final hotspotService = context.read<HotspotService>();
    final configService = context.read<ConfigService>();
    
    // 更新服务配置
    await hotspotService.updateConfiguration(
      ssid: _ssidController.text,
      password: _passwordController.text,
      ipAddress: _ipController.text,
    );
    
    // 更新并保存配置
    final config = configService.getConfig();
    config.hotspotSSID = _ssidController.text;
    config.hotspotPassword = _passwordController.text;
    config.hotspotIPAddress = _ipController.text;
    await configService.saveConfig(config);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('配置已保存'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  
  /// 运行诊断
  Future<void> _runDiagnostics() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在运行诊断...'),
          ],
        ),
      ),
    );
    
    try {
      final diagnosticResults = <String>[];
      
      // 1. 检查是否支持承载网络
      final supportResult = await Process.run(
        'netsh',
        ['wlan', 'show', 'drivers'],
        runInShell: true,
      );
      
      final driversOutput = supportResult.stdout.toString();
      final isSupported = driversOutput.contains('支持的承载网络') || 
                          driversOutput.contains('Hosted network supported');
      
      diagnosticResults.add('承载网络支持: ${isSupported ? "✓ 是" : "✗ 否"}');
      
      // 2. 检查当前热点状态
      final statusResult = await Process.run(
        'netsh',
        ['wlan', 'show', 'hostednetwork'],
        runInShell: true,
      );
      
      diagnosticResults.add('\n当前热点状态:\n${statusResult.stdout}');
      
      // 3. 检查网络适配器
      final adapterResult = await Process.run(
        'netsh',
        ['interface', 'show', 'interface'],
        runInShell: true,
      );
      
      diagnosticResults.add('\n网络适配器:\n${adapterResult.stdout}');
      
      if (mounted) {
        Navigator.of(context).pop(); // 关闭加载对话框
        
        // 显示诊断结果
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('诊断结果'),
            content: SingleChildScrollView(
              child: SelectableText(
                diagnosticResults.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: diagnosticResults.join('\n')));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')),
                  );
                },
                child: const Text('复制'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('诊断失败'),
            content: Text('错误: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('热点管理'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: '运行诊断',
            onPressed: _runDiagnostics,
          ),
        ],
      ),
      body: Consumer<HotspotService>(
        builder: (context, hotspotService, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 管理员权限提示
                _buildAdminNotice(),
                const SizedBox(height: 16),
                
                // 状态卡片
                _buildStatusCard(hotspotService),
                const SizedBox(height: 24),
                
                // 控制按钮
                _buildControlButtons(hotspotService),
                const SizedBox(height: 32),
                
                // 配置部分
                _buildConfigurationSection(),
                const SizedBox(height: 32),
                
                // 开机自启设置
                _buildAutoStartSection(),
                const SizedBox(height: 32),
                
                // 连接设备列表
                _buildConnectedDevicesSection(hotspotService),
              ],
            ),
          );
        },
      ),
    );
  }
  
  /// 构建管理员权限提示
  Widget _buildAdminNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.admin_panel_settings, color: Colors.orange[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '需要管理员权限',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '配置和启动 Windows 热点需要管理员权限。请以管理员身份运行此应用。',
                  style: TextStyle(
                    color: Colors.orange[800],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建状态卡片
  Widget _buildStatusCard(HotspotService service) {
    IconData icon;
    Color color;
    String statusText;
    
    switch (service.status) {
      case HotspotStatus.started:
        icon = Icons.wifi_tethering;
        color = Colors.green;
        statusText = '热点已启动';
        break;
      case HotspotStatus.starting:
        icon = Icons.sync;
        color = Colors.orange;
        statusText = '正在启动...';
        break;
      case HotspotStatus.stopping:
        icon = Icons.sync;
        color = Colors.orange;
        statusText = '正在停止...';
        break;
      case HotspotStatus.error:
        icon = Icons.error_outline;
        color = Colors.red;
        statusText = '错误';
        break;
      case HotspotStatus.stopped:
        icon = Icons.wifi_tethering_off;
        color = Colors.grey;
        statusText = '热点已停止';
        break;
    }
    
    return Card(
      elevation: 2,
      child: Container(
        constraints: const BoxConstraints(minHeight: 200),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 状态图标
            Icon(icon, size: 80, color: color),
            const SizedBox(height: 20),
            
            // 状态文本
            Text(
              statusText,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            
            // 错误信息
            if (service.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        service.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // 热点信息
            if (service.status == HotspotStatus.started) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              _buildInfoRow('网络名称 (SSID)', service.ssid),
              const SizedBox(height: 8),
              _buildInfoRow('密码', service.password),
              const SizedBox(height: 8),
              _buildInfoRow('IP 地址', service.ipAddress),
            ],
          ],
        ),
      ),
    );
  }
  
  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              tooltip: '复制',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已复制到剪贴板'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
  
  /// 构建控制按钮
  Widget _buildControlButtons(HotspotService service) {
    final isProcessing = service.status == HotspotStatus.starting ||
        service.status == HotspotStatus.stopping;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isProcessing || service.status == HotspotStatus.started
                    ? null
                    : () => service.startHotspot(),
                icon: isProcessing && service.status == HotspotStatus.starting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('启动热点'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isProcessing || service.status == HotspotStatus.stopped
                    ? null
                    : () => service.stopHotspot(),
                icon: isProcessing && service.status == HotspotStatus.stopping
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.stop),
                label: const Text('停止热点'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '提示: 如遇问题，点击右上角诊断按钮查看详细信息',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// 构建配置部分
  Widget _buildConfigurationSection() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '热点配置',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // SSID 输入
            TextField(
              controller: _ssidController,
              decoration: const InputDecoration(
                labelText: '网络名称 (SSID)',
                hintText: '输入 WiFi 热点名称',
                prefixIcon: Icon(Icons.wifi),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            // 密码输入
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密码',
                hintText: '至少 8 位字符',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            
            // IP 地址输入
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP 地址',
                hintText: '例如: 192.168.1.233',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            
            // 应用按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _applyChanges,
                icon: const Icon(Icons.check),
                label: const Text('应用配置'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 提示信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '修改配置后，如果热点正在运行，将自动重启以应用新配置。',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建开机自启部分
  Widget _buildAutoStartSection() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Consumer<ConfigService>(
          builder: (context, configService, _) {
            final config = configService.getConfig();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '自动启动',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                SwitchListTile(
                  value: config.enableHotspotAutoStart,
                  onChanged: (value) async {
                    config.enableHotspotAutoStart = value;
                    await configService.saveConfig(config);
                  },
                  title: const Text('开机自动启动热点'),
                  subtitle: const Text('应用启动时自动打开 WiFi 热点'),
                  secondary: const Icon(Icons.power_settings_new),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  
  /// 构建连接设备列表部分
  Widget _buildConnectedDevicesSection(HotspotService service) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '连接的设备',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新',
                  onPressed: () {
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (service.status != HotspotStatus.started)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    '热点未启动',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              FutureBuilder<List<Map<String, String>>>(
                future: service.getConnectedDevices(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          '加载失败: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }
                  
                  final devices = snapshot.data ?? [];
                  
                  if (devices.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          '暂无设备连接',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }
                  
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: devices.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return ListTile(
                        leading: const Icon(Icons.devices),
                        title: Text(device['name'] ?? '未知设备'),
                        subtitle: Text(device['status'] ?? ''),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
