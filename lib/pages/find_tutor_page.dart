import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/service/databases.dart';
import 'package:p7/service/tutor_profile_service.dart';
import 'package:p7/models/user.dart';
import 'package:p7/models/tutor_profile.dart';
import 'package:pocketbase/pocketbase.dart';
import 'chat_page.dart';
import 'tutor_profile_page.dart';
import 'package:p7/service/pocketbase_service.dart';

/// Комбинированные данные: профиль репетитора + базовые данные пользователя
class TutorWithUserData {
  final TutorProfile tutorProfile;
  final UserProfile userProfile;

  TutorWithUserData({
    required this.tutorProfile,
    required this.userProfile,
  });
}

class FindTutorPage extends StatefulWidget {
  const FindTutorPage({super.key});

  @override
  State<FindTutorPage> createState() => _FindTutorPageState();
}

class _FindTutorPageState extends State<FindTutorPage> {
  final _db = Databases();
  final _auth = Auth();
  final _tutorProfileService = TutorProfileService();
  final _pb = PocketBaseService().client;

  // Контроллеры для полей
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _priceMinController = TextEditingController();
  final TextEditingController _priceMaxController = TextEditingController();

  // Фильтры
  String _searchQuery = '';
  String? _selectedCity;
  List<String> _cities = [];
  List<String> _selectedSubjects = [];
  String? _selectedLessonFormat; // 'online', 'offline', или null (любой)
  int? _minExperience;

  // Список всех доступных предметов (такой же, как в tutor_profile_setup_page)
  final List<String> _availableSubjects = [
    'Математика',
    'Физика',
    'Химия',
    'Биология',
    'Русский язык',
    'Английский язык',
    'Немецкий язык',
    'История',
    'Обществознание',
    'Литература',
    'География',
    'Информатика',
    'Программирование',
  ];

