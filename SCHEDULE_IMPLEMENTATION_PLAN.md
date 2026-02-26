# План реализации системы расписания репетитора

## 📋 Концепция

**Проблема:** Текущая система требует от репетитора вручную добавлять каждый слот на каждую дату - это неудобно.

**Решение:** Система с недельным шаблоном + автогенерация слотов на 4 недели вперед + возможность исключений.

---

## 🏗️ Архитектура БД

### Новая таблица: `weekly_templates`

**Назначение:** Хранит недельный шаблон репетитора (когда он обычно работает)

**Поля:**
```
id: auto (Primary Key)
tutorId: relation → users (каскадное удаление)
dayOfWeek: number (1=Пн, 2=Вт, ..., 7=Вс)
startTime: text (формат HH:mm, например "10:00")
endTime: text (формат HH:mm, например "12:00")
isActive: bool (можно отключить слот без удаления)
created: auto
updated: auto
```

**Пример данных:**
```
Репетитор "Иван" работает:
- Понедельник: 10:00-12:00, 14:00-16:00
- Среда: 10:00-12:00
- Пятница: 14:00-16:00

В БД:
| tutorId | dayOfWeek | startTime | endTime | isActive |
|---------|-----------|-----------|---------|----------|
| ivan123 | 1         | 10:00     | 12:00   | true     |
| ivan123 | 1         | 14:00     | 16:00   | true     |
| ivan123 | 3         | 10:00     | 12:00   | true     |
| ivan123 | 5         | 14:00     | 16:00   | true     |
```

**API Rules (PocketBase):**
- List/View: `tutorId = @request.auth.id`
- Create: `tutorId = @request.auth.id && @request.auth.id = @collection.users.id`
- Update/Delete: `tutorId = @request.auth.id`

---

### Обновление существующей таблицы: `slots`

**Новые поля:**
```
generatedFromTemplate: bool (default: false)
  - true = слот сгенерирован автоматически из шаблона
  - false = слот добавлен вручную репетитором

templateId: relation → weekly_templates (optional)
  - указывает, из какого шаблона был создан слот
  - нужно для синхронизации при изменении шаблона
```

**Обновленная структура:**
```
id: auto
tutorId: relation → users
date: date (конкретная дата, например "2026-03-15")
startTime: text (HH:mm)
endTime: text (HH:mm)
isBooked: bool (default: false)
isPaid: bool (default: false)
studentId: relation → users (optional)
generatedFromTemplate: bool (NEW!)
templateId: relation → weekly_templates (NEW!)
created: auto
updated: auto
```

---

## 🎨 UX: Два экрана

### Экран А: "Мой недельный график" (Настройка шаблона)

**Назначение:** Репетитор настраивает, в какие дни и время он ОБЫЧНО работает.

**UI компоненты:**
```
Заголовок: "Мой недельный график"

[Переключатель вкладок]
  ☑️ Настройка шаблона  |  Календарь слотов

┌─────────────────────────────────────┐
│  📅 Понедельник  [Toggle ✓]         │
│    ┌───────────────────────────┐    │
│    │ 10:00 - 12:00      [×]    │    │
│    │ 14:00 - 16:00      [×]    │    │
│    └───────────────────────────┘    │
│    [+ Добавить время]               │
├─────────────────────────────────────┤
│  📅 Вторник  [Toggle ✓]             │
│    ┌───────────────────────────┐    │
│    │ 10:00 - 12:00      [×]    │    │
│    └───────────────────────────┘    │
│    [+ Добавить время]               │
├─────────────────────────────────────┤
│  📅 Среда  [Toggle ○]               │
│    [+ Добавить время]               │
├─────────────────────────────────────┤
│  ... (остальные дни)                │
└─────────────────────────────────────┘

[Скопировать Пн на все будни]
[Очистить всё]

[Применить изменения]  ← Синяя кнопка
```

**Функционал:**
1. **Toggle для дня недели:**
   - Включен → день активен, можно добавлять слоты
   - Выключен → день неактивный (isActive = false)

2. **Добавление времени:**
   - Открывает диалог с двумя TimePicker (начало и конец)
   - Валидация: endTime > startTime
   - Валидация: нет пересечений с другими слотами в этот день

3. **Удаление времени:**
   - Кнопка [×] рядом со слотом
   - Если есть забронированные слоты → предупреждение

4. **Кнопка "Скопировать Пн на все будни":**
   - Копирует все слоты понедельника на Вт, Ср, Чт, Пт
   - Экономит время при однородном расписании

