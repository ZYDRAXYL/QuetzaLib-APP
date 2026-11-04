import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'state/library_provider.dart';
import 'theme.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Noto Sans Thai'],
      await rootBundle.loadString('assets/fonts/NotoSansThai-OFL.txt'),
    );
  });
  runApp(const QuetzaLibApp());
}

class QuetzaLibApp extends StatelessWidget {
  const QuetzaLibApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LibraryProvider()..loadAll(),
      child: Consumer<LibraryProvider>(
        builder: (context, library, _) {
          return MaterialApp(
            title: 'QuetzaLib',
            theme: buildAppTheme(Brightness.light),
            darkTheme: buildAppTheme(Brightness.dark),
            themeMode: library.appThemeMode.themeMode,
            locale: library.appLocale.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
