import 'package:flutter/material.dart';

class DarviSplashScreen extends StatelessWidget {
  const DarviSplashScreen({
    super.key,
    this.errorMessage,
    this.onRetry,
    this.onRepair,
  });

  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onRepair;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                // Official Darvi Group Full Logo
                Image.asset(
                  'assets/darvi_logo.png',
                  width: 280,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/darvi_icon.png',
                          width: 64,
                          height: 64,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.eco,
                            size: 64,
                            color: Color(0xFF8BC34A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'DARVI GROUP',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Improving Agriculture, Improving lives.',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 2),
                if (errorMessage != null) ...[
                  Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF135D44),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: onRetry,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Retry Startup'),
                              ),
                              if (onRepair != null) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                    side: BorderSide(color: Colors.red.shade300),
                                  ),
                                  onPressed: onRepair,
                                  icon: const Icon(Icons.build, size: 18),
                                  label: const Text('Reset & Repair'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8BC34A)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading store records...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const Spacer(flex: 1),
                const Text(
                  'Darvi Billing v1.0.0 • Hubli, Karnataka',
                  style: TextStyle(fontSize: 11, color: Colors.black38),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

