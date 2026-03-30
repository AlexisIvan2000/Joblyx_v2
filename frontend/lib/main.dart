import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/core/theme/theme_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/l10n/app_localizations.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/settings/presentation/providers/preferences_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Crashlytics — capturer toutes les erreurs en production
  if (!kDebugMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // Rediriger vers le login si la session expire
  ApiClient().onSessionExpired = () {
    appRouter.go('/first-page');
  };
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  GoogleFonts.config.allowRuntimeFetching = true;

  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = ThemeColor();
    final prefs = ref.watch(preferencesProvider);

    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Joblyx',
          theme: themeColor.lightTheme,
          darkTheme: themeColor.darkTheme,
          themeMode: prefs.themeMode,
          // Langue : préférence utilisateur ou langue système
          locale: prefs.locale,
          routerConfig: appRouter,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // Si la locale n'est pas supportée → fallback en anglais
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            // Si l'utilisateur a choisi une langue, l'utiliser
            if (prefs.locale != null) return prefs.locale;
            // Sinon, utiliser la langue du système si supportée
            for (final locale in supportedLocales) {
              if (locale.languageCode == deviceLocale?.languageCode) return locale;
            }
            // Fallback anglais
            return const Locale('en');
          },
        );
      },
    );
  }
}
