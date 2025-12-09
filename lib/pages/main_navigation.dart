import 'package:flutter/material.dart';
import 'package:p7/pages/find_tutor_page.dart';
import 'package:p7/pages/home_page.dart';
import 'package:p7/pages/profile_page.dart';
import 'package:p7/pages/schedule_page.dart';
import '../service/auth.dart';

/// Главная навигация приложения с Bottom Navigation Bar
///
/// 4 основных раздела:
/// - Чаты (HomePage) - список активных чатов
/// - Поиск (FindTutorPage) - поиск репетиторов
/// - График (SchedulePage) - расписание (для репетиторов и учеников)
/// - Профиль (ProfilePage) - профиль пользователя
///
/// Дополнительно: Settings доступен через AppBar (иконка ⚙️)
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final Auth _auth = Auth();
  int _currentIndex = 0;

  // Список страниц для каждого таба
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Инициализируем страницы с текущим UID
    _pages = [
      const HomePage(),
      FindTutorPage(),
      const SchedulePage(),
      ProfilePage(uid: _auth.getCurrentUid()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // Показываем текущую страницу
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      // AppBar только для страниц где он нужен
      // (HomePage, FindTutorPage уже имеют свой AppBar)
      appBar: _buildAppBar(colorScheme),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed, // Всегда показывать labels
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.secondary.withValues(alpha: 0.6),
        backgroundColor: colorScheme.surface,
        elevation: 8,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Чаты',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            activeIcon: Icon(Icons.search),
            label: 'Поиск',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'График',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }

  /// AppBar с иконкой настроек (только для некоторых страниц)
  PreferredSizeWidget? _buildAppBar(ColorScheme colorScheme) {
    // HomePage, FindTutorPage, SchedulePage, ProfilePage имеют свой AppBar
    // Поэтому возвращаем null, чтобы не было двух AppBar
    return null;
  }
}
