import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:p7/config/server_config.dart';

enum ServerMode { local, vps }

class PocketBaseService extends ChangeNotifier {
  static final PocketBaseService _instance = PocketBaseService._internal();
  late PocketBase _pb;
  bool _initialized = false;
  ServerMode _serverMode = ServerMode.local;

  // Дефолтные URL берутся из server_config.dart (файл в .gitignore)
  static const String _defaultLocalUrl = ServerConfig.localUrl;
  static const String _defaultVpsUrl = ServerConfig.vpsUrl;

  String _localUrl = _defaultLocalUrl;
  String _vpsUrl = _defaultVpsUrl;

  factory PocketBaseService() {
    return _instance;
  }

  PocketBaseService._internal();

  ServerMode get serverMode => _serverMode;
  String get localUrl => _localUrl;
  String get vpsUrl => _vpsUrl;
  String get currentUrl => _serverMode == ServerMode.local ? _localUrl : _vpsUrl;

  Future<void> init() async {
    if (_initialized) return;

    // Загружаем сохранённые настройки
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('server_mode');
    if (savedMode == 'vps') {
      _serverMode = ServerMode.vps;
    }
    _localUrl = prefs.getString('local_url') ?? _defaultLocalUrl;
    _vpsUrl = prefs.getString('vps_url') ?? _defaultVpsUrl;

    String baseUrl = currentUrl;

    final dir = await getApplicationDocumentsDirectory();
    final authFile = File('${dir.path}/pb_auth.json');

    String initialToken = '';
    try {
      if (await authFile.exists()) {
        initialToken = await authFile.readAsString();
      }
    } catch (e) {
      debugPrint('[PocketBase] Ошибка загрузки токена: $e');
    }

    final store = AsyncAuthStore(
      save: (String data) async {
        try {
          await authFile.writeAsString(data);
        } catch (e) {
          debugPrint('[PocketBase] Ошибка сохранения токена: $e');
        }
      },
      initial: initialToken,
    );

    _pb = PocketBase(baseUrl, authStore: store);

    _initialized = true;
    debugPrint('[PocketBase] Initialized with URL: $baseUrl');
    debugPrint('[PocketBase] Auth token loaded: ${_pb.authStore.isValid}');
  }

  /// Переключить сервер (локальный ↔ VPS)
  Future<void> switchServer(ServerMode mode) async {
    if (_serverMode == mode) return;

    _serverMode = mode;

    // Сохраняем выбор
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_mode', mode == ServerMode.vps ? 'vps' : 'local');

    // Пересоздаём PocketBase клиент с новым URL, сохраняя auth store
    final oldStore = _pb.authStore;
    _pb = PocketBase(currentUrl, authStore: oldStore);

    debugPrint('[PocketBase] Switched to: $currentUrl');
    notifyListeners();
  }

  /// Обновить URL сервера
  Future<void> updateUrl(ServerMode mode, String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    if (mode == ServerMode.local) {
      _localUrl = trimmed;
      await prefs.setString('local_url', trimmed);
    } else {
      _vpsUrl = trimmed;
      await prefs.setString('vps_url', trimmed);
    }

    // Если изменили URL активного сервера — пересоздаём клиент
    if (_serverMode == mode) {
      final oldStore = _pb.authStore;
      _pb = PocketBase(currentUrl, authStore: oldStore);
      debugPrint('[PocketBase] URL updated, reconnected to: $currentUrl');
    }

    notifyListeners();
  }

  PocketBase get client => _pb;

  RecordModel? get currentUser => _pb.authStore.model;

  bool get isAuthenticated => _pb.authStore.isValid;

  String get token => _pb.authStore.token;

  void clearAuth() {
    _pb.authStore.clear();
    debugPrint('[PocketBase] Auth cleared');
  }

  String getFileUrl(RecordModel record, String filename, {String? thumb}) {
    if (filename.isEmpty) return '';

    return _pb.getFileUrl(
      record,
      filename,
      thumb: thumb,
    ).toString();
  }

  String getUserAvatarUrl(RecordModel user, {String thumb = '100x100'}) {
    final avatar = user.data['avatar'] as String?;
    if (avatar == null || avatar.isEmpty) {
      return '';
    }
    return getFileUrl(user, avatar, thumb: thumb);
  }

  Future<RecordModel> uploadAvatar({
    required String userId,
    required String filePath,
  }) async {
    try {
      debugPrint('[PocketBase] 📤 uploadAvatar START');
      debugPrint('[PocketBase] 👤 User ID: $userId');
      debugPrint('[PocketBase] 📁 File path: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Файл не найден: $filePath');
      }

      final fileSize = await file.length();
      debugPrint('[PocketBase] 📦 File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      debugPrint('[PocketBase] 🔨 Creating MultipartFile...');
      final multipartFile = await http.MultipartFile.fromPath('avatar', filePath);
      debugPrint('[PocketBase] ✅ MultipartFile created: ${multipartFile.filename}');

      debugPrint('[PocketBase] 🚀 Sending update request to PocketBase...');
      debugPrint('[PocketBase] 🌐 URL: ${_pb.baseUrl}/api/collections/users/records/$userId');

      final record = await _pb.collection('users').update(
        userId,
        files: [multipartFile],
      );

      debugPrint('[PocketBase] ✅ Avatar uploaded successfully!');
      debugPrint('[PocketBase] 📄 Record ID: ${record.id}');
      debugPrint('[PocketBase] 📄 Avatar filename: ${record.data['avatar']}');

      return record;
    } catch (e, stackTrace) {
      debugPrint('[PocketBase] ❌ ERROR uploading avatar: $e');
      debugPrint('[PocketBase] 📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

}
