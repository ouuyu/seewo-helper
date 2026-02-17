import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_config.dart';
import '../services/config_service.dart';
import '../services/wallpaper_service.dart';

class WallpaperPage extends StatefulWidget {
  const WallpaperPage({super.key});

  @override
  State<WallpaperPage> createState() => _WallpaperPageState();
}

class _WallpaperPageState extends State<WallpaperPage> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    _initialized = true;
    final config = context.read<ConfigService>().getConfig();
    // 延迟执行以避免在 build 阶段调用 notifyListeners
    Future.microtask(() {
      if (!mounted) return;
      context.read<WallpaperService>().initialize(config);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '壁纸',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          Consumer2<ConfigService, WallpaperService>(
            builder: (context, configService, wallpaperService, _) {
              return IconButton(
                tooltip: '壁纸设置',
                onPressed: () => _showWallpaperSettingsDialog(
                  context,
                  configService.getConfig(),
                ),
                icon: const Icon(Icons.tune),
              );
            },
          ),
        ],
      ),
      body: Consumer2<ConfigService, WallpaperService>(
        builder: (context, configService, wallpaperService, _) {
          final config = configService.getConfig();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWallpaperCard(wallpaperService),
                const SizedBox(height: 16),
                _buildActions(context, config, wallpaperService),

                const SizedBox(height: 16),
                _buildInfoCard(wallpaperService),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showWallpaperSettingsDialog(
    BuildContext context,
    AppConfig config,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _WallpaperSettingsDialog(config: config),
    );

    if (saved == true && mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('壁纸设置已保存')),
      );
      setState(() {});
    }
  }

  Widget _buildWallpaperCard(WallpaperService service) {
    final imageFile = service.imageFile;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.grey[100],
          height: 360,
          child: Stack(
            children: [
              Positioned.fill(
                child: imageFile != null && imageFile.existsSync()
                    ? Image.file(imageFile, fit: BoxFit.cover)
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.wallpaper_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '暂无壁纸',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (service.isLoading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color.fromARGB(140, 255, 255, 255),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    AppConfig config,
    WallpaperService service,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            FilledButton.icon(
              onPressed: service.isLoading
                  ? null
                  : () => service.refresh(config: config),
              icon: const Icon(Icons.refresh),
              label: const Text('获取最新壁纸'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: service.imageFile == null
                  ? null
                  : () async {
                      final success = await service.setCurrentAsWallpaper();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '已设置为桌面壁纸' : '设置壁纸失败'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: success ? null : Colors.red,
                        ),
                      );
                    },
              icon: const Icon(Icons.wallpaper),
              label: const Text('设置为桌面壁纸'),
            ),
            const Spacer(),
            if (service.error != null)
              Flexible(
                child: Text(
                  service.error!,
                  style: TextStyle(color: Colors.red[600], fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }



  Widget _buildInfoCard(WallpaperService service) {
    final info = service.latest;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '壁纸信息',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('日期', info?.startDate ?? '--'),
            const SizedBox(height: 6),
            _buildInfoRow('描述', info?.copyright ?? '--'),
            const SizedBox(height: 6),
            _buildInfoRow('链接', info?.copyrightLink ?? '--'),
            const SizedBox(height: 6),
            _buildInfoRow('保存路径', service.imageFile?.path ?? '--'),
            if (service.lastUpdated != null) ...[
              const SizedBox(height: 6),
              _buildInfoRow(
                '更新时间',
                service.lastUpdated.toString().substring(0, 19),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}

class _WallpaperSettingsDialog extends StatefulWidget {
  const _WallpaperSettingsDialog({required this.config});

  final AppConfig config;

  @override
  State<_WallpaperSettingsDialog> createState() =>
      _WallpaperSettingsDialogState();
}

class _WallpaperSettingsDialogState extends State<_WallpaperSettingsDialog> {
  late bool autoRefresh;
  late bool autoSet;
  late bool showCountdown;

  late final TextEditingController countdownDateController;
  late final TextEditingController countdownEventController;
  late final TextEditingController resolutionController;
  late final TextEditingController marketController;
  late final TextEditingController indexController;
  late final TextEditingController saveDirController;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final config = widget.config;

    autoRefresh = config.wallpaperAutoRefresh;
    autoSet = config.wallpaperAutoSet;
    showCountdown = config.wallpaperShowCountdown;

    countdownDateController = TextEditingController(
      text: config.wallpaperCountdownDate,
    );
    countdownEventController = TextEditingController(
      text: config.wallpaperCountdownEventName,
    );
    resolutionController = TextEditingController(text: config.wallpaperResolution);
    marketController = TextEditingController(text: config.wallpaperMarket);
    indexController = TextEditingController(text: config.wallpaperIndex);
    saveDirController = TextEditingController(text: config.wallpaperSaveDirectory);
  }

  @override
  void dispose() {
    countdownDateController.dispose();
    countdownEventController.dispose();
    resolutionController.dispose();
    marketController.dispose();
    indexController.dispose();
    saveDirController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      isSaving = true;
    });

    final config = widget.config;
    final countdownDate = countdownDateController.text.trim();
    final index = indexController.text.trim();

    final countdownDateSetting = config.getSetting<String>('wallpaperCountdownDate');
    final indexSetting = config.getSetting<String>('wallpaperIndex');

    final countdownDateError = countdownDateSetting?.validator?.call(countdownDate);
    if (countdownDateError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(countdownDateError), backgroundColor: Colors.red),
        );
        setState(() {
          isSaving = false;
        });
      }
      return;
    }

    final indexError = indexSetting?.validator?.call(index);
    if (indexError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(indexError), backgroundColor: Colors.red),
        );
        setState(() {
          isSaving = false;
        });
      }
      return;
    }

    config.wallpaperAutoRefresh = autoRefresh;
    config.wallpaperAutoSet = autoSet;
    config.wallpaperShowCountdown = showCountdown;
    config.wallpaperCountdownDate = countdownDate;
    config.wallpaperCountdownEventName = countdownEventController.text.trim();
    config.wallpaperResolution = resolutionController.text.trim();
    config.wallpaperMarket = marketController.text.trim();
    config.wallpaperIndex = index;
    config.wallpaperSaveDirectory = saveDirController.text.trim();

    final success = await context.read<ConfigService>().saveConfig(config);

    if (!mounted) return;

    setState(() {
      isSaving = false;
    });

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('壁纸设置保存失败'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('壁纸设置'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('更新与应用', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SwitchListTile(
                value: autoRefresh,
                contentPadding: EdgeInsets.zero,
                title: const Text('启动时更新壁纸'),
                onChanged: (value) {
                  setState(() {
                    autoRefresh = value;
                  });
                },
              ),
              SwitchListTile(
                value: autoSet,
                contentPadding: EdgeInsets.zero,
                title: const Text('自动设置为桌面壁纸'),
                onChanged: (value) {
                  setState(() {
                    autoSet = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              const Text('倒计时', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SwitchListTile(
                value: showCountdown,
                contentPadding: EdgeInsets.zero,
                title: const Text('显示倒计时'),
                onChanged: (value) {
                  setState(() {
                    showCountdown = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: countdownDateController,
                decoration: const InputDecoration(
                  labelText: '倒计时目标日期',
                  hintText: 'YYYY-MM-DD',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countdownEventController,
                decoration: const InputDecoration(
                  labelText: '倒计时事件名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('请求参数', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: resolutionController,
                decoration: const InputDecoration(
                  labelText: '壁纸分辨率',
                  hintText: 'UHD / 1920x1080',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: marketController,
                decoration: const InputDecoration(
                  labelText: '市场',
                  hintText: 'zh-CN / en-US',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: indexController,
                decoration: const InputDecoration(
                  labelText: '索引',
                  hintText: '0',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('存储', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: saveDirController,
                decoration: const InputDecoration(
                  labelText: '壁纸保存目录',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: isSaving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('保存'),
        ),
      ],
    );
  }
}