5. **Кнопка "Применить изменения":**
   - Сохраняет шаблон в `weekly_templates`
   - Запускает `regenerateSlotsFromTemplate()` (см. ниже)
   - Проверяет конфликты (см. раздел "Исключения")

---

### Экран Б: "Календарь слотов" (Реальные даты)

**Назначение:** Репетитор видит конкретные сгенерированные слоты и может их редактировать.

**UI компоненты:**
```
Заголовок: "Мои занятия"

[Переключатель вкладок]
  Настройка шаблона  |  ☑️ Календарь слотов

[Месяц: Март 2026  ◀ ▶]

Календарь (месячный вид):
  Пн  Вт  Ср  Чт  Пт  Сб  Вс
              1   2   3   4
  5   6   7   8   9   10  11
  12  13  14  15  16  17  18
  ...

Легенда:
🟢 Забронировано учеником
⚪️ Свободно (из шаблона)
🔵 Добавлено вручную
🔴 Удалено (исключение)

При нажатии на день → Bottom Sheet:
┌─────────────────────────────────┐
│  15 марта (пятница)             │
├─────────────────────────────────┤
│  ⚪️ 10:00-12:00  [Удалить]     │
│  🟢 14:00-16:00                 │
│      Ученик: Вася Петров        │
│      [Отменить занятие]         │
├─────────────────────────────────┤
│  [+ Добавить время в этот день] │
└─────────────────────────────────┘
```

**Функционал:**
1. **Просмотр календаря:**
   - Показывает ближайшие 4 недели (28 дней)
   - Цветовая кодировка слотов

2. **Удаление слота:**
   - Если слот свободен → просто удаляем из БД
   - Если забронирован → диалог подтверждения (см. "Исключения")

3. **Добавление разового слота:**
   - Создает slot с `generatedFromTemplate = false`
   - Не влияет на шаблон

---

## ⚙️ Логика генерации слотов

### Функция: `generateSlotsFromTemplate()`

**Когда вызывается:**
1. При нажатии "Применить изменения" в Экране А
2. При проверке каждый день в 00:00 (фоновая задача)
3. При открытии страницы расписания (проверка)

**Алгоритм:**
```dart
Future<void> generateSlotsFromTemplate({
  required String tutorId,
  int daysAhead = 28, // 4 недели
}) async {
  // 1. Загружаем шаблон репетитора
  final templates = await pb.collection('weekly_templates').getList(
    filter: 'tutorId="$tutorId" && isActive=true',
  );

  if (templates.items.isEmpty) {
    print('Шаблон не настроен');
    return;
  }

  // 2. Определяем диапазон дат
  final today = DateTime.now();
  final endDate = today.add(Duration(days: daysAhead));

  // 3. Группируем шаблоны по дням недели
  Map<int, List<WeeklyTemplate>> templatesByDay = {};
  for (var record in templates.items) {
    final template = WeeklyTemplate.fromRecord(record);
    final day = template.dayOfWeek;
    templatesByDay[day] = templatesByDay[day] ?? [];
    templatesByDay[day]!.add(template);
  }

  // 4. Проходим по каждому дню в диапазоне
  for (int i = 0; i <= daysAhead; i++) {
    final date = today.add(Duration(days: i));
    final dayOfWeek = date.weekday; // 1=Пн, 7=Вс

    // Есть ли шаблон для этого дня недели?
    if (!templatesByDay.containsKey(dayOfWeek)) continue;

    // 5. Для каждого шаблона создаем слот
    for (var template in templatesByDay[dayOfWeek]!) {
      // Проверяем, существует ли уже слот на эту дату/время
      final existing = await pb.collection('slots').getList(
        filter: 'tutorId="$tutorId" && date="${_formatDate(date)}" && startTime="${template.startTime}" && endTime="${template.endTime}"',
        perPage: 1,
      );

      if (existing.items.isEmpty) {
        // Слота нет → создаем
        await pb.collection('slots').create(body: {
          'tutorId': tutorId,
          'date': _formatDate(date), // "2026-03-15"
          'startTime': template.startTime,
          'endTime': template.endTime,
          'isBooked': false,
          'isPaid': false,
          'generatedFromTemplate': true,
          'templateId': template.id,
        });

        print('✅ Создан слот: ${_formatDate(date)} ${template.startTime}-${template.endTime}');
      }
    }
  }

  print('✅ Генерация завершена на $daysAhead дней вперед');
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
```

---

### Функция: `checkAndGenerateSlots()`

**Назначение:** Проверяет, достаточно ли слотов в будущем, и генерирует при необходимости.

**Когда вызывается:**
- При открытии страницы расписания
- Каждый день в 00:00 (фоновая задача - для диплома можно не делать)

