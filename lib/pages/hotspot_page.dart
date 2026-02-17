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
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
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

  Future<void> _applyChanges() async {
    final hotspotService = context.read<HotspotService>();
    final configService = context.read<ConfigService>();

    await hotspotService.updateConfiguration(
      ssid: _ssidController.text,
      password: _passwordController.text,
      ipAddress: _ipController.text,
    );

    final config = configService.getConfig();
    config.hotspotSSID = _ssidController.text;
    config.hotspotPassword = _passwordController.text;
    config.hotspotIPAddress = _ipController.text;
    await configService.saveConfig(config);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已保存'), duration: Duration(seconds: 2)),
      );
    }
  }

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

      final supportResult = await Process.run('netsh', [
        'wlan',
        'show',
        'drivers',
      ], runInShell: true);
      final driversOutput = supportResult.stdout.toString();
      final isSupported =
          driversOutput.contains('支持的承载网络') ||
          driversOutput.contains('Hosted network supported');
      diagnosticResults.add('承载网络支持: ${isSupported ? "✓ 是" : "✗ 否"}');

      final statusResult = await Process.run('netsh', [
        'wlan',
        'show',
        'hostednetwork',
      ], runInShell: true);
      diagnosticResults.add('\n当前热点状态:\n${statusResult.stdout}');

      final adapterResult = await Process.run('netsh', [
        'interface',
        'show',
        'interface',
      ], runInShell: true);
      diagnosticResults.add('\n网络适配器:\n${adapterResult.stdout}');

      if (mounted) {
        Navigator.of(context).pop();
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
                  Clipboard.setData(
                    ClipboardData(text: diagnosticResults.join('\n')),
                  );
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('热点管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: _runDiagnostics,
            tooltip: '运行诊断',
          ),
        ],
      ),
      body: Consumer<HotspotService>(
        builder: (context, hotspotService, _) => Container(
          color: colorScheme.surface,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // 管理员权限提示
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.admin_panel_settings_rounded,
                          color: colorScheme.onSecondaryContainer,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '需要管理员权限',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSecondaryContainer,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '配置和启动 Windows 热点需要管理员权限',
                              style: TextStyle(
                                color: colorScheme.onSecondaryContainer
                                    .withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 状态和控制区域
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      // 状态显示
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  hotspotService.status == HotspotStatus.started
                                  ? colorScheme.primaryContainer
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              hotspotService.status == HotspotStatus.started
                                  ? Icons.wifi_tethering
                                  : Icons.wifi_tethering_off,
                              size: 32,
                              color:
                                  hotspotService.status == HotspotStatus.started
                                  ? colorScheme.onPrimaryContainer
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hotspotService.status == HotspotStatus.started
                                      ? '热点已启动'
                                      : '热点已停止',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                if (hotspotService.status ==
                                    HotspotStatus.started) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '其他设备可以连接到此热点',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      // 错误信息
                      if (hotspotService.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: colorScheme.onErrorContainer,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hotspotService.errorMessage!,
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // 热点信息（仅在启动时显示）
                      if (hotspotService.status == HotspotStatus.started) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildInfoRow('网络名称', hotspotService.ssid),
                              const SizedBox(height: 8),
                              _buildInfoRow('密码', hotspotService.password),
                              const SizedBox(height: 8),
                              _buildInfoRow('IP 地址', hotspotService.ipAddress),
                            ],
                          ),
                        ),
                      ],

                      // 控制按钮
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                                  hotspotService.status == HotspotStatus.started
                                  ? null
                                  : () => hotspotService.startHotspot(),
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 18,
                              ),
                              label: const Text('启动热点'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  hotspotService.status == HotspotStatus.stopped
                                  ? null
                                  : () => hotspotService.stopHotspot(),
                              icon: const Icon(Icons.stop_rounded, size: 18),
                              label: const Text('停止热点'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 配置区域
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.settings_rounded,
                              size: 18,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            '热点配置',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _ssidController,
                        decoration: InputDecoration(
                          labelText: '网络名称 (SSID)',
                          hintText: '输入 WiFi 热点名称',
                          prefixIcon: const Icon(Icons.wifi_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: '密码',
                          hintText: '至少 8 位字符',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ipController,
                        decoration: InputDecoration(
                          labelText: 'IP 地址',
                          hintText: '例如: 192.168.1.233',
                          prefixIcon: const Icon(Icons.lan_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _applyChanges,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('应用配置'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: colorScheme.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '修改配置后，如果热点正在运行，将自动重启以应用新配置。',
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.9),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 自动启动设置
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Consumer<ConfigService>(
                    builder: (context, configService, _) {
                      final config = configService.getConfig();
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.rocket_launch_rounded,
                              size: 18,
                              color: colorScheme.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '开机自动启动',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '应用启动时自动打开 WiFi 热点',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: config.enableHotspotAutoStart,
                            onChanged: (value) async {
                              config.enableHotspotAutoStart = value;
                              await configService.saveConfig(config);
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // 连接设备
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.devices_rounded,
                              size: 18,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              '连接的设备',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            onPressed: () => setState(() {}),
                            tooltip: '刷新',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (hotspotService.status != HotspotStatus.started)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.wifi_tethering_off,
                                color: colorScheme.outline,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '热点未启动，暂无可显示设备',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        FutureBuilder<List<Map<String, String>>>(
                          future: hotspotService.getConnectedDevices(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            if (snapshot.hasError) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: colorScheme.onErrorContainer,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '加载失败: ${snapshot.error}',
                                        style: TextStyle(
                                          color: colorScheme.onErrorContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final devices = snapshot.data ?? [];
                            if (devices.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.device_unknown,
                                      color: colorScheme.outline,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '暂无设备连接',
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: devices.length,
                              separatorBuilder: (context, index) => Divider(
                                color: colorScheme.outlineVariant,
                                height: 16,
                              ),
                              itemBuilder: (context, index) {
                                final device = devices[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            colorScheme.primaryContainer,
                                        child: Icon(
                                          Icons.devices_other_rounded,
                                          color: colorScheme.onPrimaryContainer,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              device['name'] ?? '未知设备',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (device['status']?.isNotEmpty ??
                                                false)
                                              Text(
                                                device['status']!,
                                                style: TextStyle(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.copy_rounded, size: 16, color: colorScheme.primary),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已复制到剪贴板'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          tooltip: '复制',
        ),
      ],
    );
  }
}
