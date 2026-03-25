# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**"Учеба рядом"** - это дипломный проект: маркетплейс для частных репетиторов и учеников на Flutter с PocketBase backend.

### Концепция
Платформа для прямого взаимодействия репетиторов и учеников. В отличие от онлайн-школ, здесь каждый репетитор может зарегистрироваться самостоятельно, а ученик - найти подходящего специалиста по предмету, цене и рейтингу.

### Backend: PocketBase (полностью мигрировано с Firebase)
**Причина миграции:** Риск блокировки Firebase в РФ перед защитой диплома.

**Почему PocketBase:**
- Self-hosted - полный контроль, можно хостить на российских серверах
- Один исполняемый файл - простой деплой
- Встроенная Admin UI для управления данными
- Realtime subscriptions как в Firebase
- Встроенное файловое хранилище (замена Cloudinary)
- Authentication из коробки (email/password)
- Flutter SDK: `pocketbase: ^0.23.0`
- SQLite - проще для диплома
- Open source

### Целевая аудитория
- **Ученики**: школьники, студенты, взрослые, нуждающиеся в дополнительных занятиях
- **Репетиторы**: специалисты, желающие находить учеников без посредников

## Project Status

**ОБЩИЙ ПРОГРЕСС: 100%**

**ЗАВЕРШЕНО:**
- Миграция Firebase → PocketBase (100%)
- Система авторизации (100%)
- Чаты с файлами (текст, изображения, аудио) (100%)
- Система расписания + недельные шаблоны (100%)
- Расширенные профили репетиторов (100%)
- Поиск и фильтрация репетиторов (100%)
- Файловое хранилище (100% - PocketBase Storage)
- Система отзывов и рейтингов (100%)
- Система оплаты mock (100%)
- Красная карточка неоплаченного занятия (100%)
- Кэширование профилей и чатов (100%)
- Переключатель серверов Локальный/VPS (100%)
- Deployment на VPS (100%) - http://203.18.98.210:8090

**ОПЦИОНАЛЬНО:**
- Push-уведомления
- Google Sign-In

**ВРЕМЯ ДО ЗАЩИТЫ:** ~6 месяцев

---

### Уже реализовано (полный список)
- **Авторизация через PocketBase** (email/password)
- **Роли пользователей** (Репетитор/Ученик)
- **Базовые профили** с данными из PocketBase
- **Детальный профиль репетитора** (tutor_profile_page.dart):
  - Дизайн с gradient header и аватаром
  - Карточки с информацией о репетиторе
  - Кнопки "Написать" и "Расписание"
  - Отображение рейтинга или бейджа "Новичок"
- **Чат система** - ПОЛНОСТЬЮ МИГРИРОВАНО:
  - Текстовые сообщения через PocketBase
  - Двух-табличная архитектура (`messages` + `chats` metadata)
  - Auto-refresh списка чатов (pull-to-refresh + auto-reload)
  - Непрочитанные сообщения с счётчиками
  - Изображения и аудио в чатах через PocketBase Storage
- **Поиск репетиторов**:
  - Фильтры: предметы, цена, опыт, город, формат занятий (онлайн/оффлайн)
  - Интеграция с tutor_profiles коллекцией
- **Расширенные профили репетиторов**:
  - Модель TutorProfile, сервис TutorProfileService
  - Страницы заполнения и просмотра
  - Поля: subjects, priceMin/Max, experience, education, lessonFormat, rating, totalPaidLessons
- **Система расписания**:
  - Добавление/удаление слотов вручную
  - Бронирование слотов учениками (pending → confirmed)
  - Недельный шаблон расписания (weekly_templates)
  - Автоматическая генерация слотов на 28 дней вперёд
  - Страницы запросов на бронирование (для репетиторов и учеников)
