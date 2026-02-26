# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**"Учеба рядом"** - это дипломный проект: маркетплейс для частных репетиторов и учеников на Flutter с PocketBase backend.

### Концепция
Платформа для прямого взаимодействия репетиторов и учеников. В отличие от онлайн-школ, здесь каждый репетитор может зарегистрироваться самостоятельно, а ученик - найти подходящего специалиста по предмету, цене и рейтингу.

### Backend: Переход на PocketBase
**Причина миграции:** Риск блокировки Firebase в РФ перед защитой диплома (через 6 месяцев).

**Почему PocketBase:**
- ✅ Self-hosted - полный контроль, можно хостить на российских серверах
- ✅ Один исполняемый файл - простой деплой
- ✅ Встроенная Admin UI для управления данными
- ✅ Realtime subscriptions как в Firebase
- ✅ Встроенное файловое хранилище (замена Cloudinary)
- ✅ Authentication из коробки (email/password, OAuth)
- ✅ Flutter SDK: `pocketbase` package
- ✅ SQLite - проще для диплома
- ✅ Open source - никогда не заблокируют

### Целевая аудитория
- **Ученики**: школьники, студенты, взрослые, нуждающиеся в дополнительных занятиях
- **Репетиторы**: специалисты, желающие находить учеников без посредников

## Project Status

### ✅ Уже реализовано
- ✅ **Авторизация через PocketBase** (email/password) - МИГРИРОВАНО
- ✅ **Роли пользователей** (Репетитор/Ученик) - терминология обновлена
- ✅ **Базовые профили** с данными из PocketBase - МИГРИРОВАНО
- ✅ **Детальный профиль репетитора** (tutor_profile_page.dart):
  - Дизайн с gradient header и аватаром
  - Карточки с информацией о репетиторе
  - Кнопки "Написать" и "Расписание"
  - Навигация из find_tutor_page через кнопку "Подробнее"
- ✅ **Чат система** - ПОЛНОСТЬЮ МИГРИРОВАНО:
  - Текстовые сообщения через PocketBase
  - Двух-табличная архитектура (`messages` + `chats` metadata)
  - Auto-refresh списка чатов (pull-to-refresh + auto-reload)
  - Непрочитанные сообщения с счётчиками
- 🔄 **Изображения и аудио в чатах** - используют Cloudinary (ПЛАНИРУЕТСЯ МИГРАЦИЯ на PocketBase Storage)
- ✅ **Поиск репетиторов** по городу
- ✅ **Система расписания** - ПОЛНОСТЬЮ ОБНОВЛЕНА:
  - Добавление/удаление слотов вручную
  - Бронирование слотов учениками
  - **Недельный шаблон расписания** (weekly_templates):
    - Настройка графика по дням недели (Пн-Вс)
    - Автоматическая генерация слотов на 28 дней вперёд
    - Копирование понедельника на будни (Вт-Пт)
    - Сохранение забронированных слотов при пересоздании шаблона
    - Отдельная страница WeeklyTemplateSetupPage для управления
- ✅ **Блокировка пользователей**
- ✅ **Светлая/тёмная тема** с сохранением предпочтений

### 🚧 Нужно добавить для диплома
- **Профиль репетитора** (расширенный):
  - ✅ UI страницы готов (tutor_profile_page.dart)
  - ⏳ Предметы преподавания (список с возможностью множественного выбора)
  - ⏳ Стоимость занятия (диапазон или фиксированная цена)
  - ⏳ Опыт работы (лет)
  - ⏳ Образование (учебное заведение, специальность)
  - ⏳ Рейтинг и отзывы

- **Поиск и фильтрация**:
  - Поиск по предмету (основной фильтр)
  - Фильтр по цене (мин-макс)
  - Фильтр по рейтингу
  - Фильтр онлайн/оффлайн занятия
  - Сортировка результатов

- **Система отзывов и рейтингов** (детальная):
  - Отзыв только после завершённого занятия
  - Рейтинг (1-5 звёзд) только при оплате через приложение
  - Текстовые отзывы доступны всем, но помечаются как "неверифицированные"
  - Рейтинг учитывает только занятия за последние 6 месяцев
  - Вес отзыва зависит от количества оплаченных занятий с этим учеником
  - Новые репетиторы получают бейдж "🆕 Новичок на платформе"
  - В профиле: "Рейтинг 4.9 ⭐ (24 оплаченных занятия)" + "3 отзыва от учеников"

- **Система оплаты**:
  - Имитация оплаты для диплома (кнопка "Оплатить", без реального платежа)
  - Запись об оплате в Firestore (для связи с отзывами)
  - История оплаченных занятий

- **Дополнительные фичи**:
  - Push-уведомления (Firebase Cloud Messaging)
  - История занятий
  - Google Sign-In (дополнительно к email)

## Build & Development Commands

### Setup
```bash
# Install dependencies
flutter pub get

# Generate launcher icons
flutter pub run flutter_launcher_icons

# Clean build artifacts
flutter clean
```

### Running the App
```bash
# Run on connected device/emulator (debug mode)
flutter run

# Run with specific device
flutter run -d <device_id>

# List available devices
flutter devices

# Hot reload: press 'r' in terminal
# Hot restart: press 'R' in terminal
```

### Building
```bash
# Build APK (Android)
flutter build apk

# Build iOS (requires macOS)
flutter build ios

# Build with release mode
flutter build apk --release
```

### Testing & Analysis
```bash
# Run tests
flutter test

# Analyze code
flutter analyze
```

