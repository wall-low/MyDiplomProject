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

**🎯 ОБЩИЙ ПРОГРЕСС: 90%** (было 80-85%)

**✅ ЗАВЕРШЕНО:**
- Миграция Firebase → PocketBase (100%)
- Система авторизации (100%)
- Чаты с файлами (текст, изображения, аудио) (100%)
- Система расписания + недельные шаблоны (100%)
- Расширенные профили репетиторов (100%)
- Поиск и фильтрация репетиторов (100%)
- Файловое хранилище (100% - PocketBase Storage)

**⏳ ОСТАЛОСЬ ДЛЯ ДИПЛОМА:**
- Система отзывов и рейтингов (0%)
- Система оплаты (mock) (0%)
- Deployment на VPS (0%)

**📅 ВРЕМЯ ДО ЗАЩИТЫ:** ~6 месяцев

---

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
  - ✅ **Изображения и аудио в чатах** - ПОЛНОСТЬЮ МИГРИРОВАНО на PocketBase Storage
- ✅ **Поиск репетиторов** - ПОЛНОСТЬЮ РЕАЛИЗОВАНО:
  - Фильтры: предметы, цена, опыт, город, формат занятий (онлайн/оффлайн)
  - Интеграция с tutor_profiles коллекцией
- ✅ **Расширенные профили репетиторов** - ПОЛНОСТЬЮ РЕАЛИЗОВАНО:
  - Модель TutorProfile (lib/models/tutor_profile.dart)
  - Сервис TutorProfileService (lib/service/tutor_profile_service.dart)
  - Страница заполнения TutorProfileSetupPage
  - Страница просмотра TutorProfilePage с градиентом и аватаром
  - Поля: subjects, priceMin/Max, experience, education, lessonFormat, rating, totalPaidLessons
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
  - Запись об оплате в PocketBase (для связи с отзывами)
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

- **weekly_template_service.dart**: ✨ **NEW** - Manages weekly schedule templates
  - `getWeeklyTemplates(tutorId)` - get all templates for tutor
  - `createTemplate()`, `updateTemplate()`, `deleteTemplate()` - CRUD operations
  - `generateSlotsFromTemplates(tutorId)` - auto-generate slots 28 days forward
  - Preserves booked slots when regenerating

#### Tutor Profile Management (lib/service/)
- **tutor_profile_service.dart**: ✨ **NEW** - Manages extended tutor profiles (extends ChangeNotifier)
  - `createTutorProfile()` - create profile with subjects, prices, experience, education
  - `getTutorProfileByUserId(userId)` - get profile by user ID
  - `getTutorProfileById(profileId)` - get profile by record ID
  - `updateTutorProfile()` - update profile fields
  - `deleteTutorProfile()` - delete profile
  - `checkIfTutorProfileExists(userId)` - check if profile exists
  - `updateRating()` - update rating after new review (TODO: integrate with review system)
  - `incrementPaidLessons()` - increment paid lessons counter
  - `searchTutors()` - advanced search with filters (subjects, price, rating, format)
  - Filter syntax: `subjects ?~ "Математика"` (JSON array contains check)

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

- **tutor_profile.dart**: ✨ **NEW** - Extended tutor information
  - Fields: id, userId, subjects (List<String>), priceMin, priceMax, experience (years), education, lessonFormat (List<String>), rating, totalPaidLessons, lastPaidLessonDate, isNewbie
  - Helper methods:
    - `getPriceDisplay()` - formatted price string ("500-1000 ₽/час")
    - `getExperienceDisplay()` - formatted experience ("3 года")
    - `getLessonFormatDisplay()` - formatted lesson format ("Онлайн и Оффлайн")
    - `getRatingDisplay()` - formatted rating or newbie badge
  - Includes `fromRecord()` for PocketBase conversion
  - Includes `toMap()` for updates
  - Works with PocketBase tutor_profiles collection

- **weekly_template.dart**: ✨ **NEW** - Weekly schedule template for tutors
  - Fields: id, tutorId, dayOfWeek (1-7), startTime, endTime, isActive
  - Allows tutors to set recurring weekly availability
  - Auto-generates slots 28 days forward
  - Works with PocketBase weekly_templates collection

#### Planned Models (to be added)
- **Review**: Student review for tutor
  - Fields: id, tutorId, studentId, rating (1-5), comment, timestamp, isVerified (paid lesson), lessonId, weight (based on total paid lessons)

- **Payment**: Payment transaction record
  - Fields: id, studentId, tutorId, slotId, amount, timestamp, status

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
  - Image picker with PocketBase Storage upload