- **Система оплаты** (mock):
  - Форма ввода банковской карты (Visa/Mastercard/МИР)
  - Сохранение маскированных данных карты (CardStorageService)
  - Создание записи Payment в PocketBase
  - Обновление slot.isPaid = true после оплаты
  - Красная карточка для неоплаченных прошедших занятий (>2 часа назад)
  - Интеграция с TutorProfileService (incrementPaidLessons)
  - Оплата вне приложения (наличные/перевод): создаёт Payment с `slotId='external_<id>'`
  - `Payment.isExternal` геттер для различия в истории
- **История платежей** (PaymentHistoryPage):
  - Группировка по месяцам с суммой за каждый месяц
  - 3 мини-карточки: доход за месяц, занятий за месяц, средний чек
  - Визуальное различие: через приложение (зелёный), вне приложения (бирюзовый), ручная (жёлтый)
  - Кнопка "Подробная история" прямо из профиля репетитора
  - FAB для добавления ручной оплаты (наличные без привязки к слоту)
- **Система отзывов и рейтингов**:
  - Модель Review, сервис ReviewService
  - Диалог отзыва (ReviewDialog) с 1-5 звёздами + комментарий
  - Верифицированные (после оплаты) и неверифицированные отзывы
  - Взвешенный рейтинг за последние 6 месяцев
  - Вес отзыва = количество оплаченных занятий с этим учеником
  - Бейдж "Новичок на платформе" для новых репетиторов
  - Корректное отображение рейтинга в профиле
- **Кэширование** (CacheService):
  - Оффлайн-доступ к профилю и чатам
  - SharedPreferences для хранения данных
- **Переключатель серверов**:
  - Тумблер Локальный/VPS в настройках
  - Редактирование URL серверов через UI
  - Сохранение выбора в SharedPreferences
  - Для защиты: если интернет пропадёт, переключение на локальный PocketBase
- **Блокировка пользователей**
- **Светлая/тёмная тема** с сохранением предпочтений

## Build & Development Commands

### Setup
```bash
flutter pub get
flutter clean
```

### Running the App
```bash
flutter run                    # Debug mode
flutter run -d <device_id>     # Specific device
flutter devices                # List devices
# Hot reload: 'r' | Hot restart: 'R'
```

### Building
```bash
flutter build apk              # Android APK
flutter build apk --release    # Release APK
flutter build ios               # iOS (requires macOS)
```

### Testing & Analysis
```bash
flutter test
flutter analyze
```

## Architecture Overview

### State Management
- **Provider Pattern** для всех сервисов
- **ThemProvider** (lib/themes/theme_provider.dart): Тема + SharedPreferences
- **DatabaseProvider** (lib/service/database_provider.dart): Обёртка для CRUD
- **ChatService** (lib/service/chat_service.dart): ChangeNotifier для чатов
- **ScheduleService** (lib/service/schedule_service.dart): ChangeNotifier для расписания
- **PocketBaseService** (lib/service/pocketbase_service.dart): ChangeNotifier, Singleton, переключение серверов

### Core Services (lib/service/)

| Сервис | Файл | Описание |
|--------|------|----------|
| PocketBaseService | pocketbase_service.dart | Singleton PocketBase клиент, переключение Local/VPS, auth persistence |
| Auth | auth.dart | Email/password авторизация, регистрация, смена пароля |
| AuthGate | auth_gate.dart | Роутинг: авторизован → HomePage, нет → LoginOrRegister |
| Databases | databases.dart | User CRUD, getTutorsList, getAllCities |
| ChatService | chat_service.dart | Чаты, сообщения, блокировка, Two-Table Pattern |
| ScheduleService | schedule_service.dart | Слоты, бронирование, генерация из шаблонов |
| WeeklyTemplateService | weekly_template_service.dart | Недельные шаблоны расписания |
| TutorProfileService | tutor_profile_service.dart | CRUD профилей, поиск с фильтрами, рейтинг |
| PaymentService | payment_service.dart | Mock оплата, статистика, связь с TutorProfile |
| ReviewService | review_service.dart | Отзывы, взвешенный рейтинг, 6-месячное окно |
| CacheService | cache_service.dart | Оффлайн кэш профилей и чатов |
| CardStorageService | card_storage_service.dart | Маскированные данные карты |
| DatabaseProvider | database_provider.dart | Provider обёртка для Databases |
| LoginOrRegister | login_or_register.dart | Переключатель Login/Register страниц |