## Architecture Overview

### State Management
- **Provider Pattern**: Used extensively for state management
- **ThemProvider** (lib/themes/theme_provider.dart): Manages app theme (light/dark mode) with SharedPreferences persistence
- **DatabaseProvider** (lib/service/database_provider.dart): Wraps database operations with ChangeNotifier for reactive UI updates
- **ChatService** (lib/service/chat_service.dart): Extends ChangeNotifier for real-time chat features
- **ScheduleService** (lib/service/schedule_service.dart): Extends ChangeNotifier for schedule management

### Core Services (Migrating from Firebase to PocketBase)

#### Authentication Flow (lib/service/)
- **auth_gate.dart**: Entry point that orchestrates authentication state
  - ~~Checks if user is authenticated via Firebase~~ → **Migrate to PocketBase auth**
  - If authenticated but profile incomplete → RegisterProfilePage
  - If authenticated with complete profile → HomePage
  - If not authenticated → LoginOrRegister
- **auth.dart**: ~~Firebase~~ **PocketBase** Authentication wrapper
  - `loginEmailPassword(email, password)` - вход → **use pb.collection('users').authWithPassword()**
  - `registerEmailPassword(email, password)` - регистрация → **use pb.collection('users').create()**
  - `logout()` - выход → **use pb.authStore.clear()**
  - `changePassword()` - смена пароля → **use pb.collection('users').update()**
  - **NEW:** Auto-persist auth state via pb.authStore (SharedPreferences)
- **login_or_register.dart**: Toggles between login and registration pages

#### Database Layer (lib/service/)
- **databases.dart**: ~~Primary Firestore~~ **PocketBase** interface
  - User profile management (CRUD operations) → **use pb.collection('users')**
  - Tutor filtering (role-based queries) → **use pb.collection('users').getList(filter: 'role="tutor"')**
  - City aggregation for search filters → **SQL query or client-side aggregation**
  - Methods to update:
    - ~~`saveInfoInFirebase()`~~ → `saveInfoInPocketBase()`
    - ~~`getUserFromFirebase()`~~ → `getUserFromPocketBase()`
    - `updateUserProfile()` → **use pb.collection('users').update()**
    - `getTutorsStream()` → **use pb.collection('users').subscribe()** (realtime)
    - `getAllCities()` → **query distinct cities**
- **database_provider.dart**: Provider wrapper for reactive database operations
- **chat_service.dart**: ~~Chat-specific Firestore~~ **PocketBase** operations
  - Message sending (text, image, audio) → **pb.collection('messages').create()**
  - Real-time message streams → **pb.collection('messages').subscribe()**
  - User blocking/reporting → **pb.collection('blocked_users').create()**
  - Unread message tracking → **filter isRead=false**
  - Methods: `sendMessage()`, `getMessage()`, `blockUser()`, `markMessagesAsRead()`, `getUnreadCount()`

#### File Uploads
- ~~**cloudinary_service.dart**: Handles media uploads to Cloudinary~~ → **DELETE**
- **NEW: PocketBase Storage** (built-in)
  - Avatar images → stored in users collection (avatar field)
  - Audio/image messages → stored as files in PocketBase
  - Upload: `pb.collection('users').update(id, formData)` with FormData
  - File URLs: auto-generated by PocketBase, accessed via `pb.getFileUrl(record, filename)`
  - **Advantage:** No external service needed, simpler code

#### Schedule Management (lib/service/)
- **schedule_service.dart**: Manages tutor availability slots (extends ChangeNotifier)
  - `getTutorSchedule(tutorId)` - all slots for a tutor
  - `getTutorScheduleByDate(tutorId, date)` - slots for specific date
  - `getAvailableSlots(tutorId)` - only unbooked slots
  - `addSlot()`, `deleteSlot()`, `updateSlot()` - CRUD operations
  - `bookSlot(slotId, studentId)` - student books a slot
  - `cancelBooking(slotId)` - cancel booking
  - Stores date normalized (time set to 00:00:00) for consistent querying

### Data Models (lib/models/)

#### Current Models
- **user.dart**: UserProfile model with PocketBase serialization
  - Current fields: uid, name, email, username, birthDate, city, role, bio, avatarUrl
  - Includes `copyWith()` for immutable updates
  - Includes `fromRecord()` for PocketBase RecordModel conversion

- **messenge.dart**: Message model supporting text, image, and audio types
  - Fields: senderID, senderEmail, receiverID, message, timestamp, type, isRead
  - Convenience getters: isText, isImage, isAudio
  - Works with PocketBase messages collection

- **chat.dart**: ✨ **NEW** - Chat metadata model for efficient chat list display
  - Fields: id, chatRoomId, user1Id, user2Id, lastMessage, lastMessageType, lastSenderId, lastTimestamp, unreadCountUser1, unreadCountUser2
  - Helper methods:
    - `getUnreadCount(userId)` - get unread count for specific user
    - `getOtherUserId(currentUserId)` - get conversation partner's ID
    - `getLastMessagePreview()` - formatted preview ("📷 Фото", "🎵 Аудио", or text)
  - Includes `fromRecord()` for PocketBase conversion
  - Part of two-table chat architecture (see Chat Architecture below)

- **schedule_slot.dart**: Tutor availability slot
  - Fields: id, tutorId, date, startTime, endTime, isBooked, studentId, createdAt
  - Getter: isPast (checks if slot has passed)
  - Works with PocketBase slots collection

