import 'package:cbtapp/views/admin/admin_view.dart';
import 'package:cbtapp/views/student/student_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
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
      home: kIsWeb ? const StudentView() : const AdminView(),
    );
  }
}