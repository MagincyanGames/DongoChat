import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _isChangingTheme = false;
  ThemeMode? _targetThemeMode;
  
  ThemeProvider() {
    _loadThemePreference();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isChangingTheme => _isChangingTheme;
  ThemeMode? get targetThemeMode => _targetThemeMode;

  void _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('theme_mode') ?? 'system';
    
    switch (themeName) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
    
    notifyListeners();
  }

  // Inicia el proceso de cambio pero no aplica el tema inmediatamente
  void setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    // Solo iniciar la transición, pero no cambiar el tema todavía
    _isChangingTheme = true;
    _targetThemeMode = mode;
    notifyListeners();
  }
  
  // Aplica el cambio de tema después de que la animación ha comenzado
  void applyThemeChange() async {
    if (_targetThemeMode != null) {
      // Aplicar el cambio de tema
      _themeMode = _targetThemeMode!;
      notifyListeners();
      
      // Guardar la preferencia
      final prefs = await SharedPreferences.getInstance();
      String themeName;
      
      switch (_themeMode) {
        case ThemeMode.light:
          themeName = 'light';
          break;
        case ThemeMode.dark:
          themeName = 'dark';
          break;
        default:
          themeName = 'system';
      }
      
      await prefs.setString('theme_mode', themeName);
    }
  }
  
  // Completa el proceso de cambio (llamado al final de la animación)
  void completeThemeChange() {
    if (_isChangingTheme) {
      _isChangingTheme = false;
      _targetThemeMode = null;
      notifyListeners();
    }
  }
}