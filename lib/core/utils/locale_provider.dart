import 'package:flutter/material.dart';

class LocaleProvider extends ChangeNotifier {
  Locale? locale;

  LocaleProvider({this.locale});

  void updateLocale(Locale? newLocale) {
    locale = newLocale;
    notifyListeners();
  }
}
