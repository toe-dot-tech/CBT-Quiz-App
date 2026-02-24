// LOCATION: lib/main.dart

import 'package:cbt_software/views/admin/admin_view.dart';
import 'package:cbt_software/views/student/student_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  // This ensures Flutter is ready before we do any platform checks
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CBT Quiz System',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      // kIsWeb is a constant that is true when running in a browser
      // We only show the AdminView if we are NOT on web.
      home: kIsWeb ? const StudentView() : const AdminView(),
    );
  }
}