- **profile_page.dart**: User profile view - ✨ **REDESIGNED**
  - Gradient SliverAppBar header with avatar
  - Role badge (Репетитор/Ученик) with icon
  - Info card: age, city, email
  - Bio card with edit capability
  - Settings button in AppBar
  - Username removed (not displayed)

- **find_tutor_page.dart**: Search/filter tutors - ✨ **UPDATED**
  - Full filter support: subjects (multi-select), price (min-max), experience, lesson format (online/offline), city, search by name
  - Integrates with TutorProfileService.searchTutors()
  - Shows TutorProfilePage on "Подробнее" button click

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

- **tutor_profile_page.dart**: ✨ **NEW** - Detailed tutor profile
  - Gradient SliverAppBar with avatar
  - Rating card with newbie badge support
  - Info cards: subjects, price, experience, education, lesson format
  - Bio section
  - Action buttons: "Написать" (opens chat), "Расписание" (shows tutor schedule)

- **tutor_profile_setup_page.dart**: ✨ **NEW** - Tutor profile creation/editing
  - Multi-select subjects (Математика, Физика, etc.)
  - Price range input (min/max)
  - Experience input (years)
  - Education text field
  - Lesson format checkboxes (online/offline)

- **weekly_template_setup_page.dart**: ✨ **NEW** - Weekly schedule template management
  - Day-by-day schedule setup (Monday-Sunday)
  - Time slot creation for each day
  - Auto-generation of slots 28 days forward
  - Preserves booked slots when regenerating

- **booking_requests_page.dart**: ✨ **NEW** - Booking requests for tutors
  - View pending booking requests from students
  - Approve or reject bookings
  - Supports recurring bookings (grouped display)

#### Pages to Add
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
- Singleton service: `lib/service/pocketbase_service.dart`
- Android emulator: `http://10.0.2.2:8090`
- iOS simulator: `http://localhost:8090`

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
  - bookingStatus (select: "free" | "pending" | "confirmed")
  - studentId (relation → users, optional)
  - generatedFromTemplate (bool, default: false)
  - templateId (relation → weekly_templates, optional)
  - isRecurring (bool, default: false)
  - recurringGroupId (text, optional)
  - created, updated (auto)

**weekly_templates** (Base Collection) ✨ **NEW**
- Purpose: Weekly schedule template for auto-generating slots
- Fields:
  - id (auto)
  - tutorId (relation → users)
  - dayOfWeek (number, 1-7: 1=Monday, 7=Sunday)
  - startTime (text) - HH:mm format
  - endTime (text) - HH:mm format
  - isActive (bool, default: true)
  - created, updated (auto)
- Process:
  1. Tutor sets up weekly templates via WeeklyTemplateSetupPage
  2. On "Apply", system generates slots 28 days forward
  3. Old free slots are deleted, booked slots are preserved
  4. New slots created with generatedFromTemplate=true

**reports** (Base Collection)
- Fields:
  - id (auto)
  - reportedBy (relation → users)
  - messageId (relation → messages)
  - messageOwnerId (relation → users)
  - created (auto)

**tutor_profiles** (Base Collection) ✨ **NEW**
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

#### Collections to Add

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

**РЕШЕНИЕ**: `ValueKey` + `_refreshKey` для принудительного пересоздания FutureBuilder.

**Три механизма:**
1. Auto-refresh on page load: `initState()` → `_refreshChats()`
2. Pull-to-refresh: `RefreshIndicator`
3. Auto-refresh after navigation from ChatPage

### Message Types
Messages support three types (stored in 'type' field):
- 'text': Plain text messages
- 'image': Images uploaded to PocketBase Storage via `sendMessageWithImage()` (file field in messages collection)
- 'audio': Audio files uploaded to PocketBase Storage via `sendMessageWithAudio()` (file field in messages collection)

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
- Filter reviews from last 6 months with `isVerified = true`
- Calculate weighted average: `sum(rating * weight) / sum(weight)`

### Search and Filter Implementation Notes

- **Subject**: Store as JSON array, filter with PocketBase syntax
- **Price**: Range filter on priceMin/priceMax fields
- **Rating**: Filter on rating field in tutor_profiles
- **Lesson Format**: JSON array: ["online", "offline", "both"]

### Audio Session
App configures AudioSession at startup (main.dart) for music playback support using flutter_sound and audioplayers packages.

### Permission Requirements
The app requires permissions for:
- Camera/Photo Library (avatars, image messages)
- Microphone (audio messages)
- Storage (file access)

Handled via permission_handler package.

### Complete Lesson Flow (Booking → Lesson → Payment → Review)

