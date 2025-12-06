# PocketBase Docker Deployment

Backend для приложения "Учеба рядом" на базе PocketBase.

## Быстрый старт (Локальная разработка)

### 1. Запуск PocketBase

```bash
cd pocketbase
docker-compose up -d
```

### 2. Доступ к Admin UI

Открой браузер: http://localhost:8090/_/

При первом запуске создай admin аккаунт.

### 3. API Endpoint

API доступно по адресу: http://localhost:8090/api/

### Полезные команды

```bash
# Запустить контейнер
docker-compose up -d

# Остановить контейнер
docker-compose down

# Посмотреть логи
docker-compose logs -f

# Перезапустить контейнер
docker-compose restart

# Пересобрать образ (после изменения Dockerfile)
docker-compose up -d --build

# Очистить всё (включая данные!)
docker-compose down -v
```

## Структура данных

После запуска создай следующие коллекции через Admin UI:

### 1. users (Auth Collection)
Встроенная коллекция для авторизации. Добавь поля:
- `username` (text, required, unique)
- `name` (text, required)
- `birthDate` (date)
- `city` (text)
- `role` (select: "student" или "tutor")
- `bio` (text, optional)
- `avatar` (file, single, max 5MB)

### 2. messages (Base Collection)
- `chatRoomId` (text, indexed)
- `senderId` (relation → users)
- `senderEmail` (text)
- `receiverId` (relation → users)
- `message` (text)
- `type` (select: "text", "image", "audio")
- `isRead` (bool, default: false)

### 3. slots (Base Collection)
- `tutorId` (relation → users)
- `date` (date)
- `startTime` (text) - формат HH:mm
- `endTime` (text) - формат HH:mm
- `isBooked` (bool, default: false)
- `isPaid` (bool, default: false)
- `studentId` (relation → users, optional)

### 4. blocked_users (Base Collection)
- `userId` (relation → users)
- `blockedUserId` (relation → users)

### 5. reports (Base Collection)
- `reportedBy` (relation → users)
- `messageId` (relation → messages)
- `messageOwnerId` (relation → users)

## Настройка Flutter приложения

В Flutter добавь зависимость:

```yaml
dependencies:
  pocketbase: ^0.18.0
```

Создай сервис для подключения:

```dart
import 'package:pocketbase/pocketbase.dart';

class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  late final PocketBase pb;

  factory PocketBaseService() {
    return _instance;
  }

  PocketBaseService._internal() {
    // Для локальной разработки
    pb = PocketBase('http://10.0.2.2:8090'); // Android emulator
    // pb = PocketBase('http://localhost:8090'); // iOS simulator

    // Для продакшена
    // pb = PocketBase('https://your-domain.com');
  }
}
```

**Важно:**
- Android emulator использует `10.0.2.2` для доступа к localhost хоста
- iOS simulator использует `localhost`
- Для реальных устройств используй IP адрес компьютера в локальной сети

## Deployment на VPS (Production)

### Вариант 1: Российские VPS хостинги

Рекомендуемые провайдеры:
- [Timeweb](https://timeweb.com) - от 150₽/мес
- [Selectel](https://selectel.ru) - от 200₽/мес
- [Beget](https://beget.com) - от 100₽/мес

### Вариант 2: Установка на VPS

1. **Подключись к серверу:**
```bash
ssh root@your-server-ip
```

2. **Установи Docker:**
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Установи docker-compose
apt install docker-compose -y
```

3. **Загрузи файлы на сервер:**
```bash
# На твоём компьютере
scp -r pocketbase root@your-server-ip:/opt/
```

4. **Запусти на сервере:**
```bash
cd /opt/pocketbase
docker-compose up -d
```

### Вариант 3: HTTPS с Let's Encrypt

1. **Установи Caddy (автоматический HTTPS):**

Создай `Caddyfile`:
```
your-domain.com {
    reverse_proxy pocketbase:8090
}
```

2. **Обнови docker-compose.yml:**
```yaml
services:
  # ... существующий pocketbase сервис

  caddy:
    image: caddy:alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - pocketbase-network

volumes:
  caddy_data:
  caddy_config:
```

## Бэкап данных

### Автоматический бэкап

```bash
# Создай скрипт backup.sh
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
tar -czf backup_$DATE.tar.gz pb_data/
# Опционально: загрузи на Яндекс.Диск или другое хранилище
```

### Восстановление из бэкапа

```bash
docker-compose down
tar -xzf backup_20231201_120000.tar.gz
docker-compose up -d
```

## Мониторинг

### Проверка статуса
```bash
curl http://localhost:8090/api/health
```

### Логи
```bash
docker-compose logs -f pocketbase
```

## Безопасность

1. **Измени порт по умолчанию** (опционально):
```yaml
ports:
  - "8091:8090"  # Вместо 8090
```

2. **Настрой firewall**:
```bash
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

3. **Регулярные обновления**:
```bash
# Обнови версию в docker-compose.yml
docker-compose down
docker-compose up -d --build
```

## Миграция данных из Firebase

После настройки PocketBase запусти скрипт миграции (будет создан позже):

```bash
flutter run lib/scripts/migrate_firebase_to_pocketbase.dart
```

## Troubleshooting

### Проблема: Контейнер не запускается
```bash
docker-compose logs pocketbase
# Проверь логи на ошибки
```

### Проблема: Нет доступа к Admin UI
- Проверь firewall
- Проверь что порт 8090 не занят: `lsof -i :8090`
- Перезапусти контейнер

### Проблема: Flutter не подключается
- Android emulator: используй `10.0.2.2:8090`
- iOS simulator: используй `localhost:8090`
- Реальное устройство: используй IP компьютера в той же сети

## Полезные ссылки

- [PocketBase Docs](https://pocketbase.io/docs/)
- [PocketBase Dart SDK](https://github.com/pocketbase/dart-sdk)
- [Docker Compose Docs](https://docs.docker.com/compose/)