**Алгоритм:**
```dart
Future<void> checkAndGenerateSlots(String tutorId) async {
  // 1. Находим самый дальний слот
  final farthestSlot = await pb.collection('slots').getList(
    filter: 'tutorId="$tutorId"',
    sort: '-date', // Сортировка по убыванию
    perPage: 1,
  );

  if (farthestSlot.items.isEmpty) {
    // Слотов вообще нет → генерируем на 28 дней
    await generateSlotsFromTemplate(tutorId: tutorId, daysAhead: 28);
    return;
  }

  // 2. Вычисляем, на сколько дней вперед есть слоты
  final farthestDate = DateTime.parse(farthestSlot.items.first.data['date']);
  final today = DateTime.now();
  final daysAhead = farthestDate.difference(today).inDays;

  print('Слоты есть на $daysAhead дней вперед');

  // 3. Если осталось меньше 14 дней → генерируем еще на 14 дней
  if (daysAhead < 14) {
    print('⚠️ Слотов мало, генерируем еще...');
    await generateSlotsFromTemplate(tutorId: tutorId, daysAhead: 28);
  } else {
    print('✅ Слотов достаточно');
  }
}
```

---

## 🚨 Исключения и конфликты

### Сценарий 1: Разовое удаление слота

**Ситуация:** Репетитор хочет удалить слот на конкретную дату (например, идет к стоматологу).

**Логика:**
```dart
Future<void> deleteSingleSlot(String slotId) async {
  // 1. Загружаем слот
  final slot = await pb.collection('slots').getOne(slotId);

  // 2. Проверяем, забронирован ли слот
  if (slot.data['isBooked'] == true) {
    // Слот забронирован → показываем диалог
    final studentId = slot.data['studentId'];
    final student = await pb.collection('users').getOne(studentId);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Отменить занятие?'),
        content: Text(
          'Этот слот забронирован учеником ${student.data['name']}. '
          'Если вы отмените, ему будет отправлено уведомление.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Назад'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Отменить занятие'),
          ),
        ],
      ),
    );

    if (confirm != true) return; // Пользователь передумал

    // TODO: Отправить уведомление ученику
  }

  // 3. Удаляем слот
  await pb.collection('slots').delete(slotId);

  print('✅ Слот удален');
}
```

---

### Сценарий 2: Разовое добавление слота

**Ситуация:** Репетитор хочет добавить слот на один конкретный день (вне шаблона).

**Логика:**
```dart
Future<void> addSingleSlot({
  required String tutorId,
  required DateTime date,
  required String startTime,
  required String endTime,
}) async {
  // 1. Проверяем пересечения
  final existing = await pb.collection('slots').getList(
    filter: 'tutorId="$tutorId" && date="${_formatDate(date)}"',
  );

  for (var slot in existing.items) {
    if (_timeOverlaps(startTime, endTime, slot.data['startTime'], slot.data['endTime'])) {
      throw Exception('Этот слот пересекается с существующим ${slot.data['startTime']}-${slot.data['endTime']}');
    }
  }

  // 2. Создаем слот (НЕ из шаблона)
  await pb.collection('slots').create(body: {
    'tutorId': tutorId,
    'date': _formatDate(date),
    'startTime': startTime,
    'endTime': endTime,
    'isBooked': false,
    'isPaid': false,
    'generatedFromTemplate': false, // Ручное добавление!
    'templateId': null,
  });

  print('✅ Разовый слот добавлен');
}

bool _timeOverlaps(String start1, String end1, String start2, String end2) {
  // Простая проверка пересечения временных интервалов
  return !(end1 <= start2 || start1 >= end2);
}
```

---

### Сценарий 3: Изменение шаблона (САМОЕ СЛОЖНОЕ!)

**Ситуация:** Репетитор изменил шаблон (например, убрал понедельник или изменил время).

**Проблема:** А что делать с уже сгенерированными слотами? Особенно если на них есть записи?

