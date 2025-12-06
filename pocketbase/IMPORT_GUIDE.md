# Инструкция по импорту схемы данных в PocketBase

Есть два способа импортировать схему коллекций в PocketBase:

## 🚀 Способ 1: Автоматический импорт через скрипт (рекомендуется)

### Требования

Установи `jq` (утилита для работы с JSON):

```bash
brew install jq
```

### Шаги

1. **Убедись что PocketBase запущен:**
```bash
cd pocketbase
docker-compose ps
# Должен быть статус "Up" и "healthy"
```

2. **Создай admin аккаунт (если еще не создал):**
   - Открой http://localhost:8090/_/
   - При первом входе создай admin аккаунт
   - Запомни email и пароль

3. **Запусти скрипт импорта:**
```bash
cd pocketbase
./import_schema.sh
```

4. **Введи admin credentials когда запросит:**
```
Enter admin email: admin@example.com
Enter admin password: ********
```

5. **Готово!** Скрипт создаст все коллекции автоматически:
   - ✅ users (Auth collection)
   - ✅ messages
   - ✅ slots
   - ✅ blocked_users
   - ✅ reports

6. **Проверь результат:**
   - Открой Admin UI: http://localhost:8090/_/
   - Зайди в раздел "Collections"
   - Должны быть все 5 коллекций

---

## 📋 Способ 2: Ручной импорт через Admin UI

Если автоматический скрипт не работает, можно создать вручную:

### Шаг 1: Открой Admin UI

http://localhost:8090/_/

### Шаг 2: Создай коллекции одну за другой

#### 1️⃣ Коллекция `users` (Auth Collection)

1. Нажми **"New collection"** → выбери **"Auth"**
2. Name: `users`
3. Добавь поля (кликай "+ New field"):

