import 'dart:io';
import 'package:pocketbase/pocketbase.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// PocketBase Service - Singleton для подключения к PocketBase
///
/// Использование:
/// ```dart
/// final pb = PocketBaseService().client;
/// await pb.collection('users').getList();
/// ```
class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  late final PocketBase _pb;
  bool _initialized = false;

  factory PocketBaseService() {
    return _instance;
  }

  PocketBaseService._internal() {
    // Инициализация происходит асинхронно в init()
    // Пока создаем PocketBase без AsyncAuthStore (будет заменен в init)
  }

  /// НОВЫЙ МЕТОД: Асинхронная инициализация с AsyncAuthStore
  ///
  /// ПРОБЛЕМА (старый код):
  /// PocketBase(baseUrl) создает in-memory AuthStore
  /// Токен НЕ сохраняется после rebuild виджета или перезапуска
  ///
  /// РЕШЕНИЕ:
  /// Использовать AsyncAuthStore для автоматического сохранения токена
  ///
  /// AsyncAuthStore сохраняет токен в файл на устройстве
  /// При следующем запуске приложения токен загружается автоматически
  ///
  /// ВАЖНО: Этот метод должен быть вызван в main() перед runApp()!
  Future<void> init() async {
    if (_initialized) return;

    // Определяем URL в зависимости от платформы
    String baseUrl = _getBaseUrl();

    // Получаем путь к директории для сохранения токена
    final dir = await getApplicationDocumentsDirectory();
    final authFile = File('${dir.path}/pb_auth.json');

    // Загружаем сохраненный токен (если есть)
    String initialToken = '';
    try {
      if (await authFile.exists()) {
        initialToken = await authFile.readAsString();
      }
    } catch (e) {
      print('[PocketBase] Ошибка загрузки токена: $e');
    }

    // Создаем AsyncAuthStore с правильным синтаксисом
    final store = AsyncAuthStore(
      save: (String data) async {
        // Сохраняем токен в файл при каждом изменении
        try {
          await authFile.writeAsString(data);
        } catch (e) {
          print('[PocketBase] Ошибка сохранения токена: $e');
        }
      },
      initial: initialToken, // initial принимает String, а не функцию!
    );

    // Создаем PocketBase клиент с AsyncAuthStore
    _pb = PocketBase(baseUrl, authStore: store);

    _initialized = true;
    print('[PocketBase] Initialized with URL: $baseUrl');
    print('[PocketBase] Auth token loaded: ${_pb.authStore.isValid}');
  }

  /// Получить PocketBase клиент
  PocketBase get client => _pb;

  /// Получить текущего авторизованного пользователя
  RecordModel? get currentUser => _pb.authStore.model;

  /// Проверить авторизован ли пользователь
  bool get isAuthenticated => _pb.authStore.isValid;

  /// Получить токен авторизации
  String get token => _pb.authStore.token;

  /// Определить базовый URL в зависимости от платформы и окружения
  String _getBaseUrl() {
    // ============================================================================
    // ПРОДАКШЕН: Раскомментируй эту строку и укажи свой домен
    // ============================================================================
    // return 'https://your-domain.com';

    // ============================================================================
    // ЛОКАЛЬНАЯ РАЗРАБОТКА
    // ============================================================================

    // ВАЖНО: Для реального iPhone/Android устройства используй IP компьютера!
    //
    // Как узнать IP компьютера:
    // macOS: ifconfig | grep "inet " | grep -v 127.0.0.1
    // Windows: ipconfig
    // Linux: ip addr show

    const bool USE_REAL_DEVICE = true; // 👈 ИЗМЕНИ НА true ДЛЯ РЕАЛЬНОГО УСТРОЙСТВА

    if (USE_REAL_DEVICE) {
      // ========================================================================
      // ДЛЯ РЕАЛЬНОГО iPhone/Android УСТРОЙСТВА
      // ========================================================================
      // Устройство должно быть в той же WiFi сети что и компьютер!
      return 'http://192.168.31.190:8090'; // 👈 ОБНОВЛЕНО: Реальный IP Mac

    } else {
      // ========================================================================
      // ДЛЯ ЭМУЛЯТОРА/СИМУЛЯТОРА
      // ========================================================================
      if (Platform.isAndroid) {
        // Android emulator -> host machine
        return 'http://10.0.2.2:8090';
      } else if (Platform.isIOS) {
        // iOS simulator -> host machine
        return 'http://localhost:8090';
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        // Desktop platforms
        return 'http://localhost:8090';
      } else {
        // Web или другие платформы
        return 'http://localhost:8090';
      }
    }
  }

  /// Очистить хранилище авторизации (logout)
  void clearAuth() {
    _pb.authStore.clear();
    print('[PocketBase] Auth cleared');
  }

  /// Получить URL файла из PocketBase
  ///
  /// Пример:
  /// ```dart
  /// final avatarUrl = getFileUrl(userRecord, userRecord.data['avatar']);
  /// ```
  String getFileUrl(RecordModel record, String filename, {String? thumb}) {
    if (filename.isEmpty) return '';

    return _pb.getFileUrl(
      record,
      filename,
      thumb: thumb,
    ).toString();
  }

  /// Получить URL аватара пользователя с thumbnail
  String getUserAvatarUrl(RecordModel user, {String thumb = '100x100'}) {
    final avatar = user.data['avatar'] as String?;
    if (avatar == null || avatar.isEmpty) {
      return ''; // Вернем пустую строку, UI покажет fallback
    }
    return getFileUrl(user, avatar, thumb: thumb);
  }

  /// Загрузить аватар пользователя
  ///
  /// ЗАМЕНА Cloudinary.uploadAvatar()
  ///
  /// БЫЛО (Cloudinary):
  /// ```dart
  /// final url = await CloudinaryService.uploadAvatar(filePath: path);
  /// await firestore.collection('Users').doc(uid).update({'avatarUrl': url});
  /// ```
  ///
  /// СТАЛО (PocketBase):
  /// ```dart
  /// final record = await uploadAvatar(userId: uid, filePath: path);
  /// final url = getUserAvatarUrl(record);
  /// ```
  ///
  /// ОТЛИЧИЯ:
  /// - Cloudinary возвращает полный URL сразу
  /// - PocketBase возвращает RecordModel, URL генерируем через getFileUrl()
  /// - PocketBase сохраняет файл И обновляет запись одним запросом
  ///
  /// Параметры:
  /// - userId: ID пользователя (record ID в коллекции users)
  /// - filePath: Путь к файлу на устройстве
  ///
  /// Возвращает обновленный RecordModel с новым аватаром
  Future<RecordModel> uploadAvatar({
    required String userId,
    required String filePath,
  }) async {
    try {
      print('[PocketBase] 📤 uploadAvatar START');
      print('[PocketBase] 👤 User ID: $userId');
      print('[PocketBase] 📁 File path: $filePath');

      // Проверяем существование файла
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Файл не найден: $filePath');
      }

      final fileSize = await file.length();
      print('[PocketBase] 📦 File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      // Создаём MultipartFile
      print('[PocketBase] 🔨 Creating MultipartFile...');
      final multipartFile = await http.MultipartFile.fromPath('avatar', filePath);
      print('[PocketBase] ✅ MultipartFile created: ${multipartFile.filename}');

      // ИСПРАВЛЕНИЕ: Передаем файл в параметр files, а не в body!
      //
      // БЫЛО (НЕПРАВИЛЬНО):
      // body: {'avatar': multipartFile} ❌ - PocketBase SDK не умеет конвертировать MultipartFile в JSON
      //
      // СТАЛО (ПРАВИЛЬНО):
      // files: [multipartFile] ✅ - PocketBase SDK сам обработает файлы
      //
      // PocketBase SDK имеет два параметра:
      // - body: Map<String, dynamic> - для обычных полей (текст, числа, etc)
      // - files: List<http.MultipartFile> - для файлов
      print('[PocketBase] 🚀 Sending update request to PocketBase...');
      print('[PocketBase] 🌐 URL: ${_pb.baseUrl}/api/collections/users/records/$userId');

      final record = await _pb.collection('users').update(
        userId,
        files: [multipartFile], // ✅ Передаем в параметр files!
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

  /// Загрузить изображение для чата
  ///
  /// ЗАМЕНА Cloudinary.uploadImage()
  ///
  /// ОТЛИЧИЕ от uploadAvatar():
  /// - Не обновляет запись пользователя
  /// - Создает новую запись в коллекции (например, messages)
  /// - Или возвращает URL для использования в message.message поле
  ///
  /// TODO: Определить структуру хранения изображений в чате
  /// Варианты:
  /// 1. Хранить файл в коллекции messages (поле imageFile)
  /// 2. Хранить URL в поле message (как сейчас с Cloudinary)
  ///
  /// Для совместимости временно возвращаем URL строку
  Future<String> uploadChatImage({
    required String filePath,
    required String chatRoomId,
  }) async {
    try {
      print('[PocketBase] 📸 uploadChatImage START');
      print('[PocketBase] 📁 File path: $filePath');
      print('[PocketBase] 💬 Chat room: $chatRoomId');

      // Создаём MultipartFile
      final file = await http.MultipartFile.fromPath('imageFile', filePath);
      print('[PocketBase] ✅ MultipartFile created: ${file.filename}');

      // ИСПРАВЛЕНИЕ: Используем параметр files вместо body для файла!
      //
      // БЫЛО (НЕПРАВИЛЬНО):
      // body: {'imageFile': file, ...} ❌
      //
      // СТАЛО (ПРАВИЛЬНО):
      // body: {...} - только обычные поля
      // files: [file] - файлы отдельно ✅
      print('[PocketBase] 🚀 Creating message with image...');

      final record = await _pb.collection('messages').create(
        body: {
          'chatRoomId': chatRoomId,
          'type': 'image',
          'message': '', // Пустое сообщение, файл - основной контент
        },
        files: [file], // ✅ Передаем файл в параметр files!
      );

      // Получаем URL файла
      final imageUrl = getFileUrl(record, record.data['imageFile']);

      print('[PocketBase] ✅ Изображение загружено для чата: $chatRoomId');
      print('[PocketBase] 🌐 Image URL: $imageUrl');

      return imageUrl;
    } catch (e, stackTrace) {
      print('[PocketBase] ❌ ERROR uploading image: $e');
      print('[PocketBase] 📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Загрузить аудио для чата
  ///
  /// ЗАМЕНА Cloudinary.uploadAudio()
  ///
  /// Аналогично uploadChatImage(), но для аудио файлов
  Future<String> uploadChatAudio({
    required String filePath,
    required String chatRoomId,
  }) async {
    try {
      print('[PocketBase] 🎵 uploadChatAudio START');
      print('[PocketBase] 📁 File path: $filePath');
      print('[PocketBase] 💬 Chat room: $chatRoomId');

      // Создаём MultipartFile
      final file = await http.MultipartFile.fromPath('audioFile', filePath);
      print('[PocketBase] ✅ MultipartFile created: ${file.filename}');

      // ИСПРАВЛЕНИЕ: Используем параметр files вместо body для файла!
      //
      // БЫЛО (НЕПРАВИЛЬНО):
      // body: {'audioFile': file, ...} ❌
      //
      // СТАЛО (ПРАВИЛЬНО):
      // body: {...} - только обычные поля
      // files: [file] - файлы отдельно ✅
      print('[PocketBase] 🚀 Creating message with audio...');

      final record = await _pb.collection('messages').create(
        body: {
          'chatRoomId': chatRoomId,
          'type': 'audio',
          'message': '', // Пустое сообщение, файл - основной контент
        },
        files: [file], // ✅ Передаем файл в параметр files!
      );

      // Получаем URL файла
      final audioUrl = getFileUrl(record, record.data['audioFile']);

      print('[PocketBase] ✅ Аудио загружено для чата: $chatRoomId');
      print('[PocketBase] 🌐 Audio URL: $audioUrl');

      return audioUrl;
    } catch (e, stackTrace) {
      print('[PocketBase] ❌ ERROR uploading audio: $e');
      print('[PocketBase] 📋 Stack trace: $stackTrace');
      rethrow;
    }
  }
}
