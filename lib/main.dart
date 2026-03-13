import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'core/theme.dart';
import 'screens/main_screen.dart';
import 'services/alert_service.dart';
import 'services/juggluco_service.dart';
import 'services/notification_plugin.dart';
import 'services/offline_cache_service.dart';
import 'services/user_profile_service.dart';
import 'services/wellness_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 1. SharedPreferences-backed services
  await UserProfileService().init();
  await OfflineCacheService().init();

  // 2. Notification plugin — initialize exactly once before any service uses it
  await initNotificationPlugin();

  // 3. Timezone — must be initialized before WellnessService schedules notifications
  tz.initializeTimeZones();
  final tzName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(tzName));

  // 4. Services that send notifications
  await AlertService().init();
  await WellnessService().init();

  // 5. Juggluco CGM polling
  JugglucoService().start();

  runApp(const CgmApp());
}

class CgmApp extends StatelessWidget {
  const CgmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "GlucoTrack",
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}