| Поле | Тип | Настройки |
|------|-----|-----------|
| `username` | Text | ✅ Required, ✅ Unique, Min: 3 |
| `name` | Text | ✅ Required |
| `birthDate` | Date | Optional |
| `city` | Text | Optional |
| `role` | Select | ✅ Required, Single, Values: "student", "tutor" |
| `bio` | Text | Optional, Max: 500 |
| `avatar` | File | Single, Max: 5MB, Types: image/* |

4. Вкладка **"API Rules"**:
   - List/View: `@request.auth.id != ""`
   - Create: (пусто)
   - Update: `@request.auth.id = id`
   - Delete: `@request.auth.id = id`

5. Вкладка **"Options"**:
   - ✅ Allow email auth
   - ✅ Allow username auth
   - ✅ Require email
   - Min password length: 8

6. **Save**

---

#### 2️⃣ Коллекция `messages` (Base Collection)

1. **"New collection"** → **"Base"**
2. Name: `messages`
3. Поля:

| Поле | Тип | Настройки |
|------|-----|-----------|
| `chatRoomId` | Text | ✅ Required |
| `senderId` | Relation | Collection: users, Single, ✅ Required |
| `senderEmail` | Text | ✅ Required |
| `receiverId` | Relation | Collection: users, Single, ✅ Required |
| `message` | Text | ✅ Required, Max: 5000 |
| `type` | Select | ✅ Required, Single, Values: "text", "image", "audio" |
| `isRead` | Bool | Default: false |

4. **API Rules**:
   - List/View: `senderId = @request.auth.id || receiverId = @request.auth.id`
   - Create: `senderId = @request.auth.id`
   - Update: `receiverId = @request.auth.id`
   - Delete: `senderId = @request.auth.id`

5. **Save**

---

#### 3️⃣ Коллекция `slots` (Base Collection)

1. **"New collection"** → **"Base"**
2. Name: `slots`
3. Поля:

| Поле | Тип | Настройки |
|------|-----|-----------|
| `tutorId` | Relation | Collection: users, Single, ✅ Required |
| `date` | Date | ✅ Required |
| `startTime` | Text | ✅ Required, Pattern: `^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$` |
| `endTime` | Text | ✅ Required, Pattern: `^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$` |
| `isBooked` | Bool | Default: false |
| `isPaid` | Bool | Default: false |
| `studentId` | Relation | Collection: users, Single, Optional |

4. **API Rules**:
   - List/View: `@request.auth.id != ""`
   - Create: `tutorId = @request.auth.id`
   - Update: `tutorId = @request.auth.id || studentId = @request.auth.id`
   - Delete: `tutorId = @request.auth.id`

5. **Save**

---

#### 4️⃣ Коллекция `blocked_users` (Base Collection)

1. **"New collection"** → **"Base"**
2. Name: `blocked_users`
3. Поля:

| Поле | Тип | Настройки |
|------|-----|-----------|
| `userId` | Relation | Collection: users, Single, ✅ Required, Cascade delete |
| `blockedUserId` | Relation | Collection: users, Single, ✅ Required, Cascade delete |

4. **API Rules**:
   - List/View: `userId = @request.auth.id`
   - Create: `userId = @request.auth.id`
   - Update: (пусто - нельзя изменять)
   - Delete: `userId = @request.auth.id`

5. **Save**

---

#### 5️⃣ Коллекция `reports` (Base Collection)

1. **"New collection"** → **"Base"**
2. Name: `reports`
3. Поля:

| Поле | Тип | Настройки |
|------|-----|-----------|
| `reportedBy` | Relation | Collection: users, Single, ✅ Required |
| `messageId` | Relation | Collection: messages, Single, ✅ Required, Cascade delete |
| `messageOwnerId` | Relation | Collection: users, Single, ✅ Required |

4. **API Rules**:
   - List/View: (пусто - только admin)
   - Create: `reportedBy = @request.auth.id`
   - Update/Delete: (пусто - только admin)

5. **Save**

---

## ✅ Проверка что всё работает

### 1. Создай тестового пользователя

В Admin UI → Collections → users → "New record":

```
email: test@example.com
password: 12345678
username: testuser
name: Test User
role: student
```

### 2. Проверь через API

```bash
# Авторизация
curl -X POST http://localhost:8090/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity":"test@example.com","password":"12345678"}'

# Должен вернуть token и данные пользователя
```

### 3. Проверь коллекции

Открой Admin UI и убедись что все 5 коллекций созданы:
- ✅ users (Auth)
- ✅ messages (Base)
- ✅ slots (Base)
- ✅ blocked_users (Base)
- ✅ reports (Base)

---

## 🔧 Troubleshooting

### Проблема: `jq: command not found`

**Решение:**
```bash
brew install jq
```

### Проблема: `Authentication failed`

**Решение:**
- Проверь что admin аккаунт создан в Admin UI
- Проверь правильность email и пароля
- Убедись что PocketBase запущен: `docker-compose ps`

### Проблема: `Collection already exists`

**Решение:**
Если коллекция уже существует, удали её в Admin UI и запусти скрипт снова.

Или удали все данные и начни заново:
```bash
docker-compose down -v
docker-compose up -d
```

### Проблема: Permission denied при запуске скрипта

**Решение:**
```bash
chmod +x import_schema.sh
```

---

## 📚 Дополнительная информация

### Где хранятся данные?

Все данные PocketBase хранятся в:
```
pocketbase/pb_data/
├── data.db          # SQLite база данных
├── logs.db          # Логи
└── storage/         # Загруженные файлы
```

### Как сделать бэкап?

```bash
# Остановить PocketBase
docker-compose down

# Бэкап данных
tar -czf backup_$(date +%Y%m%d).tar.gz pb_data/

# Запустить снова
docker-compose up -d
```

### Экспорт схемы

Если хочешь экспортировать текущую схему:

1. Открой Admin UI → Settings → Export collections
2. Скачай JSON файл
3. Сохрани как `pb_schema_backup.json`

---

## 🎯 Следующие шаги

После успешного импорта:

1. ✅ Добавь Flutter package `pocketbase` в `pubspec.yaml`
2. ✅ Создай `lib/service/pocketbase_service.dart`
3. ✅ Начни миграцию с auth (Step 1)

См. `CLAUDE.md` для полного плана миграции.
