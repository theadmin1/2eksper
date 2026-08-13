import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isLoggedIn = false;
  String? _token;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _firma;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  Map<String, dynamic>? get firma => _firma;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    ApiService.onUnauthorized = _expireSession;
    tryAutoLogin();
  }

  Future<void> _expireSession() async {
    if (!_isLoggedIn) return;
    _errorMessage = 'Oturumunuz sona erdi. Lütfen yeniden giriş yapın.';
    await logout();
  }

  // Oturum durumunu kontrol et
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      _token = prefs.getString('auth_token');
      final userDataStr = prefs.getString('user_data');
      final firmaDataStr = prefs.getString('firma_data');

      // Eski Base64 jetonları ve eski Map.toString kayıtları yeni imzalı
      // oturum biçimiyle uyumlu değildir; kullanıcıdan bir kez yeniden giriş istenir.
      if (_token != null && _token!.contains('.') && userDataStr != null) {
        _user = jsonDecode(userDataStr) as Map<String, dynamic>;
        if (firmaDataStr != null) {
          _firma = jsonDecode(firmaDataStr) as Map<String, dynamic>;
        }
        _isLoggedIn = true;
        return true;
      }
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      await prefs.remove('firma_data');
      return false;
    } catch (_) {
      await prefs.remove('auth_token');
      await prefs.remove('user_data');
      await prefs.remove('firma_data');
      return false;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Giriş Yap
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.post('login.php', {
        'username': username,
        'password': password,
      });

      final data = ApiData.map(res['data']);
      if (res['status'] == true && data.isNotEmpty) {
        _token = '${data['token'] ?? ''}';
        _user = ApiData.map(data['user']);
        _firma = ApiData.map(data['firma']);
        if (_token!.isEmpty || _user!.isEmpty) {
          throw const ApiException('Sunucu oturum bilgilerini eksik gönderdi.');
        }
        _isLoggedIn = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        await prefs.setString('user_data', jsonEncode(_user));
        await prefs.setString('firma_data', jsonEncode(_firma));

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = res['message'] ?? 'Giriş başarısız.';
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Çıkış Yap
  Future<void> logout() async {
    _token = null;
    _user = null;
    _firma = null;
    _isLoggedIn = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    await prefs.remove('firma_data');

    notifyListeners();
  }
}
