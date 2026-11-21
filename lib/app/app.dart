import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/l10n/app_localizations.dart';
import '../core/state/app_cubit.dart';
import 'app_dependencies.dart';
import 'app_scope.dart';
import 'router/app_router.dart';
import 'splash_screen.dart';
import 'theme/app_theme.dart';

class DarviAppBootstrap extends StatefulWidget {
  const DarviAppBootstrap({super.key});

  @override
  State<DarviAppBootstrap> createState() => _DarviAppBootstrapState();
}

class _DarviAppBootstrapState extends State<DarviAppBootstrap> {
  AppDependencies? _dependencies;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    setState(() {
      _error = null;
    });
    try {
      final deps = await AppDependencies.create();
      if (mounted) {
        setState(() {
          _dependencies = deps;
        });
      }
    } catch (e, stack) {
      debugPrint('Initialization error: $e\n$stack');
      if (mounted) {
        setState(() {
          _error = 'Startup error: $e';
        });
      }
    }
  }

  Future<void> _resetAndRepairDb() async {
    setState(() {
      _error = 'Repairing database...';
    });
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'mini_pos_inventory.sqlite'));
      if (await file.exists()) {
        await file.delete();
      }
      await _initApp();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Repair failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dependencies != null) {
      return MiniPosRoot(dependencies: _dependencies!);
    }

    return MaterialApp(
      title: 'Darvi Billing',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: DarviSplashScreen(
        errorMessage: _error,
        onRetry: _initApp,
        onRepair: _resetAndRepairDb,
      ),
    );
  }
}

class MiniPosRoot extends StatefulWidget {
  const MiniPosRoot({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<MiniPosRoot> createState() => _MiniPosRootState();
}

class _MiniPosRootState extends State<MiniPosRoot> {
  late final AppRouter _appRouter = AppRouter(widget.dependencies);

  @override
  void dispose() {
    widget.dependencies.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      dependencies: widget.dependencies,
      child: RepositoryProvider<AppDependencies>.value(
        value: widget.dependencies,
        child: BlocProvider.value(
          value: widget.dependencies.appCubit,
          child: BlocBuilder<AppCubit, AppState>(
            builder: (context, state) {
              final locale = Locale(state.settings.language);
              return MaterialApp.router(
                title: 'Darvi Billing',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                locale: locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                routerConfig: _appRouter.router,
              );
            },
          ),
        ),
      ),
    );
  }
}
