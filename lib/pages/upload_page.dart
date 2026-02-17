import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'upload_recent_fullscreen_page.dart';
import '../services/config_service.dart';
import '../services/upload_service.dart';

/// 上传页面 - 将 EventListen 文件夹中的文件上传到服务器
class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final ScrollController _logScrollController = ScrollController();
  bool _autoUpload = false;

  @override
  void initState() {
    super.initState();
    _autoUpload = context.read<ConfigService>().getConfig().enableAutoUpload;
    // 页面加载后自动扫描
    WidgetsBinding.instance.addPostFrameCallback((_) => _scanFiles());
  }

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

  /// 获取配置目录
  String get _configDirectory {
    return context.read<ConfigService>().getConfig().configDirectory;
  }

  /// 扫描文件
  Future<void> _scanFiles() async {
    final service = context.read<UploadService>();
    service.reset();
    await service.scanFiles(_configDirectory);

    final hasPending = service.fileItems
        .any((item) => item.status == FileUploadStatus.pending);
    if (_autoUpload && !service.isUploading && hasPending) {
      await service.startUpload(_configDirectory);
    }
  }

  Future<void> _toggleAutoUpload(bool value) async {
    final configService = context.read<ConfigService>();
    final config = configService.getConfig();

    setState(() {
      _autoUpload = value;
    });

    config.enableAutoUpload = value;
    final saved = await configService.saveConfig(config);

    if (!mounted) return;
    if (!saved) {
      setState(() {
        _autoUpload = !value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自动上传设置保存失败')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value ? '已开启自动上传' : '已关闭自动上传')),
    );
  }

  /// 开始上传
  Future<void> _startUpload() async {
    final service = context.read<UploadService>();
    await service.startUpload(_configDirectory);
  }

  /// 停止上传
  void _stopUpload() {
    context.read<UploadService>().stopUpload();
  }

  /// 打开 EventListen 文件夹
  Future<void> _openFolder() async {
    final dir = '$_configDirectory\\EventListen';
    final directory = Directory(dir);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    await Process.run('explorer', [dir]);
  }

  /// 打开最近文件全屏视图
  Future<void> _openRecentFilesFullscreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const UploadRecentFullscreenPage(),
        fullscreenDialog: true,
      ),
    );
  }

  /// 展示已上传文件的直链并支持复制
  Future<void> _showUploadedLinkDialog(UploadFileItem item) async {
    final url = item.url;
    if (url == null || url.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('上传直链'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(dialogContext)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      url,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(dialogContext)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      child: SizedBox.square(
                        dimension: 148,
                        child: QrImageView(
                          data: url,
                          size: 148,
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('直链已复制到剪贴板')),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('复制链接'),
            ),
          ],
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final y = dateTime.year.toString();
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    final hh = dateTime.hour.toString().padLeft(2, '0');
    final mm = dateTime.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '文件上传',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: '全屏查看最近文件',
            onPressed: _openRecentFilesFullscreen,
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: '打开 EventListen 文件夹',
            onPressed: _openFolder,
          ),
        ],
      ),
      body: Consumer<UploadService>(
        builder: (context, service, _) {
          if (service.logs.isNotEmpty) {
            _scrollToBottom();
          }

          return Column(
            children: [
              // 顶部操作区
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildStatusCard(context, service),
              ),

              // 中间文件网格
              Expanded(
                child: _buildFileList(context, service),
              ),
              
              // 底部日志区域
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 220,
                  child: _buildLogCard(context, service),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建状态卡片
  Widget _buildStatusCard(BuildContext context, UploadService service) {
    final isUploading = service.isUploading;
    final hasFiles = service.fileItems.isNotEmpty;
    final hasPending = service.fileItems
        .any((item) => item.status == FileUploadStatus.pending);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 状态图标
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUploading
                    ? Colors.blue.withValues(alpha: 0.1)
                    : hasFiles
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isUploading
                    ? Icons.cloud_upload
                    : hasFiles
                        ? Icons.cloud_done
                        : Icons.cloud_off,
                size: 28,
                color: isUploading
                    ? Colors.blue
                    : hasFiles
                        ? Colors.green
                        : Colors.grey,
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
                          color: isUploading ? Colors.blue : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isUploading ? '正在上传...' : '就绪',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isUploading
                              ? Colors.blue[700]
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '共 ${service.totalCount} 个文件  |  '
                    '成功 ${service.uploadedCount}  |  '
                    '跳过 ${service.skippedCount}  |  '
                    '失败 ${service.failedCount}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            // 操作按钮组
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '自动上传',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    Switch(
                      value: _autoUpload,
                      onChanged: isUploading ? null : _toggleAutoUpload,
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                // 刷新按钮
                OutlinedButton.icon(
                  onPressed: isUploading ? null : _scanFiles,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('扫描'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 上传/停止按钮
                FilledButton.icon(
                  onPressed: isUploading
                      ? _stopUpload
                      : hasPending
                          ? _startUpload
                          : null,
                  icon: Icon(
                    isUploading ? Icons.stop : Icons.cloud_upload,
                    size: 20,
                  ),
                  label: Text(isUploading ? '停止' : '上传'),
                  style: FilledButton.styleFrom(
                    backgroundColor: isUploading ? Colors.red : Colors.blue,
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
          ],
        ),
      ),
    );
  }

  /// 构建文件列表（瀑布流）
  Widget _buildFileList(BuildContext context, UploadService service) {
    final items = service.fileItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text(
              '待办事项列表为空',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击"扫描"检测文件',
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return MasonryGridView.count(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      crossAxisCount: 2, // 2 列瀑布流
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: items.length,
      itemBuilder: (context, index) => _buildModernFileCard(context, items[index]),
    );
  }

  /// 构建现代风格文件卡片
  Widget _buildModernFileCard(BuildContext context, UploadFileItem item) {
    final _ = Theme.of(context);
    final (
      Color baseColor,
      Color bgColor,
      IconData icon,
      String statusText,
    ) = switch (item.status) {
      FileUploadStatus.pending => (
          Colors.orange,
          Colors.orange.withValues(alpha: 0.08),
          Icons.schedule_rounded,
          '等待上传'
        ),
      FileUploadStatus.uploading => (
          Colors.blue,
          Colors.blue.withValues(alpha: 0.08),
          Icons.cloud_upload_rounded,
          '上传中...'
        ),
      FileUploadStatus.success => (
          Colors.green,
          Colors.green.withValues(alpha: 0.08),
          Icons.check_circle_rounded,
          '已完成'
        ),
      FileUploadStatus.failed => (
          Colors.red,
          Colors.red.withValues(alpha: 0.08),
          Icons.error_rounded,
          '失败'
        ),
      FileUploadStatus.skipped => (
          Colors.grey,
          Colors.grey.withValues(alpha: 0.08),
          Icons.skip_next_rounded,
          '已跳过'
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: baseColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if ((item.status == FileUploadStatus.success ||
                    item.status == FileUploadStatus.skipped) &&
                item.url != null &&
                item.url!.isNotEmpty) {
              _showUploadedLinkDialog(item);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部状态栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: baseColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: baseColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.status == FileUploadStatus.uploading)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: baseColor,
                        ),
                      ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 文件名
                    Text(
                      item.fileName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // 文件大小与扩展名
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            UploadService.formatSize(item.fileSize),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDateTime(item.modifiedAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // 错误信息展示
                        if (item.status == FileUploadStatus.failed && 
                            item.errorMessage != null)
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Colors.red[300],
                          ),
                        // 成功链接展示
                        if ((item.status == FileUploadStatus.success ||
                                item.status == FileUploadStatus.skipped) &&
                            item.url != null)
                          Icon(
                            Icons.link_rounded,
                            size: 16,
                            color: Colors.green[300],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建日志卡片
  Widget _buildLogCard(BuildContext context, UploadService service) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.article_outlined, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '上传日志',
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
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildLogArea(context, service)),
        ],
      ),
    );
  }

  /// 构建日志内容
  Widget _buildLogArea(BuildContext context, UploadService service) {
    final logs = service.logs;

    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              '暂无日志',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
            const SizedBox(height: 4),
            Text(
              '点击"扫描"扫描文件后点击"上传"开始',
              style: TextStyle(fontSize: 12, color: Colors.grey[350]),
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
        final isError =
            logEntry.contains('失败') || logEntry.contains('异常') || logEntry.contains('超时');
        final isSuccess = logEntry.contains('成功');

        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isSuccess
                    ? Icons.check_circle_outline
                    : isError
                        ? Icons.error_outline
                        : Icons.chevron_right,
                size: 14,
                color: isSuccess
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
                    color: isSuccess
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
