import 'dart:io';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  late final PocketBase _pb;
  bool _initialized = false;

  factory PocketBaseService() {
    return _instance;
  }

  PocketBaseService._internal() {
  }

  Future<void> init() async {
    if (_initialized) return;

    String baseUrl = _getBaseUrl();

    final dir = await getApplicationDocumentsDirectory();
    final authFile = File('${dir.path}/pb_auth.json');

    String initialToken = '';
    try {
      if (await authFile.exists()) {
        initialToken = await authFile.readAsString();
      }
    } catch (e) {
      print('[PocketBase] Ошибка загрузки токена: $e');
    }

    final store = AsyncAuthStore(
      save: (String data) async {
        try {
          await authFile.writeAsString(data);
        } catch (e) {
          print('[PocketBase] Ошибка сохранения токена: $e');
        }
      },
      initial: initialToken,
    );

    _pb = PocketBase(baseUrl, authStore: store);

    _initialized = true;
    print('[PocketBase] Initialized with URL: $baseUrl');
    print('[PocketBase] Auth token loaded: ${_pb.authStore.isValid}');
  }

  PocketBase get client => _pb;

  RecordModel? get currentUser => _pb.authStore.model;

  bool get isAuthenticated => _pb.authStore.isValid;

  String get token => _pb.authStore.token;

  String _getBaseUrl() {
    const bool USE_REAL_DEVICE = true;

    if (USE_REAL_DEVICE) {
      return 'http://192.168.31.125:8090';

    } else {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8090';
      } else if (Platform.isIOS) {
        return 'http://localhost:8090';
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        return 'http://localhost:8090';
      } else {
        return 'http://localhost:8090';
      }
    }
  }

  void clearAuth() {
    _pb.authStore.clear();
    print('[PocketBase] Auth cleared');
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
      print('[PocketBase] 📤 uploadAvatar START');
      print('[PocketBase] 👤 User ID: $userId');
      print('[PocketBase] 📁 File path: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Файл не найден: $filePath');
      }

      final fileSize = await file.length();
      print('[PocketBase] 📦 File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      print('[PocketBase] 🔨 Creating MultipartFile...');
      final multipartFile = await http.MultipartFile.fromPath('avatar', filePath);
      print('[PocketBase] ✅ MultipartFile created: ${multipartFile.filename}');

      print('[PocketBase] 🚀 Sending update request to PocketBase...');
      print('[PocketBase] 🌐 URL: ${_pb.baseUrl}/api/collections/users/records/$userId');

      final record = await _pb.collection('users').update(
        userId,
        files: [multipartFile],
      );

      print('[PocketBase] ✅ Avatar uploaded successfully!');
      print('[PocketBase] 📄 Record ID: ${record.id}');
      print('[PocketBase] 📄 Avatar filename: ${record.data['avatar']}');

      return record;
    } catch (e, stackTrace) {
      print('[PocketBase] ❌ ERROR uploading avatar: $e');
      print('[PocketBase] 📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

}
