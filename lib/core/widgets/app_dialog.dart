import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The dashboard's dialog shell: dark glass surface, gradient icon badge and
/// a consistent title/actions rhythm. Every dialog in the app builds on this
/// so they stop drifting apart visually.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.actions = const [],
    this.width = 460,
    this.accent,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final List<Widget> actions;
  final double width;
  final Color? accent;

  static const Color surface = Color(0xFF0F1B25);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: accent == null
                    ? AppTheme.primaryGradient
                    : LinearGradient(
                        colors: [accent!, Color.lerp(accent!, Colors.black, 0.35)!],
                      ),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12.5, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(width: width, child: child),
      actions: actions.isEmpty ? null : actions,
    );
  }
}

/// Cancel button styled for [AppDialog] actions.
class AppDialogCancelButton extends StatelessWidget {
  const AppDialogCancelButton({super.key, this.label = 'Cancel', this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed ?? () => Navigator.pop(context, false),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      child: Text(label),
    );
  }
}

/// Primary dialog action with a built-in busy state.
class AppDialogActionButton extends StatelessWidget {
  const AppDialogActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.accent,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? accent;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: accent ?? AppTheme.primaryColor,
        disabledBackgroundColor: (accent ?? AppTheme.primaryColor).withOpacity(0.5),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      ),
      icon: isLoading
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon ?? Icons.check_rounded, size: 17),
      label: Text(label),
    );
  }
}

/// Shows a yes/no confirmation using the shared dialog shell.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  IconData icon = Icons.help_outline_rounded,
  IconData? confirmIcon,
  Color? accent,
  String cancelLabel = 'Cancel',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AppDialog(
      title: title,
      icon: icon,
      accent: accent,
      width: 400,
      actions: [
        AppDialogCancelButton(
          label: cancelLabel,
          onPressed: () => Navigator.pop(dialogContext, false),
        ),
        AppDialogActionButton(
          label: confirmLabel,
          icon: confirmIcon,
          accent: accent,
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
      child: Text(
        message,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.55),
      ),
    ),
  );
  return result ?? false;
}