### Data Models (lib/models/)

| Модель | Файл | Поля |
|--------|------|------|
| UserProfile | user.dart | uid, name, email, username, birthDate, city, role, bio, avatarUrl |
| Message | messenge.dart | senderID, receiverID, message, type (text/image/audio), isRead |
| Chat | chat.dart | chatRoomId, user1Id, user2Id, lastMessage, unreadCounts |
| ScheduleSlot | schedule_slot.dart | tutorId, date, startTime, endTime, isBooked, isPaid, bookingStatus |
| TutorProfile | tutor_profile.dart | userId, subjects, priceMin/Max, experience, education, lessonFormat, rating |
| WeeklyTemplate | weekly_template.dart | tutorId, dayOfWeek (1-7), startTime, endTime, isActive |
| Review | review.dart | tutorId, studentId, rating (1-5), comment, isVerified, weight, lessonId |
| Payment | payment.dart | studentId, tutorId, slotId, amount, status (pending/completed/failed) |

### UI Structure (lib/pages/) — 17 страниц

**Навигация:**
- **main_navigation.dart**: Bottom Navigation Bar — 4 вкладки (Чаты, Поиск, График, Профиль), IndexedStack

**Авторизация:**
- **login_page.dart**: Вход по email/password
- **register_page.dart**: Регистрация
- **register_profile_page.dart**: Заполнение профиля после регистрации

**Основные страницы:**
- **home_page.dart**: Список чатов (FutureBuilder + ValueKey refresh)
- **chat_page.dart**: Чат с текстом/изображениями/аудио
- **find_tutor_page.dart**: Поиск репетиторов с фильтрами
- **schedule_page.dart**: Dual-mode — расписание (репетитор) / мои занятия (ученик)
- **profile_page.dart**: Профиль с gradient header

**Репетиторы:**
- **tutor_profile_page.dart**: Детальный профиль с рейтингом
- **tutor_profile_setup_page.dart**: Заполнение профиля репетитора
- **tutor_schedule_view_page.dart**: Просмотр расписания репетитора учеником

**Бронирование:**
- **booking_requests_page.dart**: Запросы на бронирование (для репетиторов)
- **student_booking_requests_page.dart**: Запросы ученика
- **weekly_template_setup_page.dart**: Настройка недельного шаблона

**Настройки:**
- **setting_page.dart**: Тема, сервер (Local/VPS), пароль, заблокированные, выход
- **blocked_user_page.dart**: Список заблокированных

### Reusable Components (lib/components/) — 12 компонентов

| Компонент | Описание |
|-----------|----------|
| user_tile.dart | Элемент списка чатов (аватар, имя, превью, время, unread) |
| chat_bubble.dart | Сообщение в чате (sender/receiver стили) |
| audio_player_widget.dart | Проигрыватель аудио с прогрессом |
| avatar_picker.dart | Выбор аватара (камера/галерея) + загрузка в PocketBase |
| user_avatar.dart | Кэшированный аватар с fallback |
| payment_dialog.dart | Диалог mock оплаты с формой карты |
| review_dialog.dart | Диалог отзыва (звёзды + комментарий) |
| my_text_field.dart | Кастомное текстовое поле |
| input_box.dart | Простое текстовое поле |
| my_button.dart | Стилизованная кнопка |
| bio_box.dart | Отображение/редактирование био |
| load_animation.dart | Анимация загрузки |

### PocketBase Configuration

**Database Schema:** файл `database_schema.dbml` в корне проекта

#### Installation & Setup

**Docker (рекомендуется):**
```bash
cd pocketbase
docker-compose up -d
# Admin UI: http://localhost:8090/_/
# API: http://localhost:8090/api/
```

**Локальный бинарник:**
```bash
./pocketbase serve
# Admin UI: http://127.0.0.1:8090/_/
```

