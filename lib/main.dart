import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/di/injection_container.dart';
import 'core/routing/app_router.dart';
import 'core/services/presence_lifecycle_observer.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'core/config/supabase_config.dart';
import 'core/monitoring/error_monitor.dart';
import 'core/widgets/upload_progress_overlay.dart';
import 'core/services/server_realtime_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // Dependency Injection
  await initDependencies();

  // Global error monitoring: routes framework errors and uncaught async
  // errors to the server so the platform owner can see real failures instead
  // of relying on users describing them.
  ErrorMonitor.install();

  runApp(
    const ProviderScope(
      child: MashareenaApp(),
    ),
  );
}

class MashareenaApp extends ConsumerWidget {
  const MashareenaApp({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(globalServerRealtimeSyncProvider);
    final palette = ref.watch(themeControllerProvider);
    final theme = AppTheme.fromPalette(palette);

    return MaterialApp(
      title: 'مشاريعنا | Mashareena',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      builder: (
        context,
        child,
      ) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: UploadProgressOverlay(child: child ?? const SizedBox.shrink()),
        );
      },
      home: const PresenceLifecycleObserver(child: AppRouter()),
    );
  }
}
