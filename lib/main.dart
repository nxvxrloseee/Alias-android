import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/board.dart';
import 'screens/home.dart';
import 'sfx.dart';
import 'state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: C.felt,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  app = AppState();
  await app.init();
  Sfx.init();
  runApp(const AliasApp());
}

class AliasApp extends StatelessWidget {
  const AliasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Элиас',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ru'),
      home: const HomeScreen(),
      routes: {BoardScreen.route: (_) => const BoardScreen()},
    );
  }
}
