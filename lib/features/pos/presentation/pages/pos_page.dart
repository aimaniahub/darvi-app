import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/app_scope.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/states.dart';
import '../cubit/pos_cubit.dart';
import '../widgets/pos_checkout_review_view.dart';
import '../widgets/pos_invoice_preview_view.dart';
import '../widgets/pos_workspace_view.dart';

class PosPage extends StatelessWidget {
  const PosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final deps = AppScope.of(context);
    return BlocProvider(
      create: (context) => PosCubit(
        productRepository: deps.productRepository,
        salesRepository: deps.salesRepository,
        settingsRepository: deps.settingsRepository,
        partyRepository: deps.partyRepository,
        accountRepository: deps.accountRepository,
        scannerService: deps.barcodeScannerService,
        receiptPdfService: deps.receiptPdfService,
      )..load(),
      child: const _PosView(),
    );
  }
}

class _PosView extends StatelessWidget {
  const _PosView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        if (state.loading && state.products.isEmpty) {
          return const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: LoadingSkeleton(),
            ),
          );
        }

        switch (state.viewMode) {
          case PosViewMode.workspace:
            return const PosWorkspaceView();
          case PosViewMode.checkoutReview:
            return const PosCheckoutReviewView();
          case PosViewMode.invoicePreview:
            return const PosInvoicePreviewView();
        }
      },
    );
  }
}
