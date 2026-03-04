import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeColor {
  final lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal[300]!,
      surface: const Color.fromARGB(255, 255, 255, 255),
      primary: Colors.teal[700]!,
      tertiary: Color.fromARGB(255, 7, 255, 230),
      secondary: Color(0xFF018786),
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.latoTextTheme(),
  );

  final darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal[300]!,
      surface: const Color.fromARGB(255, 72, 71, 71),
      primary: Colors.teal[700]!,
      tertiary: Color(0xFF03DAC6),
      secondary: Color(0xFF018786),
      brightness: Brightness.dark,
    ),
    textTheme: GoogleFonts.latoTextTheme(ThemeData.dark().textTheme),
  );
}