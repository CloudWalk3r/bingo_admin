import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:biongo_admin/core/theme/app_theme.dart';
import 'package:biongo_admin/features/navigation/presentation/providers/app_state_provider.dart';
import 'package:biongo_admin/features/navigation/presentation/widgets/side_menu.dart';
import 'package:biongo_admin/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:biongo_admin/features/users/presentation/screens/user_management_screen.dart';
import 'package:biongo_admin/features/drivers/presentation/screens/driver_management_screen.dart';
import 'package:biongo_admin/features/requests/presentation/screens/user_requests_screen.dart';
import 'package:biongo_admin/features/live_tracking/presentation/screens/live_tracking_screen.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07121A),
      body: Stack(
        children: [
          // Animated Background Circles
          Positioned(
            top: -100,
            right: -100,
            child: _AnimatedCircle(
              size: 400,
              color: AppTheme.primaryColor.withOpacity(0.05),
              duration: const Duration(seconds: 15),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _AnimatedCircle(
              size: 300,
              color: AppTheme.accentColor.withOpacity(0.03),
              duration: const Duration(seconds: 20),
            ),
          ),
          
          Row(
            children: [
              const SideMenu(),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(40),
                  child: Consumer<AppStateProvider>(
                    builder: (context, provider, child) {
                      switch (provider.currentView) {
                        case AppView.dashboard: return const DashboardScreen();
                        case AppView.userManagement: return const UserManagementScreen();
                        case AppView.driverManagement: return const DriverManagementScreen();
                        case AppView.userRequests: return const UserRequestsScreen();
                        case AppView.liveTracking: return const LiveTrackingScreen();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimatedCircle extends StatefulWidget {
  final double size;
  final Color color;
  final Duration duration;

  const _AnimatedCircle({
    required this.size,
    required this.color,
    required this.duration,
  });

  @override
  State<_AnimatedCircle> createState() => _AnimatedCircleState();
}

class _AnimatedCircleState extends State<_AnimatedCircle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            20 * _controller.value,
            30 * (1 - _controller.value),
          ),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.1),
                  blurRadius: 100,
                  spreadRadius: 50,
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
