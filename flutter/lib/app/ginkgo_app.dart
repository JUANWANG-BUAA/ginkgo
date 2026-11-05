import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:ginkgo_mirror/application/external_links.dart';
import 'package:ginkgo_mirror/platform/external_links.dart';
import 'package:ginkgo_mirror/widgets/school_links.dart';
import 'package:ginkgo_mirror/shared/app_preferences.dart';
import 'package:ginkgo_mirror/design/ginkgo_theme.dart';
import 'package:ginkgo_mirror/application/startup_update_controller.dart';
import 'package:ginkgo_mirror/features/settings/startup_update_hint.dart';
import 'package:ginkgo_mirror/application/task_storage_scope.dart';
import 'package:ginkgo_mirror/infrastructure/task_storage.dart';

Widget ginkgoApp({
  required Widget home,
  Brightness? brightness,
  AppPreferences? preferences,
  StartupUpdateController? startupUpdate,
  ExternalLinkLauncher externalLinkLauncher = launchExternalLink,
}) {
  final settings = preferences ?? AppPreferences.shared;
  return ListenableBuilder(
    listenable: settings,
    builder: (context, _) => TaskStorageScope(
      resolve: localTasksStorageRoot,
      child: AppPreferencesScope(
        preferences: settings,
        child: ExternalLinkScope(
          launcher: externalLinkLauncher,
          child: CupertinoApp(
            title: 'Ginkgo',
            debugShowCheckedModeBanner: false,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: GlobalCupertinoLocalizations.delegates,
            theme: ginkgoTheme(
              brightness ?? settings.appearance.brightness,
              settings.accent.color,
            ),
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: settings.textSize == 1
                      ? media.textScaler
                      : TextScaler.linear(
                          media.textScaler.scale(14) / 14 * settings.textSize,
                        ),
                  disableAnimations:
                      media.disableAnimations || settings.reduceMotion,
                ),
                child: child!,
              );
            },
            home: startupUpdate == null
                ? home
                : StartupUpdateHint(controller: startupUpdate, child: home),
          ),
        ),
      ),
    ),
  );
}
