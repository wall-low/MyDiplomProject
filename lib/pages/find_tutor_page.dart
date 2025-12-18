import 'package:flutter/material.dart';
import 'package:p7/components/user_tile.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/service/databases.dart';
import 'package:p7/models/user.dart';
import 'chat_page.dart';

class FindTutorPage extends StatefulWidget {
  const FindTutorPage({super.key});

  @override
  State<FindTutorPage> createState() => _FindTutorPageState();
}

class _FindTutorPageState extends State<FindTutorPage> {
  final Databases _db = Databases();
  final Auth _auth = Auth();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedCity;
  List<String> _cities = [];

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    // Загружаем уникальные города из базы
    final cities = await _db.getAllCities();
    setState(() {
      _cities = cities;
    });
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
          // Поиск и фильтры
          _buildSearchSection(),
          const SizedBox(height: 10),
          // Список репетиторов
          Expanded(child: _buildTutorList()),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.tertiary,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Поле поиска
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Поиск по имени...',
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.primary,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
                  : null,
              filled: true,
              fillColor: Theme.of(context).colorScheme.onSecondary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Фильтр по городу
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: Text(
                  'Выберите город',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                value: _selectedCity,
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Theme.of(context).colorScheme.primary,
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                ),
                dropdownColor: Theme.of(context).colorScheme.onSecondary,
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      'Все города',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  ..._cities.map((String city) {
                    return DropdownMenuItem<String>(
                      value: city,
                      child: Text(city),
                    );
                  }).toList(),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCity = newValue;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorList() {
    // ИЗМЕНЕНО: StreamBuilder → FutureBuilder
    // ИЗМЕНЕНО: getTutorsStream() → getTutorsList()
    //
    // PocketBase использует Future вместо Stream
    return FutureBuilder<List<UserProfile>>(
      future: _db.getTutorsList(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Ошибка загрузки',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
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
                  Icons.person_search,
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
              ],
            ),
          );
        }

        // Фильтрация
        List<UserProfile> tutors = snapshot.data!
            .where((tutor) {
          // Исключаем текущего пользователя
          if (tutor.uid == _auth.getCurrentUid()) return false;

          // Фильтр по городу
          if (_selectedCity != null && tutor.city != _selectedCity) {
            return false;
          }

          // Фильтр по имени
          if (_searchQuery.isNotEmpty) {
            return tutor.name.toLowerCase().contains(_searchQuery) ||
                tutor.username.toLowerCase().contains(_searchQuery);
          }

          return true;
        })
            .toList();

        if (tutors.isEmpty) {
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
                  'Ничего не найдено',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Попробуйте изменить фильтры',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: tutors.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            return _buildTutorTile(tutors[index]);
          },
        );
      },
    );
  }

  Widget _buildTutorTile(UserProfile tutor) {
    return UserTile(
      text: tutor.name,
      avatarUrl: tutor.avatarUrl,
      subtitle: '${tutor.city} • ${tutor.role}',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              receiverName: tutor.name, // ИЗМЕНЕНО: передаём name
              receiverID: tutor.uid,
            ),
          ),
        );
      },
    );
  }
}