import 'package:flutter/material.dart';
import 'screens/search_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // .env file not found, likely in production
  }

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  final url = dotenv.env['SUPABASE_URL'] ?? supabaseUrl;
  final key = dotenv.env['SUPABASE_ANON_KEY'] ?? supabaseKey;

  if (url.isEmpty || key.isEmpty) {
    throw Exception('Supabase URL and Key must be provided via .env or --dart-define');
  }

  await Supabase.initialize(
    url: url,
    anonKey: key,
  );

  runApp(const CifrasApp());
}

class CifrasApp extends StatefulWidget {
  const CifrasApp({super.key});

  // Static method to toggle theme from anywhere
  static _CifrasAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_CifrasAppState>();

  @override
  State<CifrasApp> createState() => _CifrasAppState();
}

class _CifrasAppState extends State<CifrasApp> {
  ThemeMode _themeMode = ThemeMode.light;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mac Cifras',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const SearchScreen(),
    );
  }
}
