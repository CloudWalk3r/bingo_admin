import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:biongo_admin/core/theme/app_theme.dart';
import 'package:biongo_admin/features/navigation/presentation/providers/app_state_provider.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);

    return Container(
      width: 280,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF07121A).withOpacity(0.5),
        border: const Border(right: BorderSide(color: AppTheme.borderColor)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.recycling, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Biongo Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _buildMenuItem(context, 0, Icons.dashboard_outlined, 'Dashboard', appState),
          _buildMenuItem(context, 1, Icons.people_outline_rounded, 'User Management', appState),
          _buildMenuItem(context, 2, Icons.local_shipping_outlined, 'Driver Management', appState),
          _buildMenuItem(context, 3, Icons.assignment_outlined, 'User Requests', appState),
          _buildMenuItem(context, 4, Icons.my_location_outlined, 'Live Tracking', appState),
          
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'v1.0.2 - Beta',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, int index, IconData icon, String title, AppStateProvider appState) {
    final isSelected = appState.selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => appState.setIndex(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            gradient: isSelected ? LinearGradient(
              colors: [AppTheme.primaryColor.withOpacity(0.2), Colors.transparent],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              if (isSelected)
                const Spacer(),
              if (isSelected)
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryColor,
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
