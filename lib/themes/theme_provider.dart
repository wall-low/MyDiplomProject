import 'package:flutter/material.dart';
import 'package:p7/themes/dark_mode.dart';
import 'package:p7/themes/light_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemProvider with ChangeNotifier {
  static const _prefKey = 'isDarkMode';
  ThemeData _themeData = lightMode;

  ThemeData get themeData => _themeData;

  bool get isDarkMode => _themeData == darkMode;

  ThemProvider(){
    _loadFromPrefs();
  }


  void toggleTheme(){
    _themeData = isDarkMode ? lightMode : darkMode;
    notifyListeners();
    _saveToPrefers();
  }

  Future<void> _saveToPrefers() async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, isDarkMode);
  }

  Future<void> _loadFromPrefs() async{
    final prefs = await SharedPreferences.getInstance();
    final savedDarkMode = prefs.getBool(_prefKey) ?? false;
    _themeData = savedDarkMode ? darkMode : lightMode;
    notifyListeners();
  }

}