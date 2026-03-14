import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:p7/service/auth_gate.dart';
import 'package:p7/service/database_provider.dart';
import 'package:p7/service/notification_service.dart';
import 'package:p7/service/pocketbase_service.dart';
import 'package:p7/themes/theme_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PocketBaseService().init();
  await NotificationService().init();

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());

  runApp(
    MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => ThemProvider()),

          ChangeNotifierProvider(create: (context) => DatabaseProvider()),
        ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

@override
  Widget build(BuildContext context) {
    // TODO: implement build
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
      theme: Provider.of<ThemProvider>(context).themeData,
    );
  }
}