**Логика:**
```dart
Future<void> updateTemplateAndRegenerate(String tutorId) async {
  // 1. Сохраняем новый шаблон (это уже сделано в UI)

  // 2. Ищем БУДУЩИЕ слоты, сгенерированные из старого шаблона
  final today = DateTime.now();
  final futureSlots = await pb.collection('slots').getList(
    filter: 'tutorId="$tutorId" && date>="${_formatDate(today)}" && generatedFromTemplate=true',
    perPage: 500,
  );

  // 3. Разделяем на забронированные и свободные
  List<RecordModel> bookedSlots = [];
  List<String> freeSlotIds = [];

  for (var slot in futureSlots.items) {
    if (slot.data['isBooked'] == true) {
      bookedSlots.add(slot);
    } else {
      freeSlotIds.add(slot.id);
    }
  }

  // 4. Удаляем ВСЕ свободные слоты (они будут пересозданы)
  for (var slotId in freeSlotIds) {
    await pb.collection('slots').delete(slotId);
  }

  print('🗑️ Удалено ${freeSlotIds.length} свободных слотов');

  // 5. Если есть забронированные слоты → показываем предупреждение
  if (bookedSlots.isNotEmpty) {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('⚠️ Внимание!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('У вас есть ${bookedSlots.length} забронированных занятий, которые не вписываются в новый график:'),
            SizedBox(height: 12),
            ...bookedSlots.take(5).map((slot) {
              return Text('• ${slot.data['date']} ${slot.data['startTime']}-${slot.data['endTime']}');
            }),
            if (bookedSlots.length > 5) Text('... и еще ${bookedSlots.length - 5}'),
            SizedBox(height: 12),
            Text('Они останутся в календаре как исключения. Проверьте их вручную.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Понятно'),
          ),
        ],
      ),
    );
  }

  // 6. Генерируем новые слоты по новому шаблону
  await generateSlotsFromTemplate(tutorId: tutorId, daysAhead: 28);

  print('✅ Шаблон обновлен, слоты пересозданы');
}
```

---

## 📝 Модели данных (Flutter)

### `lib/models/weekly_template.dart`

```dart
import 'package:pocketbase/pocketbase.dart';

class WeeklyTemplate {
  final String id;
  final String tutorId;
  final int dayOfWeek; // 1-7
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final bool isActive;

  WeeklyTemplate({
    required this.id,
    required this.tutorId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.isActive,
  });

  factory WeeklyTemplate.fromRecord(RecordModel record) {
    final data = record.data;
    return WeeklyTemplate(
      id: record.id,
      tutorId: data['tutorId'] as String,
      dayOfWeek: data['dayOfWeek'] as int,
      startTime: data['startTime'] as String,
      endTime: data['endTime'] as String,
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tutorId': tutorId,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'isActive': isActive,
    };
  }

  String getDayName() {
    const days = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
    return days[dayOfWeek - 1];
  }
}
```

---

### Обновление `lib/models/schedule_slot.dart`

Добавить поля:
```dart
final bool generatedFromTemplate;
final String? templateId;

// В factory fromRecord:
generatedFromTemplate: data['generatedFromTemplate'] as bool? ?? false,
templateId: data['templateId'] as String?,

// В toMap:
'generatedFromTemplate': generatedFromTemplate,
if (templateId != null) 'templateId': templateId,
```

---

## 🛠️ Сервис (Flutter)

### `lib/service/weekly_template_service.dart`

```dart
import 'package:pocketbase/pocketbase.dart';
import 'package:p7/service/pocketbase_service.dart';
import 'package:p7/models/weekly_template.dart';

class WeeklyTemplateService {
  final _pb = PocketBaseService().client;

  // Получить все шаблоны репетитора
  Future<List<WeeklyTemplate>> getTutorTemplates(String tutorId) async {
    final result = await _pb.collection('weekly_templates').getList(
      filter: 'tutorId="$tutorId"',
      sort: 'dayOfWeek,startTime',
    );

    return result.items.map((r) => WeeklyTemplate.fromRecord(r)).toList();
  }

  // Создать шаблон
  Future<WeeklyTemplate> createTemplate(WeeklyTemplate template) async {
    final record = await _pb.collection('weekly_templates').create(
      body: template.toMap(),
    );

    return WeeklyTemplate.fromRecord(record);
  }

  // Удалить шаблон
  Future<void> deleteTemplate(String templateId) async {
    await _pb.collection('weekly_templates').delete(templateId);
  }

  // Удалить все шаблоны репетитора (для очистки)
  Future<void> clearAllTemplates(String tutorId) async {
    final templates = await getTutorTemplates(tutorId);
    for (var template in templates) {
      await deleteTemplate(template.id);
    }
  }

  // Скопировать понедельник на все будни
  Future<void> copyMondayToWeekdays(String tutorId) async {
    // 1. Получаем все слоты понедельника
    final mondayTemplates = await _pb.collection('weekly_templates').getList(
      filter: 'tutorId="$tutorId" && dayOfWeek=1',
    );

    if (mondayTemplates.items.isEmpty) return;

    // 2. Для каждого дня недели (Вт-Пт)
    for (int day = 2; day <= 5; day++) {
      // Удаляем старые шаблоны этого дня
      final existing = await _pb.collection('weekly_templates').getList(
        filter: 'tutorId="$tutorId" && dayOfWeek=$day',
      );
      for (var record in existing.items) {
        await _pb.collection('weekly_templates').delete(record.id);
      }

      // Создаем новые (копии понедельника)
      for (var mondayRecord in mondayTemplates.items) {
        await _pb.collection('weekly_templates').create(body: {
          'tutorId': tutorId,
          'dayOfWeek': day,
          'startTime': mondayRecord.data['startTime'],
          'endTime': mondayRecord.data['endTime'],
          'isActive': true,
        });
      }
    }
  }
}
```