#### Подключение Flutter → PocketBase
- Singleton: `lib/service/pocketbase_service.dart`
- Переключатель серверов: Local/VPS через настройки приложения
- URL сохраняются в SharedPreferences (можно менять через UI)
- Дефолт Local: `http://192.168.31.125:8090`
- Дефолт VPS: нужно заменить на реальный IP

#### Collections (10 коллекций)

**users** (Auth Collection)
- email, username, name, birthDate, city, role (student/tutor), bio, avatar

**messages** (Base Collection)
- chatRoomId (indexed), senderId, receiverId, message, type (text/image/audio), isRead

**chats** (Base Collection) — метаданные для Two-Table Pattern
- chatRoomId, user1Id, user2Id, lastMessage, lastMessageType, lastSenderId, lastTimestamp, unreadCountUser1/User2

**slots** (Base Collection)
- tutorId, date, startTime, endTime, isBooked, isPaid, bookingStatus (free/pending/confirmed), studentId, generatedFromTemplate, templateId, isRecurring, recurringGroupId

**weekly_templates** (Base Collection)
- tutorId, dayOfWeek (1-7), startTime, endTime, isActive

**tutor_profiles** (Base Collection)
- userId (unique), subjects (json), priceMin, priceMax, experience, education, lessonFormat (json), rating, totalPaidLessons, lastPaidLessonDate, isNewbie

**reviews** (Base Collection)
- tutorId, studentId, rating (1-5), comment, isVerified, lessonId, weight

**payments** (Base Collection)
- studentId, tutorId, slotId, amount, status (pending/completed/failed)

**blocked_users** (Base Collection)
- userId, blockedUserId

**reports** (Base Collection)
- reportedBy, messageId, messageOwnerId

### Theme System (lib/themes/)
- **light_mode.dart**: Мягкий серый `#F5F5F7`, синий акцент `#4A90E2`
- **dark_mode.dart**: Чёрный `#000000`, синий акцент `#5BA4F5`
- **theme_provider.dart**: Переключение + SharedPreferences

## Important Implementation Notes

### Chat Architecture (Two-Table Pattern)

PocketBase не поддерживает subcollections (как Firebase). Решение — разделение на 2 коллекции:

1. **`messages`** — все сообщения (для истории чата)
2. **`chats`** — метаданные (для быстрого списка чатов на главной)

Метод `_createOrUpdateChatRoom()` вызывается после КАЖДОЙ отправки сообщения и обновляет lastMessage, lastTimestamp, unreadCount.

**Результат:** 1 запрос за 100-300ms вместо загрузки 500+ messages.

### Chat Room ID Generation
```dart
List<String> ids = [userId1, userId2];
ids.sort();
String chatRoomId = ids.join('_');
```
Детерминированный ID — один чатрум для любой пары, независимо от инициатора.

### Complete Lesson Flow (Booking → Lesson → Payment → Review)

1. Ученик находит репетитора → бронирует слот (isBooked=true)
2. Занятие проходит
3. **После занятия** (>2 часа): красная карточка → ученик оплачивает (mock) → slot.isPaid=true
4. **После оплаты**: диалог отзыва → звёзды + комментарий → верифицированный отзыв
5. Система пересчитывает взвешенный рейтинг (6-месячное окно)

**Критические правила:**
- Оплата ПОСЛЕ занятия, не при бронировании
- Верифицированные отзывы (звёзды) только после оплаты
- Рейтинг = взвешенное среднее за 6 месяцев
- Вес = кол-во оплаченных занятий между учеником и репетитором
- Новые репетиторы (0 оплат) → бейдж "Новичок на платформе"

### Rating System Logic — Двухуровневая агрегация

**Проблема простого среднего:** частый ученик доминирует за счёт количества отзывов, а не качества.

**Решение — двухуровневая модель:**
1. Отзывы группируются по `studentId` → средняя оценка каждого ученика (`avg_rᵢ`)
2. Вес ученика = `clamp(кол-во оплаченных занятий, 1, 5)` — опытные ученики весят больше, но не доминируют
3. Итоговый рейтинг = `Σ(avg_rᵢ × clamp(nᵢ, 1, 5)) / Σ(clamp(nᵢ, 1, 5))`
4. Учитываются только верифицированные отзывы за последние 180 дней

