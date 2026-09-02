import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:biongo_admin/features/auth/presentation/providers/auth_provider.dart';
import 'package:biongo_admin/features/auth/presentation/screens/login_screen.dart';
import 'package:biongo_admin/features/navigation/presentation/screens/main_layout.dart';

/// Shows the login screen until an admin signs in, then the dashboard shell.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = context.select<AuthProvider, bool>((a) => a.isAuthenticated);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: isAuthenticated
          ? const MainLayout(key: ValueKey('main'))
          : const LoginScreen(key: ValueKey('login')),
    );
  }
}