---

## 📅 План реализации (пошаговый)

### ✅ Этап 1: Настройка БД (30 мин)
1. Открыть PocketBase Admin UI (http://localhost:8090/_/)
2. Создать коллекцию `weekly_templates`:
   - Тип: Base Collection
   - Поля: tutorId (relation), dayOfWeek (number), startTime (text), endTime (text), isActive (bool)
   - API Rules: настроить доступ только для владельца
3. Обновить коллекцию `slots`:
   - Добавить поле `generatedFromTemplate` (bool, default: false)
   - Добавить поле `templateId` (relation → weekly_templates, optional)

### ✅ Этап 2: Модели и сервис (1 час)
1. Создать `lib/models/weekly_template.dart`
2. Обновить `lib/models/schedule_slot.dart` (добавить новые поля)
3. Создать `lib/service/weekly_template_service.dart`
4. Добавить функции генерации слотов в `lib/service/schedule_service.dart`

### ✅ Этап 3: UI "Настройка шаблона" (3 часа)
1. Создать `lib/pages/weekly_template_page.dart`
2. Реализовать список дней недели (7 карточек)
3. Диалог добавления времени (два TimePicker)
4. Кнопка "Скопировать на все будни"
5. Валидация пересечений

### ✅ Этап 4: UI "Календарь слотов" (2 часа)
1. Обновить `lib/pages/schedule_page.dart`
2. Добавить TabBar (Шаблон / Календарь)
3. Календарный вид с цветовой кодировкой
4. Bottom Sheet для деталей дня

### ✅ Этап 5: Логика генерации (2 часа)
1. Реализовать `generateSlotsFromTemplate()`
2. Реализовать `checkAndGenerateSlots()`
3. Интегрировать вызовы при открытии страницы
4. Тестирование генерации

### ✅ Этап 6: Обработка исключений (2 часа)
1. Диалоги подтверждения удаления
2. Логика изменения шаблона с предупреждениями
3. Разовое добавление слотов
4. Тестирование edge cases

### ✅ Этап 7: Полировка и тестирование (1 час)
1. Проверка всех сценариев
2. Улучшение UI/UX
3. Обработка ошибок

**Общее время:** ~11-12 часов чистой работы

---

## 🎯 Критерии успеха

### Для репетитора:
✅ Настроил шаблон один раз за 5 минут
✅ Система сама генерирует слоты на месяц вперед
✅ Может удалить/добавить отдельный день без проблем
✅ Не нужно думать о "продлении расписания"

### Для ученика:
✅ Видит слоты на 4 недели вперед
✅ Может забронировать удобное время
✅ Получает уведомление при отмене (в будущем)

### Для диплома:
✅ Профессиональная архитектура БД (2 таблицы, foreign keys)
✅ Умная автоматизация (скользящее окно)
✅ Обработка edge cases (исключения, конфликты)
✅ Хороший UX (два режима работы)

---

## 📚 Дополнительные улучшения (опционально)

### После базовой реализации можно добавить:

1. **Массовые операции:**
   - "Отключить все среды на следующий месяц" (отпуск)
   - "Добавить слоты на праздники"

2. **Статистика:**
   - "У вас 15 свободных слотов на этой неделе"
   - "Загруженность: 60% (12 из 20 слотов забронировано)"

3. **Уведомления:**
   - Push-уведомление ученику при отмене
   - Напоминание репетитору о завтрашних занятиях

4. **Гибкие слоты:**
   - Разная длительность (30 мин, 1 час, 1.5 часа)
   - Разная цена в зависимости от времени

---

## 🚀 С чего начать?

**Следующий шаг:** Создать таблицу `weekly_templates` в PocketBase Admin UI.

Команда для запуска PocketBase (если он не запущен):
```bash
cd pocketbase
docker-compose up -d
```

Затем открыть: http://localhost:8090/_/

Готов начать реализацию? 🔥
