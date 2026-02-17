import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as path;
import '../models/app_config.dart';

class WallpaperInfo {
  final String startDate;
  final String endDate;
  final String url;
  final String copyright;
  final String copyrightLink;

  const WallpaperInfo({
    required this.startDate,
    required this.endDate,
    required this.url,
    required this.copyright,
    required this.copyrightLink,
  });

  factory WallpaperInfo.fromJson(Map<String, dynamic> json) {
    return WallpaperInfo(
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      copyright: json['copyright']?.toString() ?? '',
      copyrightLink: json['copyright_link']?.toString() ?? '',
    );
  }
}

class WallpaperService extends ChangeNotifier {
  static const String _apiBase = 'https://bing.biturl.top/';

  bool _isLoading = false;
  String? _error;
  WallpaperInfo? _latest;
  File? _imageFile; // 原始图片文件（展示给用户）
  File? _processedImageFile; // PS处理后的临时文件（用于设置壁纸）
  DateTime? _lastUpdated;

  bool get isLoading => _isLoading;
  String? get error => _error;
  WallpaperInfo? get latest => _latest;
  File? get imageFile => _imageFile;
  DateTime? get lastUpdated => _lastUpdated;

  Future<void> initialize(AppConfig config) async {
    if (config.wallpaperAutoRefresh) {
      await refresh(config: config, setAsWallpaper: config.wallpaperAutoSet);
    }
  }

  Future<void> refresh({
    required AppConfig config,
    bool setAsWallpaper = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final info = await _fetchLatest(config);
      // 下载原图（带缓存检查）
      final originalImageFile = await _downloadImage(info, config);

      // 保存原图引用（展示给用户）
      _imageFile = originalImageFile;
      _latest = info;
      _lastUpdated = DateTime.now();

      // 创建处理后的图片副本到临时文件夹
      File processedFile = await _copyToTempFile(originalImageFile, info);

      // 获取屏幕分辨率并调整图片以完全匹配
      final screenSize = await _getScreenResolution();
      if (screenSize != null) {
        processedFile = await _resizeAndCropImage(processedFile, screenSize);
      }

      // 如果启用了倒计时，在图片上绘制倒计时（带高斯模糊背景）
      if (config.wallpaperShowCountdown &&
          config.wallpaperCountdownDate.trim().isNotEmpty) {
        processedFile = await _addCountdownToImage(processedFile, config);
      }

      // 保存处理后的文件引用
      _processedImageFile = processedFile;

      if (setAsWallpaper || config.wallpaperAutoSet) {
        final setResult = await setAsDesktopWallpaper(processedFile.path);
        if (!setResult) {
          _error = '设置桌面壁纸失败';
        }
      }
    } catch (e) {
      _error = '获取壁纸失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> setCurrentAsWallpaper() async {
    // 使用处理后的临时文件设置壁纸
    final file = _processedImageFile ?? _imageFile;
    if (file == null) return false;
    return setAsDesktopWallpaper(file.path);
  }

  Future<WallpaperInfo> _fetchLatest(AppConfig config) async {
    final query = <String, String>{
      'resolution': config.wallpaperResolution.trim(),
      'format': 'json',
      'index': config.wallpaperIndex.trim(),
      'mkt': config.wallpaperMarket.trim(),
    }..removeWhere((key, value) => value.isEmpty);

    final uri = Uri.parse(_apiBase).replace(queryParameters: query);
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return WallpaperInfo.fromJson(json);
    } finally {
      client.close();
    }
  }

  Future<File> _downloadImage(WallpaperInfo info, AppConfig config) async {
    final rawUrl = info.url.trim();
    if (rawUrl.isEmpty) {
      throw const FormatException('壁纸地址为空');
    }

    final imageUri = _normalizeImageUri(rawUrl);
    final directory = Directory(
      config.wallpaperSaveDirectory.trim().isEmpty
          ? '${config.configDirectory}\\Wallpapers'
          : config.wallpaperSaveDirectory.trim(),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final fileName = _buildFileName(info, imageUri);
    final filePath = path.join(directory.path, fileName);
    final file = File(filePath);

    // 缓存检查：如果原图已存在，直接返回
    if (await file.exists()) {
      debugPrint('使用缓存的壁纸: $filePath');
      return file;
    }

    // 下载新图片
    debugPrint('下载新壁纸: $filePath');
    final client = HttpClient();
    try {
      final request = await client.getUrl(imageUri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: imageUri);
      }
      final bytes = await consolidateHttpClientResponseBytes(response);
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } finally {
      client.close();
    }
  }

