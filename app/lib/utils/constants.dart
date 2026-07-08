import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const navy = Color(0xFF0E2A47);
  static const navyDeep = Color(0xFF081B2E);
  static const gold = Color(0xFFC79A3E);
  static const green = Color(0xFF1B9E5A);
  static const red = Color(0xFFD1483A);
  static const muted = Color(0xFF8A93A6);
  static const divider = Color(0xFFE7EAEF);
  static const chipBg = Color(0xFFEFF2F6);

  // tag palette offered in color picker (Mac-tags style)
  static const tagPalette = <Color>[
    Color(0xFFD1483A), // red
    Color(0xFFE08A2C), // orange
    Color(0xFFD4B72E), // yellow
    Color(0xFF1B9E5A), // green
    Color(0xFF2E8CD4), // blue
    Color(0xFF7A4FD1), // purple
    Color(0xFF8A93A6), // gray
  ];
}

const apiBaseUrl = 'http://192.168.0.105:8080/api/v1';

const bondScannerScheme = 'bondscanner://bond/';
const bondScannerPlayStore =
    'https://play.google.com/store/apps/details?id=com.bondscanner.app';
const bondScannerAppStore =
    'https://apps.apple.com/app/bondscanner/id0000000000';

const maxWishlists = 5;
const maxBondsPerWishlist = 10;
