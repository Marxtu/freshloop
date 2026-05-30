import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'app/dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  appPrefs = await SharedPreferences.getInstance();
  runApp(const FreshLoopApp());
}
