import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../features/projects/screens/project_dashboard.dart';

class AluVisApp extends StatelessWidget {
  const AluVisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AluVis',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
      home: const ProjectDashboard(),
    );
  }
}
