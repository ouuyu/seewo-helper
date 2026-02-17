import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../services/event_listen_service.dart';

/// 事件监听页面 - 监控指定进程打开的文件
class EventListenPage extends StatefulWidget {
  const EventListenPage({super.key});

  @override
  State<EventListenPage> createState() => _EventListenPageState();
}

class _EventListenPageState extends State<EventListenPage> {
  final ScrollController _logScrollController = ScrollController();

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  /// 自动滚动日志到底部
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 打开 EventListen 文件夹
  Future<void> _openEventListenFolder() async {
    final service = context.read<EventListenService>();
    final dir = service.eventListenDir;
    if (dir.isEmpty) return;

    final directory = Directory(dir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    await Process.run('explorer', [dir]);
  }

  /// 切换监听状态
  Future<void> _toggleListening() async {
    final service = context.read<EventListenService>();
    final configService = context.read<ConfigService>();

    if (service.isListening) {
      service.stopListening();
    } else {
      // 从配置加载参数
      final config = configService.getConfig();
      final eventListenDir =
          '${config.configDirectory}\\EventListen';
      final processesStr = config.eventListenProcesses;
      final processes = processesStr
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      service.configure(
        eventListenDir: eventListenDir,
        processNames: processes,
      );

      await service.startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '事件监听',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          // 打开文件夹按钮
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: '打开 EventListen 文件夹',
            onPressed: _openEventListenFolder,
          ),
        ],
      ),
      body: Consumer<EventListenService>(
        builder: (context, service, _) {
          // 日志更新时自动滚动
          if (service.logs.isNotEmpty) {
            _scrollToBottom();
          }

          return Column(
            children: [
              // 状态与控制区域
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 状态卡片
                    _buildStatusCard(context, service),
                    const SizedBox(height: 16),
                    // 监听进程列表卡片
                    _buildProcessCard(context, service),
                  ],
                ),
              ),
              // 日志卡片
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.article_outlined,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '运行日志',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const Spacer(),
                              if (service.logs.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () => service.clearLogs(),
                                  icon: const Icon(Icons.clear_all, size: 18),
                                  label: const Text('清空'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey[600],
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: _buildLogArea(context, service),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建状态卡片
  Widget _buildStatusCard(BuildContext context, EventListenService service) {
    final isListening = service.isListening;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 状态指示灯
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isListening
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isListening ? Icons.hearing : Icons.hearing_disabled,
                size: 28,
                color: isListening ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            // 状态信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isListening ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isListening ? '正在监听' : '未启动',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isListening ? Colors.green[700] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '已复制文件: ${service.copiedCount} 个',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // 控制按钮
            FilledButton.icon(
              onPressed: _toggleListening,
              icon: Icon(
                isListening ? Icons.stop : Icons.play_arrow,
                size: 20,
              ),
              label: Text(isListening ? '停止' : '开始'),
              style: FilledButton.styleFrom(
                backgroundColor: isListening ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建监听进程卡片
  Widget _buildProcessCard(BuildContext context, EventListenService service) {
    final configService = context.read<ConfigService>();
    final config = configService.getConfig();
    final processesStr = config.eventListenProcesses;
    final processes = processesStr
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.apps,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '监听进程',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: processes.map((proc) {
                IconData icon;
                if (proc.toLowerCase().contains('word')) {
                  icon = Icons.description;
                } else if (proc.toLowerCase().contains('excel')) {
                  icon = Icons.table_chart;
                } else if (proc.toLowerCase().contains('powerpnt')) {
                  icon = Icons.slideshow;
                } else if (proc.toLowerCase().contains('edge')) {
                  icon = Icons.language;
                } else {
                  icon = Icons.apps;
                }
                return Chip(
                  avatar: Icon(icon, size: 16),
                  label: Text(
                    proc,
                    style: const TextStyle(fontSize: 13),
                  ),
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建日志区域
  Widget _buildLogArea(BuildContext context, EventListenService service) {
    final logs = service.logs;

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            Text(
              '暂无日志',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '点击"开始"按钮启动监听',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[350],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _logScrollController,
      padding: const EdgeInsets.all(12),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final logEntry = logs[index];
        final isError = logEntry.contains('失败') || logEntry.contains('异常');
        final isCopy = logEntry.contains('已复制');

        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isCopy
                    ? Icons.file_copy
                    : isError
                        ? Icons.error_outline
                        : Icons.chevron_right,
                size: 14,
                color: isCopy
                    ? Colors.green
                    : isError
                        ? Colors.red
                        : Colors.grey[400],
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  logEntry,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Consolas',
                    color: isCopy
                        ? Colors.green[700]
                        : isError
                            ? Colors.red[700]
                            : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
