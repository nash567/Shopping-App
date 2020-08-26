import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/http_exception.dart';

class Auth with ChangeNotifier {
  String _token;
  DateTime _expiryDate;
  String _userId;
  Timer _authTimer;

  // Auth({

  // });
  bool get isAuth {
    return token != null;
  }

  String get token {
    if (_expiryDate != null &&
        _expiryDate.isAfter(DateTime.now()) &&
        _token != null) {
      return _token;
    }

    return null;
  }

  String get userId {
    return _userId;
  }

  Future<void> _authenticate(
      String urlSegment, String email, String password) async {
    print(password);
    print(urlSegment);

    final url =
        'https://identitytoolkit.googleapis.com/v1/accounts:$urlSegment?key=AIzaSyAt_jJ1VipuSs7YembG-19cMtzJUOGRCyY';
    print(password);
    print(email);

    try {
      print(password);
      print(email);

      final response = await http.post(url,
          body: json.encode({
            'email': email,
            'password': password,
            'returnSecureToken': true,
          }));

      final responseData = json.decode(response.body);
      print(responseData);

      if (responseData['error'] != null) {
        print('error printing');
        print(
          responseData['error'],
        );

        throw HttpException(
          responseData['error']['message'],
        );
      }

      _token = responseData['idToken'];
      _userId = responseData['localId'];

      _expiryDate = DateTime.now().add(
        Duration(
          seconds: int.parse(
            responseData['expiresIn'],
          ),
        ),
      );
      _autologout();
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final userData = json.encode(
        {
          'token': _token,
          'userId': _userId,
          'expiryDate': _expiryDate.toIso8601String()
        },
      );

      prefs.setString('userData', userData);
    } catch (err) {
      print('err' + err);
      throw err;
    }
  }

  Future<void> signup(String email, String password) async {
    return _authenticate(
      'signUp',
      email,
      password,
    );
  }

  Future<void> login(String email, String password) async {
    await _authenticate(
      'signInWithPassword',
      email,
      password,
    );
  }

  Future<bool> tryAutologin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) {
      return false;
    }

    final extractedUserData =
        json.decode(prefs.getString('userData')) as Map<String, Object>;

    final expiryDate = DateTime.parse(extractedUserData['expiryDate']);
    if (expiryDate.isBefore(DateTime.now())) {
      return false;
    }

    _token = extractedUserData['token'];
    _userId = extractedUserData['userId'];
    _expiryDate = expiryDate;

    notifyListeners();
    _autologout();
    return true;
  }

  void logout() async {
    _token = null;
    _expiryDate = null;
    _userId = null;

    if (_authTimer != null) {
      _authTimer.cancel();
    }

    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('userData'); // clears only a key

//    prefs.clear(); Delets all the data
  }

  void _autologout() {
    if (_authTimer != null) {
      _authTimer.cancel();
    }
    final timeToExpiry = _expiryDate.difference(DateTime.now()).inSeconds;
    _authTimer = Timer(
      Duration(
        seconds: timeToExpiry,
      ),
      logout,
    );
  }
}