#### Planned Models (to be added)
- **Review**: Student review for tutor
  - Fields: id, tutorId, studentId, rating (1-5), comment, timestamp, isVerified (paid lesson), lessonId, weight (based on total paid lessons)

- **Subject**: Teaching subject
  - Fields: id, name, category (e.g., "Математика", "Физика")

- **Payment**: Payment transaction record
  - Fields: id, studentId, tutorId, slotId, amount, timestamp, status

- **TutorProfile**: Extended tutor information
  - Fields: subjects (List<String>), priceMin, priceMax, experience (years), education, rating, totalPaidLessons, lastPaidLessonDate, isNewbie

### UI Structure (lib/pages/)

#### Navigation Architecture
- **main_navigation.dart**: ✨ **NEW** - Bottom Navigation Bar (заменил Drawer)
  - 4 вкладки: Чаты, Поиск, График, Профиль
  - Uses IndexedStack для сохранения состояния страниц
  - Settings вынесены в AppBar ProfilePage
  - Logout перенесен в SettingPage

#### Authentication Pages
- **login_page.dart**: Email/password authentication
- **register_page.dart**: Email/password registration
- **register_profile_page.dart**: Post-signup profile completion (name, birthDate, city, role)

#### Main Pages
- **home_page.dart**: Chat list with last message preview and unread counts
  - ✨ **UPDATED**: Uses FutureBuilder with `getUserChatsFromMetadata()` (fast metadata query)
  - Auto-refresh mechanisms:
    - `initState()` refresh on page load
    - Pull-to-refresh with `RefreshIndicator`
    - Auto-refresh when returning from ChatPage
  - Uses `ValueKey(_refreshKey)` to force FutureBuilder reload
  - Shows avatar, username, last message preview, timestamp, unread badge
  - Empty state with helpful message and refresh hint

- **chat_page.dart**: Individual chat interface
  - Supports text, image, and audio messages
  - Implements scroll position caching per chat
  - Auto-marks messages as read when viewed
  - Audio recording with upload progress
  - Image picker with Cloudinary upload

- **profile_page.dart**: User profile view - ✨ **REDESIGNED**
  - Gradient SliverAppBar header with avatar
  - Role badge (Репетитор/Ученик) with icon
  - Info card: age, city, email
  - Bio card with edit capability
  - Settings button in AppBar
  - Username removed (not displayed)

- **find_tutor_page.dart**: Search/filter tutors
  - Current: filter by city, search by name
  - TODO: filter by subject, price, rating, online/offline

