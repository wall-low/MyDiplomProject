import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:p7/service/auth_gate.dart';
import 'package:p7/service/database_provider.dart';
import 'package:p7/service/pocketbase_service.dart';
import 'package:p7/themes/theme_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // НОВОЕ: Инициализация PocketBase с AsyncAuthStore
  //
  // ВАЖНО: Должно быть вызвано ПЕРЕД runApp()!
  //
  // AsyncAuthStore автоматически:
  // 1. Загружает сохраненный токен при старте приложения
  // 2. Сохраняет новый токен после успешного входа
  // 3. Удаляет токен после выхода
  //
  // Без этого токен будет теряться после каждого rebuild виджета
  await PocketBaseService().init();

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