  // Ключ для принудительного обновления FutureBuilder
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    final cities = await _db.getAllCities();
    setState(() {
      _cities = cities;
    });
  }

  /// Применить фильтры и обновить список (автоматически)
  void _applyFilters() {
    setState(() {
      _refreshKey++; // Принудительно обновляем FutureBuilder
    });
  }

  /// Применить фильтры с небольшой задержкой (для поиска)
  Timer? _debounceTimer;
  void _applyFiltersDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _applyFilters();
    });
  }

  /// Сбросить все фильтры
  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCity = null;
      _selectedSubjects.clear();
      _selectedLessonFormat = null;
      _minExperience = null;
      _priceMinController.clear();
      _priceMaxController.clear();
      _refreshKey++;
    });
  }

  /// Загрузка репетиторов с фильтрацией
  Future<List<TutorWithUserData>> _loadTutors() async {
    try {
      // Строим фильтр для PocketBase
      List<String> filters = [];

      // Фильтр по предметам
      if (_selectedSubjects.isNotEmpty) {
        final subjectFilters =
            _selectedSubjects.map((s) => 'subjects ?~ "$s"').toList();
        filters.add('(${subjectFilters.join(' || ')})');
      }

      // Фильтр по цене
      final priceMin = _priceMinController.text.isNotEmpty
          ? double.tryParse(_priceMinController.text)
          : null;
      final priceMax = _priceMaxController.text.isNotEmpty
          ? double.tryParse(_priceMaxController.text)
          : null;

      if (priceMin != null) {
        filters.add('priceMax >= $priceMin'); // Макс цена репетитора >= мин фильтра
      }
      if (priceMax != null) {
        filters.add('priceMin <= $priceMax'); // Мин цена репетитора <= макс фильтра
      }

      // Фильтр по формату занятий
      if (_selectedLessonFormat != null) {
        filters.add('lessonFormat ?~ "$_selectedLessonFormat"');
      }

      // Фильтр по опыту
      if (_minExperience != null && _minExperience! > 0) {
        filters.add('experience >= $_minExperience');
      }

      // Объединяем фильтры
      final filterStr = filters.isNotEmpty ? filters.join(' && ') : '';

      print('[FindTutor] 🔍 Фильтр: $filterStr');

      // Загружаем tutor_profiles с expand для userId
      final result = await _pb.collection('tutor_profiles').getList(
            filter: filterStr,
            expand: 'userId', // Загружаем данные пользователя
            sort: '-rating,+priceMin',
            perPage: 100,
          );

      print('[FindTutor] ✅ Найдено профилей: ${result.totalItems}');

      // Преобразуем в список TutorWithUserData
      List<TutorWithUserData> tutors = [];

      for (var record in result.items) {
        final tutorProfile = TutorProfile.fromRecord(record);

        // Получаем расширенные данные пользователя из expand
        final expandedData = record.expand;
        if (expandedData != null && expandedData.containsKey('userId')) {
          final userRecordsRaw = expandedData['userId'];
          if (userRecordsRaw != null && userRecordsRaw is List && userRecordsRaw.isNotEmpty) {
            final userRecordRaw = userRecordsRaw.first;
            if (userRecordRaw is RecordModel) {
              final userProfile = UserProfile.fromRecord(userRecordRaw);

              // Применяем дополнительные фильтры (город, имя)
              // Эти фильтры применяем на клиенте, т.к. они относятся к users, а не tutor_profiles

              // Исключаем текущего пользователя
              if (userProfile.uid == _auth.getCurrentUid()) continue;

              // Фильтр по городу
              if (_selectedCity != null && userProfile.city != _selectedCity) {
                continue;
              }

              // Фильтр по имени
              if (_searchQuery.isNotEmpty) {
                if (!userProfile.name.toLowerCase().contains(_searchQuery) &&
                    !userProfile.username.toLowerCase().contains(_searchQuery)) {
                  continue;
                }
              }

              tutors.add(TutorWithUserData(
                tutorProfile: tutorProfile,
                userProfile: userProfile,
              ));
            }
          }
        }
      }

      print('[FindTutor] ✅ После фильтрации: ${tutors.length} репетиторов');

      return tutors;
    } catch (e, stackTrace) {
      print('[FindTutor] ❌ Ошибка загрузки репетиторов:');
      print('  Error: $e');
      print('  StackTrace: $stackTrace');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        title: const Text("П О И С К   Р Е П Е Т И Т О Р А"),
        foregroundColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Column(
        children: [
          // Поисковая строка (как на скриншоте)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
                _applyFiltersDebounced();
              },
              decoration: InputDecoration(
                hintText: 'Предмет, имя репетитора...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 28),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ),

          // Фильтр-чипы (как на скриншоте)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSimpleFilterChip('Предмет', _selectedSubjects.isNotEmpty, () {
                  _showSubjectFilterDialog();
                }),
                const SizedBox(width: 8),
                _buildSimpleFilterChip('Город', _selectedCity != null, () {
                  _showCityFilterDialog();
                }),
                const SizedBox(width: 8),
                _buildSimpleFilterChip('Цена', _priceMinController.text.isNotEmpty || _priceMaxController.text.isNotEmpty, () {
                  _showPriceFilterDialog();
                }),
                const SizedBox(width: 8),
                _buildSimpleFilterChip('Стаж', _minExperience != null, () {
                  _showExperienceFilterDialog();
                }),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Список репетиторов
          Expanded(child: _buildTutorList()),
        ],
      ),
    );
  }

  /// Простой чип фильтра (как на скриншоте)
  Widget _buildSimpleFilterChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Colors.blue[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.blue[700],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Диалог выбора предметов
  void _showSubjectFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Выберите предметы'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableSubjects.map((subject) {
                final isSelected = _selectedSubjects.contains(subject);
                return FilterChip(
                  label: Text(subject),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedSubjects.add(subject);
                      } else {
                        _selectedSubjects.remove(subject);
                      }
                    });
                    setDialogState(() {});
                    _applyFilters();
                  },
                  selectedColor: Theme.of(context).colorScheme.primary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : null,
                    fontSize: 13,
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() => _selectedSubjects.clear());
                _applyFilters();
                Navigator.pop(context);
              },
              child: const Text('Сбросить'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }

  /// Диалог выбора города
  void _showCityFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выберите город'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Все города'),
                leading: Radio<String?>(
                  value: null,
                  groupValue: _selectedCity,
                  onChanged: (value) {
                    setState(() => _selectedCity = null);
                    _applyFilters();
                    Navigator.pop(context);
                  },
                ),
                onTap: () {
                  setState(() => _selectedCity = null);
                  _applyFilters();
                  Navigator.pop(context);
                },
              ),
              ..._cities.map((city) => ListTile(
                    title: Text(city),
                    leading: Radio<String?>(
                      value: city,
                      groupValue: _selectedCity,
                      onChanged: (value) {
                        setState(() => _selectedCity = city);
                        _applyFilters();
                        Navigator.pop(context);
                      },
                    ),
                    onTap: () {
                      setState(() => _selectedCity = city);
                      _applyFilters();
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  /// Диалог фильтра цены
  void _showPriceFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Стоимость занятий (₽/час)'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _priceMinController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'От',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _priceMaxController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'До',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _priceMinController.clear();
              _priceMaxController.clear();
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('Сбросить'),
          ),
          TextButton(
            onPressed: () {
              _applyFilters();
              Navigator.pop(context);
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }

  /// Диалог фильтра опыта/рейтинга
  void _showExperienceFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Опыт работы'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Любой'),
              leading: Radio<int?>(
                value: null,
                groupValue: _minExperience,
                onChanged: (value) {
                  setState(() => _minExperience = null);
                  _applyFilters();
                  Navigator.pop(context);
                },
              ),
              onTap: () {
                setState(() => _minExperience = null);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('1+ год'),
              leading: Radio<int?>(
                value: 1,
                groupValue: _minExperience,
                onChanged: (value) {
                  setState(() => _minExperience = 1);
                  _applyFilters();
                  Navigator.pop(context);
                },
              ),
              onTap: () {
                setState(() => _minExperience = 1);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('3+ года'),
              leading: Radio<int?>(
                value: 3,
                groupValue: _minExperience,
                onChanged: (value) {
                  setState(() => _minExperience = 3);
                  _applyFilters();
                  Navigator.pop(context);
                },
              ),
              onTap: () {
                setState(() => _minExperience = 3);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('5+ лет'),
              leading: Radio<int?>(
                value: 5,
                groupValue: _minExperience,
                onChanged: (value) {
                  setState(() => _minExperience = 5);
                  _applyFilters();
                  Navigator.pop(context);
                },
              ),
              onTap: () {
                setState(() => _minExperience = 5);
                _applyFilters();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorList() {
    return FutureBuilder<List<TutorWithUserData>>(
      key: ValueKey(_refreshKey), // Принудительное обновление
      future: _loadTutors(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ошибка загрузки',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Репетиторы не найдены',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Попробуйте изменить фильтры',
                  style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        final tutors = snapshot.data!;

        return ListView.builder(
          itemCount: tutors.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            return _buildTutorCard(tutors[index]);
          },
        );
      },
    );
  }

  Widget _buildTutorCard(TutorWithUserData tutorData) {
    final user = tutorData.userProfile;
    final tutor = tutorData.tutorProfile;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Аватар + Имя
            Row(
              children: [
                // Большой аватар (как на скриншоте)
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue[300],
                  backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                      ? Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),

                // Имя, предметы, цена, рейтинг
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Имя
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Предметы (чипы)
                      if (tutor.subjects.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: tutor.subjects.take(3).map((subject) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                subject,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 8),

                      // Цена
                      Text(
                        tutor.getPriceDisplay(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Рейтинг + Город
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.orange, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            tutor.isReallyNewbie
                                ? 'Новичок'
                                : '${tutor.rating.toStringAsFixed(1)} (${tutor.totalPaidLessons})',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            ' • ${user.city}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Кнопка "Подробнее" (как на скриншоте)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TutorProfilePage(
                        tutorProfile: tutor,
                        userProfile: user,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Подробнее',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