- **schedule_page.dart**: Schedule management - ✨ **DUAL-MODE**
  - **Tutors** ("М О Е   Р А С П И С А Н И Е"):
    - Date selector with calendar picker
    - Add/delete availability slots by date and time
    - View slots for selected date
    - Floating Action Button to add new slot
  - **Students** ("М О И   З А Н Я Т И Я"):
    - View ALL booked lessons (all dates)
    - No date selector (shows everything)
    - No FAB (can't create slots)
  - Uses ScheduleService for reactive updates

- **setting_page.dart**: App settings - ✨ **UPDATED**
  - Theme toggle (ThemProvider) - переключение светлой/темной темы
  - Account settings (change password)
  - Blocked users management
  - **Logout** button with confirmation dialog (moved from Drawer)

- **blocked_user_page.dart**: Manage blocked users list

#### Pages to Add
- **tutor_detail_page.dart**: Detailed tutor profile with subjects, price, experience, education, reviews
- **reviews_page.dart**: List of all reviews for a tutor
- **payment_history_page.dart**: History of paid lessons

### Reusable Components (lib/components/)
- **user_tile.dart**: Chat list item with avatar, username, last message, timestamp, unread badge
- **chat_bubble.dart**: Message display with sender/receiver styling
- **audio_player_widget.dart**: Audio message playback control with progress
- **avatar_picker.dart**: Image picker for profile photos (camera/gallery) - ✅ **FIXED**
  - Uploads to PocketBase Storage via `files` parameter
  - Shows loading indicator and success/error messages
  - Detailed logging for debugging
- **user_avatar.dart**: Cached avatar display with fallback
- **my_text_field.dart / input_box.dart**: Custom text inputs
- **my_button.dart**: Styled button component
- **bio_box.dart**: Profile bio display/edit
- **load_animation.dart**: Loading indicators

#### Components to Add
- **rating_display.dart**: Show star rating with count of paid lessons
- **review_card.dart**: Display individual review with verification badge
- **subject_chip.dart**: Display teaching subject as chip
- **price_filter.dart**: Price range filter widget
- **tutor_card.dart**: Tutor card for search results

### PocketBase Configuration

**📋 Database Schema (ВАЖНО - читай первым!):**

Файл `database_schema.dbml` в корне проекта содержит **актуальную структуру БД**:
- ✅ Все существующие коллекции (users, messages, chats, slots, blocked_users, reports)
- ⏳ Планируемые коллекции (tutor_profiles, reviews, payments)
- 📊 Типы полей PocketBase (text, date, bool, select, file, relation)
- 🔗 Связи между таблицами
- 📝 Статус миграции Firebase → PocketBase

**Как использовать:**
1. Открой `database_schema.dbml` перед работой с БД
2. Визуализация: скопируй содержимое на https://dbdiagram.io/
3. При изменении структуры - обновляй этот файл!

#### Installation & Setup

**Вариант 1: Docker (рекомендуется)**
```bash
# Перейди в папку pocketbase
cd pocketbase

# Запусти через docker-compose
docker-compose up -d

# Проверь статус
docker-compose ps

# Посмотри логи
docker-compose logs -f

# Admin UI: http://localhost:8090/_/
# API: http://localhost:8090/api/
```

**Вариант 2: Локальный бинарник**
```bash
# Скачай PocketBase (latest version)
# https://github.com/pocketbase/pocketbase/releases

# Запусти локально
./pocketbase serve

# Admin UI: http://127.0.0.1:8090/_/
# API: http://127.0.0.1:8090/api/
```

**Файлы Docker:**
- `pocketbase/Dockerfile` - образ PocketBase
- `pocketbase/docker-compose.yml` - конфигурация запуска
- `pocketbase/.dockerignore` - игнорируемые файлы
- `pocketbase/README.md` - подробная документация по deployment

#### Flutter Package
```yaml
dependencies:
  pocketbase: ^0.18.0  # Official Dart SDK
```

#### Flutter Connection Setup
```dart
// lib/service/pocketbase_service.dart
import 'package:pocketbase/pocketbase.dart';

class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  late final PocketBase pb;

  factory PocketBaseService() {
    return _instance;
  }

  PocketBaseService._internal() {
    // Для локальной разработки (Docker)
    String baseUrl;
    if (Platform.isAndroid) {
      baseUrl = 'http://10.0.2.2:8090'; // Android emulator → host machine
    } else if (Platform.isIOS) {
      baseUrl = 'http://localhost:8090'; // iOS simulator
    } else {
      baseUrl = 'http://localhost:8090'; // Desktop/Web
    }

    // Для продакшена (VPS)
    // baseUrl = 'https://your-domain.com';

    pb = PocketBase(baseUrl);
  }

  PocketBase get client => pb;
}

// Использование:
final pb = PocketBaseService().client;
```

#### Current Collections (migrated from Firestore)

**users** (Auth Collection - built-in)
- Fields:
  - id (auto)
  - email (text, required, unique)
  - username (text, required, unique)
  - name (text, required)
  - birthDate (date)
  - city (text)
  - role (select: "student" | "tutor")
  - bio (text, optional)
  - avatar (file, single, max 5MB)
  - created, updated (auto)

**blocked_users** (Base Collection)
- Fields:
  - id (auto)
  - userId (relation → users)
  - blockedUserId (relation → users)
  - created (auto)

**messages** (Base Collection)
- Fields:
  - id (auto)
  - chatRoomId (text, indexed) - format: "uid1_uid2" (alphabetically sorted)
  - senderId (relation → users)
  - senderEmail (text)
  - receiverId (relation → users)
  - message (text) - text content or file URL
  - type (select: "text" | "image" | "audio")
  - isRead (bool, default: false)
  - created (auto)
- Indexes: chatRoomId, senderId, receiverId

**chats** (Base Collection) ✨ **NEW**
- Purpose: Pre-computed chat metadata for fast home page loading
- Fields:
  - id (auto)
  - chatRoomId (text, required, min:1, max:200) - format: "uid1_uid2"
  - user1Id (relation → users, cascade delete)
  - user2Id (relation → users, cascade delete)
  - lastMessage (text, optional, max:500)
  - lastMessageType (select: "text" | "image" | "audio")
  - lastSenderId (relation → users)
  - lastTimestamp (date, required)
  - unreadCountUser1 (number, optional, min:0)
  - unreadCountUser2 (number, optional, min:0)
  - created, updated (auto)
- API Rules (all operations): `user1Id = @request.auth.id || user2Id = @request.auth.id`
- Auto-updated by `_createOrUpdateChatRoom()` after each message

**slots** (Base Collection)
- Fields:
  - id (auto)
  - tutorId (relation → users)
  - date (date)
  - startTime (text) - HH:mm format
  - endTime (text) - HH:mm format
  - isBooked (bool, default: false)
  - isPaid (bool, default: false)
  - studentId (relation → users, optional)
  - created, updated (auto)

**reports** (Base Collection)
- Fields:
  - id (auto)
  - reportedBy (relation → users)
  - messageId (relation → messages)
  - messageOwnerId (relation → users)
  - created (auto)

#### Collections to Add

**tutor_profiles** (Base Collection)
- Fields:
  - id (auto)
  - userId (relation → users, unique)
  - subjects (json) - array of strings
  - priceMin (number)
  - priceMax (number)
  - experience (number) - years
  - education (text)
  - lessonFormat (json) - array: ["online", "offline", "both"]
  - rating (number, default: 0)
  - totalPaidLessons (number, default: 0)
  - lastPaidLessonDate (date, optional)
  - isNewbie (bool, default: true)
  - created, updated (auto)

**reviews** (Base Collection)
- Fields:
  - id (auto)
  - tutorId (relation → users)
  - studentId (relation → users)
  - rating (number, 1-5, required for verified)
  - comment (text, optional)
  - isVerified (bool) - true if paid lesson
  - lessonId (relation → slots, optional)
  - weight (number) - calculated from paid lessons count
  - created (auto)
- Indexes: tutorId + created (for 6-month filtering)

**payments** (Base Collection)
- Fields:
  - id (auto)
  - studentId (relation → users)
  - tutorId (relation → users)
  - slotId (relation → slots)
  - amount (number)
  - status (select: "pending" | "completed" | "failed")
  - created (auto)
- Note: Имитация оплаты для диплома (без реального платежного провайдера)

### Theme System (lib/themes/)
- **light_mode.dart**: Светлая тема (мягкий серый `#F5F5F7`, синий акцент `#4A90E2`)
- **dark_mode.dart**: Темная тема (черный `#000000`, синий акцент `#5BA4F5`)
- **theme_provider.dart**: Theme switching with SharedPreferences persistence
- User preference saved under key 'isDarkMode'
- **Оценка**: 9/10 - минималистичный iOS-style дизайн, хорошая контрастность для проектора

## Important Implementation Notes

### Chat Architecture (Two-Table Pattern)

**ПРОБЛЕМА (Firebase subcollections):**
Firebase использовал структуру:
```
chat_room/{chatRoomId} (metadata document)
  └─ messages/{messageId} (subcollection)
```
PocketBase НЕ поддерживает subcollections!

**РЕШЕНИЕ (Two-Table Pattern):**
Разделили данные на две коллекции:

1. **`messages` collection** - все сообщения (data layer)
   - Хранит: senderId, receiverId, message, type, isRead, timestamp
   - Используется в ChatPage для показа истории сообщений
   - Запрос: `filter: 'chatRoomId="uid1_uid2"'` + `sort: 'created'`

2. **`chats` collection** - метаданные чатов (metadata layer)
   - Хранит: lastMessage, lastMessageType, lastTimestamp, unreadCountUser1, unreadCountUser2
   - Используется в HomePage для быстрого отображения списка чатов
   - Запрос: `filter: 'user1Id="currentUserId" || user2Id="currentUserId"'` + `sort: '-lastTimestamp'`
   - **Преимущество**: 1 запрос вместо загрузки 500+ сообщений и группировки

**Автоматическое обновление метаданных:**
```dart
// chat_service.dart
Future<void> _createOrUpdateChatRoom({...}) async {
  // Проверяем существование чата
  final existing = await pb.collection('chats').getList(
    filter: 'chatRoomId="$chatRoomId"',
    perPage: 1,
  );

  if (existing.items.isNotEmpty) {
    // UPDATE: обновляем lastMessage, lastTimestamp, увеличиваем unreadCount
    await pb.collection('chats').update(recordId, body: {...});
  } else {
    // CREATE: создаём новую запись метаданных
    await pb.collection('chats').create(body: {...});
  }
}
```

Этот метод вызывается после КАЖДОЙ отправки сообщения:
- `sendMessage()` → `_createOrUpdateChatRoom()`
- `sendMessageWithImage()` → `_createOrUpdateChatRoom()`
- `sendMessageWithAudio()` → `_createOrUpdateChatRoom()`

**Производительность:**
- ❌ **ДО**: `getActiveChats()` загружал 500+ messages → группировал по chatRoomId → N+1 запросов → 2-5 секунд
- ✅ **ПОСЛЕ**: `getUserChatsFromMetadata()` делает 1 запрос к chats → 100-300ms

### Chat Room ID Generation
Chat rooms use deterministic IDs by sorting user UIDs alphabetically:
```dart
List<String> ids = [userId1, userId2];
ids.sort();
String chatRoomId = ids.join('_');
```
This ensures the same chatroom for any pair of users regardless of who initiates.

### Auto-Refresh Pattern (FutureBuilder with Manual Reload)

**ПРОБЛЕМА**: FutureBuilder загружает данные только при первом билде виджета. Если данные изменились (новое сообщение в БД), UI не обновляется автоматически.

**РЕШЕНИЕ**: Используем `ValueKey` + `_refreshKey` для принудительного пересоздания FutureBuilder:

```dart
class _HomePageState extends State<HomePage> {
  int _refreshKey = 0;

  void _refreshChats() {
    setState(() {
      _refreshKey++; // Изменяем ключ → FutureBuilder пересоздаётся → future вызывается заново
    });
  }

  @override
  void initState() {
    super.initState();
    _refreshChats(); // Auto-refresh при открытии страницы
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Chat>>(
      key: ValueKey(_refreshKey), // При изменении ключа FutureBuilder пересоздаётся
      future: _chatService.getUserChatsFromMetadata(),
      builder: (context, snapshot) {
        // Оборачиваем в RefreshIndicator для pull-to-refresh
        return RefreshIndicator(
          onRefresh: () async {
            _refreshChats();
            await Future.delayed(Duration(milliseconds: 500));
          },
          child: ListView.builder(...),
        );
      },
    );
  }
}
```

**Три механизма авто-обновления:**
1. **Auto-refresh on page load**: `initState()` → `_refreshChats()`
2. **Pull-to-refresh**: `RefreshIndicator` → пользователь тянет вниз → `_refreshChats()`
3. **Auto-refresh after navigation**:
   ```dart
   await Navigator.push(context, ChatPage(...));
   _refreshChats(); // Обновляем после возврата из чата
   ```

**Альтернативы (НЕ использованы):**
- ❌ StreamBuilder - требует реализации realtime subscriptions (сложнее)
- ❌ Manual refresh button - плохой UX, требует действия от пользователя
- ✅ ValueKey pattern - простой, работает с любым Future

### Message Types
Messages support three types (stored in 'type' field):
- 'text': Plain text messages
- 'image': Cloudinary URLs stored in 'message' field
- 'audio': Cloudinary audio URLs stored in 'message' field

### Rating System Logic (for implementation)

#### Rating Calculation Rules
1. **Verification**: Only paid lessons generate verified ratings (1-5 stars)
2. **Time Window**: Only reviews from last 6 months count toward rating
3. **Weight System**: Review weight = number of paid lessons between student and tutor
   - Example: 1 student × 10 paid lessons = weight of 10
   - Example: 5 students × 1 paid lesson each = weight of 5
4. **Newbie Badge**: Tutors with 0 paid lessons show "🆕 Новичок на платформе" instead of rating
5. **Display Format**: "Рейтинг 4.9 ⭐ (24 оплаченных занятия)" + separate count of text reviews

#### Review Creation Flow
1. Student completes a lesson (slot becomes past due)
2. If lesson was paid → can leave verified rating (stars) + optional comment
3. If lesson was not paid → can only leave unverified comment (no stars)
4. Review updates if same student leaves another review (weight increases)

#### Rating Query Strategy
```dart
// Get reviews from last 6 months
final sixMonthsAgo = DateTime.now().subtract(Duration(days: 180));
final reviewsQuery = FirebaseFirestore.instance
  .collection('Reviews')
  .where('tutorId', isEqualTo: tutorId)
  .where('timestamp', isGreaterThan: sixMonthsAgo)
  .where('isVerified', isEqualTo: true);

// Calculate weighted average
double calculateRating(List<Review> reviews) {
  if (reviews.isEmpty) return 0.0;

  double totalWeightedRating = 0;
  int totalWeight = 0;

  for (var review in reviews) {
    totalWeightedRating += review.rating * review.weight;
    totalWeight += review.weight;
  }

  return totalWeightedRating / totalWeight;
}
```

### Search and Filter Implementation Notes

#### Subject Search
- Store subjects as array in TutorProfile
- Use `arrayContains` for filtering: `.where('subjects', arrayContains: selectedSubject)`

#### Price Filter
- Query with range: `.where('priceMin', isLessThanOrEqualTo: maxPrice).where('priceMax', isGreaterThanOrEqualTo: minPrice)`
- Note: Firestore compound queries may require composite index

#### Rating Filter
- Calculate rating on client side or use Cloud Functions to maintain `rating` field in TutorProfile
- Filter: `.where('rating', isGreaterThanOrEqualTo: minRating)`

#### Online/Offline Filter
- Add `lessonFormat` field to TutorProfile: ['online', 'offline', 'both']
- Filter: `.where('lessonFormat', arrayContains: selectedFormat)`

### Audio Session
App configures AudioSession at startup (main.dart) for music playback support using flutter_sound and audioplayers packages.

### Permission Requirements
The app requires permissions for:
- Camera/Photo Library (avatars, image messages)
- Microphone (audio messages)
- Storage (file access)

Handled via permission_handler package.

### Complete Lesson Flow (Booking → Lesson → Payment → Review)

**ВАЖНО: Это полный цикл занятия, описывающий правильную последовательность действий**

#### Main Flow (25 steps):
1. Student searches for tutors using filters (subject, city, price, rating)
2. System displays filtered tutor list
3. Student opens tutor's detailed profile
4. System shows tutor info (name, experience, education, subjects, price, rating, reviews)
5. Student clicks "View Schedule"
6. System displays available slots (date, time, price)
7. Student selects free slot and clicks "Book" (NOT "Book and Pay")
8. System books slot (isBooked = true, studentId) and sends notification to tutor
9. System saves lesson to student's "My Lessons"
10. **Lesson takes place** (offline or online)
11. After lesson end time, system automatically sets slot to isPast = true
12. **System automatically opens payment dialog** with lesson info and amount
13. Student clicks "Pay" and confirms
14. Payment system (mock) processes payment and returns "Success"
15. System creates Payment record (status: 'completed') and updates slot (isPaid = true)
16. System updates tutor profile (totalPaidLessons +1, lastPaidLessonDate) and sends notification
17. **System automatically opens review form**
18. Student rates (1-5 stars) and writes text comment
19. Student submits review
20. System calculates review weight (count of paid lessons between this student and tutor)
21. System saves verified review (isVerified = true, with weight and rating)
22. System recalculates tutor's weighted average rating (last 6 months only)
23. System updates tutor's rating field in profile
24. System sends push notification to tutor about new review
25. Updated rating displays in tutor profile for all users

#### Key Alternative Scenarios:
- **A3: Chat communication** (between steps 9-10): Optional, only if student/tutor needs to clarify details
- **A4: Cancel booking** (before step 10): Student cancels → slot freed → no payment, no review
- **A5: Lesson didn't happen** (step 12): Student reports problem → complaint saved → no payment
- **A6: Student postpones payment** (step 13): Lesson saved as "Unpaid" → can only leave unverified text review (no stars)
- **A10: Unverified review** (alternative to step 17): If unpaid → form shows only text field (NO stars) → review saved as isVerified = false → rating NOT recalculated

#### Critical Business Rules:
- 🔴 **Payment happens AFTER lesson completion**, not before booking
- 🔴 **Payment dialog appears automatically** after lesson end time
- 🔴 **Verified reviews (with stars) only available after payment**
- 🔴 **Unverified reviews (text only) available without payment** but marked and don't affect rating
- 🔴 **Rating calculation uses only verified reviews from last 6 months**
- 🔴 **Review weight = number of paid lessons between student and tutor**
- 🔴 **New tutors (0 paid lessons) show "🆕 Новичок на платформе" badge instead of rating**

### Known Issues

#### ✅ ИСПРАВЛЕНО в предыдущей сессии:
- ✅ Registration error - `role` field wasn't passed during user creation (FIXED: added `'role': 'Ученик'` as default)
- ✅ Inefficient chat list loading - loading 500+ messages (FIXED: implemented two-table pattern with `chats` metadata)
- ✅ No auto-refresh on HomePage - FutureBuilder didn't update (FIXED: ValueKey pattern with three refresh mechanisms)
- ✅ Terminology inconsistency - "Преподаватель" vs "Репетитор" (FIXED: globally renamed to "Репетитор")

#### 🔄 Текущие задачи:
- 🔄 **Cloudinary dependency**: Изображения и аудио в чатах используют внешний сервис Cloudinary → **ПЛАНИРУЕТСЯ миграция на PocketBase Storage**
- 🔄 **Realtime chat updates**: ChatPage использует polling вместо realtime subscriptions → можно улучшить позже

#### ⚠️ Старые баги (требуют проверки):
- ⚠️ chat_service.dart line 174: Возможная опечатка в markMessagesAsRead() - sorts [userID1, userID1] instead of [userID1, userID2] (ТРЕБУЕТ ПРОВЕРКИ)
- ⚠️ chat_service.dart line 161: Возможное несоответствие в getUnreadCount() - queries "message" instead of "messages" (ТРЕБУЕТ ПРОВЕРКИ)

## Migration Plan: Firebase → PocketBase

### Code Examples: Before → After

#### Authentication
```dart
// BEFORE (Firebase)
final userCredential = await FirebaseAuth.instance
    .signInWithEmailAndPassword(email: email, password: password);

// AFTER (PocketBase)
final authData = await pb.collection('users')
    .authWithPassword(email, password);
final user = authData.record;
```

#### Get User Profile
```dart
// BEFORE (Firebase)
final doc = await FirebaseFirestore.instance
    .collection('Users')
    .doc(uid)
    .get();
final user = UserProfile.fromDocument(doc);

// AFTER (PocketBase)
final record = await pb.collection('users').getOne(uid);
final user = UserProfile.fromRecord(record);
```

#### Realtime Messages
```dart
// BEFORE (Firebase)
FirebaseFirestore.instance
    .collection('chat_room')
    .doc(chatRoomId)
    .collection('messages')
    .orderBy('timestamp', descending: true)
    .snapshots();

// AFTER (PocketBase)
pb.collection('messages').subscribe('*', (e) {
  // e.action: 'create', 'update', 'delete'
  // e.record: message record
}, filter: 'chatRoomId="$chatRoomId"');

// Or use getList() with auto-refresh
```

#### File Upload
```dart
// BEFORE (Cloudinary)
final response = await cloudinary.uploadFile(
  CloudinaryFile.fromFile(file.path, folder: 'avatars'),
);
final avatarUrl = response.secureUrl;

// AFTER (PocketBase)
final formData = FormData();
formData.files.add(MapEntry(
  'avatar',
  MultipartFile.fromFileSync(file.path),
));
await pb.collection('users').update(userId, body: formData);

// Get URL: pb.getFileUrl(userRecord, userRecord.data['avatar'])
```

### Step 0: Setup PocketBase ✅ COMPLETED
1. ✅ **Docker setup complete** - файлы созданы:
   - `pocketbase/Dockerfile`
   - `pocketbase/docker-compose.yml`
   - `pocketbase/.dockerignore`
   - `pocketbase/README.md`
2. ✅ PocketBase запущен (Docker)
3. ✅ Admin UI настроен: http://localhost:8090/_/
4. ✅ Коллекции созданы через Admin UI:
   - ✅ users (Auth Collection) + доп. поля (username, name, birthDate, city, role, bio, avatar)
   - ✅ messages (chatRoomId, senderId, receiverId, message, type, isRead)
   - ✅ chats (chatRoomId, user1Id, user2Id, lastMessage, lastMessageType, lastTimestamp, unreadCounts) - **NEW**
   - ✅ slots (tutorId, date, startTime, endTime, isBooked, isPaid, studentId)
   - ✅ blocked_users (userId, blockedUserId)
   - ✅ reports (reportedBy, messageId, messageOwnerId)
5. ✅ Flutter зависимость добавлена: `pocketbase: ^0.18.0` в `pubspec.yaml`
6. ✅ Создан `lib/service/pocketbase_service.dart` - Singleton для подключения

### Step 1: Authentication Migration ✅ COMPLETED
1. ✅ Created `lib/service/pocketbase_service.dart` - PocketBase client wrapper (Singleton pattern)
2. ✅ Updated `lib/service/auth.dart`:
   - ✅ Replaced Firebase Auth with PocketBase Auth
   - ✅ Implemented `pb.collection('users').authWithPassword()`
   - ✅ Implemented `pb.collection('users').create()` for registration
   - ✅ **FIXED**: Added `'role': 'Ученик'` as default during registration
   - ✅ Auto-persist via `pb.authStore` (SharedPreferences)
3. ✅ Tested login/register/logout flows
4. ✅ Firebase dependency removed

### Step 2: User Profile Migration ✅ COMPLETED
1. ✅ Updated `lib/service/databases.dart`:
   - ✅ Replaced all Firestore calls with PocketBase
   - ✅ Migrated `getUserFromFirebase()` → `getUserFromPocketBase()`
   - ✅ Updated `saveInfoInFirebase()` → `saveInfoInPocketBase()`
   - ✅ **FIXED**: Terminology renamed "Преподаватель" → "Репетитор" globally
2. 🔄 Avatar uploads still use Cloudinary (ПЛАНИРУЕТСЯ миграция на PocketBase Storage)
3. ✅ Profile view/edit functionality tested

### Step 3: Chat System Migration ✅ COMPLETED
1. ✅ Updated `lib/service/chat_service.dart`:
   - ✅ Replaced Firestore messages with PocketBase messages collection
   - ✅ **NEW**: Implemented two-table pattern (`messages` + `chats` metadata)
   - ✅ **NEW**: Created `_createOrUpdateChatRoom()` for automatic metadata updates
   - ✅ **NEW**: Created `getUserChatsFromMetadata()` for fast chat list loading
   - ✅ Integrated metadata updates into all message sending methods
2. ✅ Updated `lib/models/chat.dart` - новая модель для метаданных
3. ✅ Updated `lib/pages/home_page.dart`:
   - ✅ Switched from `getActiveChats()` to `getUserChatsFromMetadata()`
   - ✅ **NEW**: Implemented auto-refresh with ValueKey pattern
   - ✅ **NEW**: Added pull-to-refresh with RefreshIndicator
   - ✅ **NEW**: Auto-refresh on page load and after returning from chat
4. ✅ Text message sending tested ✅
5. 🔄 Image/audio uploads still use Cloudinary (ПЛАНИРУЕТСЯ миграция на PocketBase Storage)
6. 🔄 Realtime updates use polling (можно улучшить с pb.collection('messages').subscribe())

### Step 4: Schedule System Migration ✅ COMPLETED + ENHANCED
1. ✅ Updated `lib/service/schedule_service.dart`:
   - Replaced Firestore slots with PocketBase slots collection
   - Updated CRUD operations
   - Migrated date/time handling
   - ✅ **NEW**: Added template-based generation (generateSlotsFromTemplate, clearGeneratedFreeSlots)
2. ✅ Tested slot creation, booking, cancellation
3. ✅ Dual-mode UI: tutors see slots by date, students see all bookings
4. ✅ **NEW**: Weekly Template System:
   - Created `lib/models/weekly_template.dart` model
   - Created `lib/service/weekly_template_service.dart` with CRUD operations
   - Created `lib/pages/weekly_template_setup_page.dart` UI for template management
   - Updated ScheduleSlot model with generatedFromTemplate, templateId, isPaid fields
   - Integrated template button into SchedulePage AppBar
   - Auto-generation of slots on 28-day rolling window

### Step 5: Search & Filters ✅ COMPLETED (Basic)
1. ✅ Updated `lib/pages/find_tutor_page.dart`:
   - Replaced Firestore queries with PocketBase filters
   - Uses filter syntax: `filter: 'role="tutor" && city="Moscow"'`
2. ✅ Tested tutor search by city, name
3. ⏳ Advanced filters (subjects, price, rating) - planned for Phase 1

### Step 6: Cleanup
1. 🔄 Remove Cloudinary dependencies from `pubspec.yaml` (ПОСЛЕ миграции на PocketBase Storage)
2. 🔄 Delete `lib/service/cloudinary_service.dart` (ПОСЛЕ миграции на PocketBase Storage)
3. ✅ Firebase dependencies removed
4. ✅ Firebase config files deleted
5. 🔄 Test full app flow end-to-end (ФИНАЛЬНОЕ ТЕСТИРОВАНИЕ)

**Progress:**
- ✅ **COMPLETED**: Steps 0-5 (Setup, Auth, Profiles, Chat System, Schedule, Basic Search) - ~12-14 days
- 🔄 **REMAINING**: Step 6 (Cleanup + Cloudinary migration to PocketBase Storage) - ~2-3 days
- **Total migration time**: ~14-17 days (80-85% ЗАВЕРШЕНО)

**Текущие задачи для диплома:**
- ✅ **DONE**: Система недельного шаблона расписания (weekly_templates collection + UI)
- ✅ **DONE**: Детальный профиль репетитора (tutor_profile_page.dart с дизайном)
- ⏳ Миграция файлов на PocketBase Storage (изображения/аудио в чатах)
- ⏳ Создание tutor_profiles collection (предметы, цена, опыт, образование)
- ⏳ Система отзывов и рейтингов (reviews collection)
- ⏳ Имитация оплаты (payments collection)

### Step 7: Deploy to Production
1. Buy Russian VPS (Timeweb, Selectel, или другой)
2. Deploy PocketBase with systemd/docker
3. Setup HTTPS with Let's Encrypt
4. Update Flutter app with production PocketBase URL
5. Test on real devices

## Development Priorities for Diploma (AFTER Migration)

### Phase 1: Extended Tutor Profile
1. ✅ **DONE**: Создана детальная страница профиля (tutor_profile_page.dart)
2. ⏳ Add subjects, price, experience, education fields to tutor_profiles collection
3. ⏳ Update TutorProfilePage to show real data from tutor_profiles
4. ⏳ Update find_tutor_page.dart with subject/price filters
5. ✅ **DONE**: Система недельного шаблона расписания (WeeklyTemplateSetupPage)

### Phase 2: Reviews and Ratings
1. Create reviews model and collection
2. Implement payment simulation flow
3. Add review creation after paid lesson
4. Calculate and display weighted ratings
5. Show "Newbie" badge for new tutors

### Phase 3: Enhanced Search
1. Multi-filter support (subject + price + rating)
2. Sort options (rating, price, experience)
3. Favorites functionality
4. Search result improvements

### Phase 4: Additional Features
1. Payment history page
2. Push notifications (можно использовать другой сервис вместо FCM)
3. Google Sign-In (опционально)
4. Polish UI/UX
