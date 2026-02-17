import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/config_service.dart';
import '../services/upload_service.dart';

/// 最近文件全屏页面（卡片化瀑布流 + 二维码信息）
class UploadRecentFullscreenPage extends StatefulWidget {
  const UploadRecentFullscreenPage({super.key});

  @override
  State<UploadRecentFullscreenPage> createState() =>
      _UploadRecentFullscreenPageState();
}

class _UploadRecentFullscreenPageState extends State<UploadRecentFullscreenPage> {
  bool _loading = true;

  String get _configDirectory {
    return context.read<ConfigService>().getConfig().configDirectory;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRecords());
  }

  Future<void> _loadRecords() async {
    setState(() => _loading = true);
    await context.read<UploadService>().loadUploadRecords(_configDirectory);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String _formatDateTime(DateTime dateTime) {
    final y = dateTime.year.toString();
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  int _crossAxisCountByWidth(double width) {
    const horizontalPadding = 32.0;
    const spacing = 12.0;
    const baseCardWidth = 220.0;

    final availableWidth = math.max(320, width - horizontalPadding);
    final targetCardWidth = baseCardWidth;
    final columns =
        ((availableWidth + spacing) / (targetCardWidth + spacing)).floor();
    return columns.clamp(2, 10);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('最近文件（全屏）'),
        actions: [
          IconButton(
            tooltip: '刷新最近文件',
            icon: const Icon(Icons.refresh),
            onPressed: _loadRecords,
          ),
        ],
      ),
      body: Consumer<UploadService>(
        builder: (context, service, _) {
          final records = service.uploadRecords.values.toList()
            ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (records.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 56, color: Colors.grey[350]),
                  const SizedBox(height: 10),
                  Text(
                    '暂无最近文件记录',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final columns = _crossAxisCountByWidth(constraints.maxWidth);
              final contentWidth = math.max(320, constraints.maxWidth - 32);
              final cardWidth = (contentWidth - (columns - 1) * 12) / columns;
              final qrSize = (cardWidth - 40).clamp(110.0, 150.0);
              const cardHeight = 360.0;

              return MasonryGridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  final hasUrl = record.url.isNotEmpty;

                  return SizedBox(
                    height: cardHeight,
                    child: Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '上传：${_formatDateTime(record.uploadedAt)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '大小：${UploadService.formatSize(record.fileSize)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                hasUrl ? record.url : '无可用链接',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: hasUrl ? null : Colors.grey[500],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: hasUrl
                                      ? SizedBox.square(
                                          dimension: qrSize,
                                          child: QrImageView(
                                            data: record.url,
                                            size: qrSize,
                                            padding: EdgeInsets.zero,
                                            backgroundColor: Colors.white,
                                          ),
                                        )
                                      : SizedBox(
                                          width: qrSize,
                                          height: qrSize,
                                          child: Center(
                                            child: Text(
                                              '无二维码',
                                              style: TextStyle(
                                                color: Colors.grey[500],
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            if (hasUrl)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: record.url),
                                    );
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('链接已复制到剪贴板'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.copy, size: 14),
                                  label: const Text('复制链接'),
                                ),
                              )
                            else
                              const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