#### Main Flow:
1. Student searches/finds tutor → Opens profile → Views schedule
2. Books free slot (isBooked=true, NO payment yet)
3. Lesson takes place
4. **After lesson**: Auto payment dialog → Student pays (mock) → slot.isPaid=true
5. **After payment**: Auto review form → Student rates (stars) + comment → Verified review created
6. System updates tutor's weighted rating (6-month window)

#### Critical Rules:
- 🔴 Payment AFTER lesson, not before booking
- 🔴 Verified reviews (stars) only after payment
- 🔴 Unverified reviews (text only) without payment → don't affect rating
- 🔴 Rating weight = paid lessons count between student/tutor
- 🔴 New tutors (0 paid) show "🆕 Новичок на платформе"

### Known Issues

#### ✅ ИСПРАВЛЕНО в предыдущих сессиях:
- ✅ Registration error - `role` field wasn't passed during user creation (FIXED: added `'role': 'Ученик'` as default)
- ✅ Inefficient chat list loading - loading 500+ messages (FIXED: implemented two-table pattern with `chats` metadata)
- ✅ No auto-refresh on HomePage - FutureBuilder didn't update (FIXED: ValueKey pattern with three refresh mechanisms)
- ✅ Terminology inconsistency - "Преподаватель" vs "Репетитор" (FIXED: globally renamed to "Репетитор")
- ✅ Cloudinary dependency - FIXED: Полностью мигрировано на PocketBase Storage (аватары, изображения, аудио)
- ✅ TutorProfile collection - FIXED: Создана коллекция, реализованы CRUD операции, интегрирован поиск

#### 🔄 Опциональные улучшения:
- 🔄 **Realtime chat updates**: ChatPage использует polling вместо realtime subscriptions → можно улучшить позже

#### ⚠️ Старые баги (требуют проверки):
- ⚠️ chat_service.dart line 174: Возможная опечатка в markMessagesAsRead() - sorts [userID1, userID1] instead of [userID1, userID2] (ТРЕБУЕТ ПРОВЕРКИ)
- ⚠️ chat_service.dart line 161: Возможное несоответствие в getUnreadCount() - queries "message" instead of "messages" (ТРЕБУЕТ ПРОВЕРКИ)

## Migration Plan: Firebase → PocketBase

**Status: 90% ЗАВЕРШЕНО** ✨ (Steps 0-7 completed)

### Migration Steps:
- ✅ **Step 0**: PocketBase setup (Docker + collections)
- ✅ **Step 1**: Authentication (email/password)
- ✅ **Step 2**: User profiles
- ✅ **Step 3**: Chat system (two-table pattern + auto-refresh)
- ✅ **Step 4**: Schedule + Weekly Templates
- ✅ **Step 5**: Basic search (city, name)
- ✅ **Step 6**: Cloudinary → PocketBase Storage migration (avatars, images, audio)
- ✅ **Step 7**: Tutor profiles (tutor_profiles collection + CRUD + filters)

**Progress: 90% COMPLETED** 🎉

**Осталось для диплома:**
- ⏳ reviews collection + rating system (weighted calculation, 6-month window)
- ⏳ payments collection (mock payment flow)
- ⏳ Deploy to Russian VPS (Timeweb/Selectel)

## Development Priorities for Diploma

### Phase 1: Extended Tutor Profile ✅ **COMPLETED**
1. ✅ **DONE**: Создана детальная страница профиля (tutor_profile_page.dart)
2. ✅ **DONE**: Создана коллекция tutor_profiles в PocketBase
3. ✅ **DONE**: Реализована модель TutorProfile с полной сериализацией
4. ✅ **DONE**: Создан сервис TutorProfileService (CRUD + поиск)
5. ✅ **DONE**: Создана страница заполнения профиля (tutor_profile_setup_page.dart)
6. ✅ **DONE**: Интеграция с find_tutor_page.dart (фильтры по предметам, цене, опыту, формату)
7. ✅ **DONE**: Система недельного шаблона расписания (WeeklyTemplateSetupPage)

### Phase 2: Reviews and Ratings (ТЕКУЩИЙ ПРИОРИТЕТ)
1. Create reviews model and collection
2. Implement payment simulation flow
3. Add review creation after paid lesson
4. Calculate and display weighted ratings
5. Show "Newbie" badge for new tutors

### Phase 3: Payment System
1. Create payments model and collection
2. Implement mock payment dialog after lesson
3. Update slot.isPaid = true on payment
4. Integrate with review system (payment → review flow)
5. Payment history page

### Phase 4: Deployment & Polish
1. Payment history page
2. Push notifications (можно использовать другой сервис вместо FCM)
3. Google Sign-In (опционально)
4. Polish UI/UX
