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

class CifrasApp extends StatelessWidget {
  const CifrasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cifras App',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const SearchScreen(),
    );
  }
}
