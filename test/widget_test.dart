import 'package:flutter_test/flutter_test.dart';
import 'package:seewo_helper/main.dart';
import 'package:seewo_helper/services/config_service.dart';
import 'package:seewo_helper/services/event_listen_service.dart';
import 'package:seewo_helper/services/wallpaper_service.dart';
import 'package:seewo_helper/services/hotspot_service.dart';
import 'package:seewo_helper/services/upload_service.dart';

void main() {
  testWidgets('App renders with navigation rail', (tester) async {
    final configService = ConfigService();
    await configService.initialize();
    final eventListenService = EventListenService();

    await tester.pumpWidget(MyApp(
      configService: configService,
      eventListenService: eventListenService,
      wallpaperService: WallpaperService(),
      hotspotService: HotspotService(),
      uploadService: UploadService(),
      shouldHideWindow: false,  // 测试时不要隐藏窗口
    ));
    await tester.pumpAndSettle();

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('监听'), findsOneWidget);
    expect(find.text('壁纸'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