**Защита от трёх типов атак:**
- **Месть:** злая оценка размывается собственной историей отзывов ученика
- **Накрутка (фейки):** фейковые аккаунты с 1 занятием получают вес 1, реальные ученики с весом 3–5 перевешивают
- **Доминирование:** clamp(1, 5) не даёт одному ученику контролировать рейтинг

**Реализация:**
- `ReviewService._recalculateTutorRating()` — двухуровневый пересчёт после каждого отзыва
- `ReviewService._countPaidLessonsBetween()` — подсчёт оплаченных занятий для веса
- `TutorProfile.getRatingDisplay()` — форматирование для UI

### Server Switching (Локальный ↔ VPS)

Для защиты диплома: если интернет пропадёт, можно переключиться на локальный PocketBase.

- `PocketBaseService.switchServer(mode)` — переключение клиента
- `PocketBaseService.updateUrl(mode, url)` — изменение URL через UI
- Auth store сохраняется при переключении
- URL и выбор сохраняются в SharedPreferences

### Audio Session
AudioSession настроена в main.dart для поддержки записи/воспроизведения аудио (flutter_sound + audioplayers).

### Permission Requirements
- Camera/Photo Library (аватары, изображения в чатах)
- Microphone (аудио сообщения)
- Storage (доступ к файлам)

Через permission_handler package.

### Known Issues

#### Исправлено ранее:
- Registration error — `role` не передавался (добавлено `'role': 'Ученик'`)
- Неэффективная загрузка чатов — 500+ messages (реализован Two-Table Pattern)
- Нет auto-refresh на HomePage (ValueKey pattern)
- Терминология "Преподаватель" → "Репетитор"
- Зависимость от Cloudinary → PocketBase Storage
- markMessagesAsRead() и getUnreadCount() — ПРОВЕРЕНО, баги НЕ подтвердились (код корректный)

#### Опциональные улучшения:
- ChatPage использует polling вместо realtime subscriptions (можно улучшить позже)
- Имя файла `messenge.dart` — опечатка (должно быть `message.dart`), косметическое

## Migration Plan: Firebase → PocketBase

**Status: 100% ЗАВЕРШЕНО**

- Step 0: PocketBase setup (Docker + collections)
- Step 1: Authentication (email/password)
- Step 2: User profiles
- Step 3: Chat system (two-table pattern + auto-refresh)
- Step 4: Schedule + Weekly Templates
- Step 5: Basic search (city, name)
- Step 6: Cloudinary → PocketBase Storage (avatars, images, audio)
- Step 7: Tutor profiles (tutor_profiles collection + CRUD + filters)
- Step 8: Reviews + Rating system (weighted, 6-month window)
- Step 9: Payments (mock payment flow + integration with reviews)
- Step 10: Caching (CacheService для оффлайн доступа)
- Step 11: Server switching (Local/VPS переключатель)

Все зависимости Firebase полностью удалены из проекта.

## Development Priorities for Diploma

### Phase 1: Extended Tutor Profile — COMPLETED
### Phase 2: Reviews and Ratings — COMPLETED
### Phase 3: Payment System — COMPLETED
### Phase 4: Server Switching — COMPLETED

### Phase 5: Deployment & Polish (ТЕКУЩИЙ ПРИОРИТЕТ)
1. Deploy PocketBase на российский VPS (Timeweb/Selectel)
2. Заполнить VPS URL в настройках приложения
3. Подготовить тестовые данные на VPS
4. Финальное тестирование
5. (Опционально) Push-уведомления
6. (Опционально) Google Sign-In

## Project Statistics

- **Dart файлов:** 52
- **Общий код:** ~12,000 строк
- **Моделей:** 8
- **Сервисов:** 14
- **Страниц:** 17
- **Компонентов:** 12
- **PocketBase коллекций:** 10
- **PocketBase миграций:** 18+
