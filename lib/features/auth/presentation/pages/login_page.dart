import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/state/app_cubit.dart';
import '../../../../core/widgets/buttons.dart';
import '../../../../core/widgets/fields.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _pinController = TextEditingController(text: '1234');
  final _adminController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    _adminController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<AppCubit, AppState>(
      listenWhen: (previous, current) => previous.isAuthenticated != current.isAuthenticated,
      listener: (context, state) {
        if (state.isAuthenticated) {
          context.go('/pos');
        }
      },
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: BlocBuilder<AppCubit, AppState>(
                    builder: (context, state) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/darvi_logo.png',
                              height: 64,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset('assets/darvi_icon.png', height: 48, width: 48),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.tr('appTitle'),
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF333333),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Center(
                            child: Text(
                              'Improving Agriculture, Improving lives.',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(l10n.tr('login'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _pinController,
                            label: l10n.tr('pin'),
                            keyboardType: TextInputType.number,
                            obscureText: true,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          PrimaryButton(
                            label: l10n.tr('continueAsCashier'),
                            onPressed: state.loading
                                ? null
                                : () => context.read<AppCubit>().loginCashier(_pinController.text.trim()),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppTextField(
                            controller: _adminController,
                            label: l10n.tr('adminPassword'),
                            obscureText: true,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                            onPressed: state.loading
                                ? null
                                : () => context.read<AppCubit>().loginAdmin(_adminController.text.trim()),
                            icon: const Icon(Icons.admin_panel_settings_outlined),
                            label: Text(l10n.tr('continueAsAdmin')),
                          ),
                          if (state.error != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              l10n.tr('invalidCredentials'),
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