  Uri _normalizeImageUri(String url) {
    final parsed = Uri.parse(url);
    if (parsed.hasScheme) {
      return parsed;
    }
    return Uri.parse('https://www.bing.com$url');
  }

  String _buildFileName(WallpaperInfo info, Uri imageUri) {
    final queryId = imageUri.queryParameters['id'];
    final baseName = (queryId != null && queryId.trim().isNotEmpty)
        ? queryId.trim()
        : path.basename(imageUri.path);
    final safeBase = baseName.isEmpty ? 'bing_wallpaper.jpg' : baseName;
    final prefix = info.startDate.trim().isEmpty ? 'bing' : info.startDate;
    return '${prefix}_$safeBase';
  }

  /// 复制原图到临时文件夹
  Future<File> _copyToTempFile(File originalFile, WallpaperInfo info) async {
    final tempDir = Directory.systemTemp;
    final tempFileName = 'seewo_wallpaper_${info.startDate}_processed.png';
    final tempFilePath = path.join(tempDir.path, tempFileName);
    final tempFile = File(tempFilePath);

    // 复制原图到临时文件
    await originalFile.copy(tempFilePath);
    debugPrint('已复制到临时文件: $tempFilePath');
    return tempFile;
  }

  Future<({int width, int height})?> _getScreenResolution() async {
    if (!Platform.isWindows) return null;

    try {
      // 使用 EnumDisplaySettings API 获取真实物理分辨率
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        r'''
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DisplayInfo {
  [StructLayout(LayoutKind.Sequential)]
  public struct DEVMODE {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
    public string dmDeviceName;
    public short dmSpecVersion;
    public short dmDriverVersion;
    public short dmSize;
    public short dmDriverExtra;
    public int dmFields;
    public int dmPositionX;
    public int dmPositionY;
    public int dmDisplayOrientation;
    public int dmDisplayFixedOutput;
    public short dmColor;
    public short dmDuplex;
    public short dmYResolution;
    public short dmTTOption;
    public short dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
    public string dmFormName;
    public short dmLogPixels;
    public int dmBitsPerPel;
    public int dmPelsWidth;
    public int dmPelsHeight;
    public int dmDisplayFlags;
    public int dmDisplayFrequency;
    public int dmICMMethod;
    public int dmICMIntent;
    public int dmMediaType;
    public int dmDitherType;
    public int dmReserved1;
    public int dmReserved2;
    public int dmPanningWidth;
    public int dmPanningHeight;
  }
  [DllImport("user32.dll")]
  public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);
  public static void GetResolution() {
    DEVMODE dm = new DEVMODE();
    dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
    EnumDisplaySettings(null, -1, ref dm);
    Console.WriteLine(dm.dmPelsWidth + "," + dm.dmPelsHeight);
  }
}
"@
[DisplayInfo]::GetResolution()
''',
      ]);

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        final parts = output.split(',');
        if (parts.length == 2) {
          final width = int.tryParse(parts[0]);
          final height = int.tryParse(parts[1]);
          if (width != null && height != null) {
            debugPrint('检测到屏幕物理分辨率: ${width}x$height');
            return (width: width, height: height);
          }
        }
      }
    } catch (e) {
      debugPrint('获取屏幕分辨率失败: $e');
    }
    return null;
  }

  Future<File> _resizeAndCropImage(
    File imageFile,
    ({int width, int height}) targetSize,
  ) async {
    try {
      // 读取原始图片
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;

      final srcWidth = originalImage.width;
      final srcHeight = originalImage.height;
      final dstWidth = targetSize.width;
      final dstHeight = targetSize.height;

      // 计算缩放比例（覆盖整个目标区域）
      final scaleX = dstWidth / srcWidth;
      final scaleY = dstHeight / srcHeight;
      final scale = scaleX > scaleY ? scaleX : scaleY;

      // 计算缩放后的尺寸
      final scaledWidth = (srcWidth * scale).round();
      final scaledHeight = (srcHeight * scale).round();

      // 计算居中裁剪的偏移量
      final offsetX = ((scaledWidth - dstWidth) / 2).round();
      final offsetY = ((scaledHeight - dstHeight) / 2).round();

      // 创建画布
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 绘制缩放和裁剪后的图片
      final srcRect = Rect.fromLTWH(
        offsetX / scale,
        offsetY / scale,
        dstWidth / scale,
        dstHeight / scale,
      );
      final dstRect = Rect.fromLTWH(
        0,
        0,
        dstWidth.toDouble(),
        dstHeight.toDouble(),
      );

      canvas.drawImageRect(
        originalImage,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.high,
      );

      // 转换为图片
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(dstWidth, dstHeight);

      // 编码为 PNG
      final byteData = await finalImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw Exception('无法编码图片');
      }

      // 保存到临时文件
      final finalBytes = byteData.buffer.asUint8List();
      await imageFile.writeAsBytes(finalBytes, flush: true);

      debugPrint('图片已调整为屏幕分辨率: ${dstWidth}x$dstHeight (临时文件)');
      return imageFile;
    } catch (e) {
      debugPrint('调整图片尺寸失败: $e');
      return imageFile; // 失败时返回原始图片
    }
  }

  Future<File> _addCountdownToImage(File imageFile, AppConfig config) async {
    try {
      // 计算倒计时天数
      final targetDateStr = config.wallpaperCountdownDate.trim();
      if (targetDateStr.isEmpty) return imageFile;

      final target = DateTime.parse(targetDateStr);
      final today = DateTime.now();
      final targetDay = DateTime(target.year, target.month, target.day);
      final todayDay = DateTime(today.year, today.month, today.day);
      final daysRemaining = targetDay.difference(todayDay).inDays;

      final eventName = config.wallpaperCountdownEventName.trim();
      final copyright = _latest?.copyright ?? '';

      // 读取原始图片
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // 创建画布
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final imageWidth = image.width.toDouble();
      final imageHeight = image.height.toDouble();

      // 绘制原始图片
      canvas.drawImage(image, Offset.zero, Paint());

      // === 1. 绘制底部居中的描述信息（copyright） ===
      if (copyright.isNotEmpty) {
        _drawBottomCopyright(canvas, imageWidth, imageHeight, copyright);
      }

      // === 2. 绘制右侧日历形式的倒计时 ===
      _drawCalendarCountdown(
        canvas,
        imageWidth,
        imageHeight,
        daysRemaining,
        eventName,
      );

      // 转换为图片
      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(image.width, image.height);

      // 编码为 PNG
      final byteData = await finalImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw Exception('无法编码图片');
      }

      // 保存到临时文件
      final finalBytes = byteData.buffer.asUint8List();
      await imageFile.writeAsBytes(finalBytes, flush: true);
      debugPrint('已添加艺术化倒计时到临时文件');

      return imageFile;
    } catch (e) {
      // 如果处理失败，返回原始图片
      debugPrint('添加倒计时到图片失败: $e');
      return imageFile;
    }
  }

  /// 绘制底部居中的版权描述信息
  void _drawBottomCopyright(
    Canvas canvas,
    double imageWidth,
    double imageHeight,
    String copyright,
  ) {
    final padding = imageWidth * 0.03;
    final containerHeight = imageHeight * 0.08;
    final containerWidth = imageWidth * 0.6;
    final containerLeft = (imageWidth - containerWidth) / 2;
    final containerTop = imageHeight - containerHeight - padding;

    // 绘制半透明背景
    final backgroundPaint = Paint()
      ..color =
          const Color(0x33000000) // 黑色，20% 不透明度
      ..style = PaintingStyle.fill;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        containerLeft,
        containerTop,
        containerWidth,
        containerHeight,
      ),
      Radius.circular(containerHeight / 2),
    );

    canvas.drawRRect(rrect, backgroundPaint);

    // 绘制描述文本
    final textPainter = TextPainter(
      text: TextSpan(
        text: copyright,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: containerHeight * 0.35,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8,
          shadows: [
            Shadow(
              color: const Color(0x80000000),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    textPainter.layout(maxWidth: containerWidth - padding * 2);

    final textOffset = Offset(
      containerLeft + (containerWidth - textPainter.width) / 2,
      containerTop + (containerHeight - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  /// 绘制右侧日历形式的倒计时
  void _drawCalendarCountdown(
    Canvas canvas,
    double imageWidth,
    double imageHeight,
    int daysRemaining,
    String eventName,
  ) {
    // 日历卡片尺寸和位置
    final cardWidth = imageWidth * 0.22;
    final cardHeight = cardWidth * 1.3;
    final cardRight = imageWidth - imageWidth * 0.05;
    final cardLeft = cardRight - cardWidth;
    final cardTop = imageHeight * 0.15;

    // 绘制日历卡片主体 - 带渐变和阴影效果
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardLeft, cardTop, cardWidth, cardHeight),
      Radius.circular(cardWidth * 0.08),
    );

    // 阴影效果
    final shadowPaint = Paint()
      ..color = const Color(0x60000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawRRect(cardRect.shift(const Offset(0, 10)), shadowPaint);

    // 主背景 - 白色半透明毛玻璃效果
    final cardBackgroundPaint = Paint()
      ..color =
          const Color(0xE6FFFFFF) // 白色，90% 不透明度
      ..style = PaintingStyle.fill;
    canvas.drawRRect(cardRect, cardBackgroundPaint);

    // 顶部装饰条（模拟日历撕页）
    final headerHeight = cardHeight * 0.25;
    final headerRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(cardLeft, cardTop, cardWidth, headerHeight),
      topLeft: Radius.circular(cardWidth * 0.08),
      topRight: Radius.circular(cardWidth * 0.08),
    );

    final headerPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(cardLeft, cardTop),
        Offset(cardLeft, cardTop + headerHeight),
        [
          const Color(0xFFFF6B6B), // 渐变红色
          const Color(0xFFEE5A6F),
        ],
      );
    canvas.drawRRect(headerRect, headerPaint);

    // 绘制装饰性的螺旋孔
    final holeRadius = cardWidth * 0.025;
    final holePaint = Paint()
      ..color = const Color(0x40000000)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final holeX = cardLeft + cardWidth * (0.25 + i * 0.25);
      final holeY = cardTop + headerHeight * 0.15;
      canvas.drawCircle(Offset(holeX, holeY), holeRadius, holePaint);
    }

    // 绘制 "距离XX还有" 文本
    final titleText = eventName.isEmpty ? '倒计时' : '离 $eventName 还有';
    final titlePainter = TextPainter(
      text: TextSpan(
        text: titleText,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: cardWidth * 0.12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          shadows: [
            Shadow(
              color: const Color(0x40000000),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
    );
    titlePainter.layout(maxWidth: cardWidth * 0.85);

    final titleOffset = Offset(
      cardLeft + (cardWidth - titlePainter.width) / 2,
      cardTop + headerHeight * 0.35,
    );
    titlePainter.paint(canvas, titleOffset);

    // 绘制倒计时天数（大字）
    final daysText = daysRemaining >= 0
        ? '$daysRemaining'
        : '${daysRemaining.abs()}';
    final daysPainter = TextPainter(
      text: TextSpan(
        text: daysText,
        style: TextStyle(
          color: const Color(0xFF2C3E50),
          fontSize: cardWidth * 0.45,
          fontWeight: FontWeight.w900,
          letterSpacing: -2,
          shadows: [
            Shadow(
              color: const Color(0x30000000),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    daysPainter.layout(maxWidth: cardWidth * 0.9);

    final daysOffset = Offset(
      cardLeft + (cardWidth - daysPainter.width) / 2,
      cardTop +
          headerHeight +
          (cardHeight - headerHeight - daysPainter.height) / 2 -
          cardHeight * 0.07,
    );
    daysPainter.paint(canvas, daysOffset);

    // 绘制 "天" 字标签
    final labelText = daysRemaining >= 0 ? '天' : '天前';
    final labelPainter = TextPainter(
      text: TextSpan(
        text: labelText,
        style: TextStyle(
          color: const Color(0xFF7F8C8D),
          fontSize: cardWidth * 0.18,
          fontWeight: FontWeight.w600,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    labelPainter.layout();

    final labelOffset = Offset(
      cardLeft + (cardWidth - labelPainter.width) / 2,
      cardTop + cardHeight - cardHeight * 0.22,
    );
    labelPainter.paint(canvas, labelOffset);

    // 绘制装饰性边框
    final borderPaint = Paint()
      ..color = const Color(0x20000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(cardRect, borderPaint);
  }

  Future<bool> setAsDesktopWallpaper(String imagePath) async {
    if (!Platform.isWindows) {
      _error = '仅支持 Windows 桌面壁纸设置';
      notifyListeners();
      return false;
    }

    final escapedPath = imagePath.replaceAll("'", "''");
    final script =
        '''
Add-Type @"
using System.Runtime.InteropServices;
public class WallpaperSetter {
  [DllImport("user32.dll", SetLastError = true)]
  public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@;
[WallpaperSetter]::SystemParametersInfo(20, 0, '$escapedPath', 3) | Out-Null
''';

    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      script,
    ]);

    return result.exitCode == 0;
  }
}
