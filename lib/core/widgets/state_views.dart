import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Sweeping highlight used by the skeleton placeholders, so a slow collection
/// reads as "loading" rather than "frozen".
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

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
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final slide = (_controller.value * 2) - 0.5;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (slide - 0.3).clamp(0.0, 1.0),
                slide.clamp(0.0, 1.0),
                (slide + 0.3).clamp(0.0, 1.0),
              ],
              colors: [
                Colors.white.withOpacity(0.04),
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.04),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A single grey block standing in for text that hasn't arrived yet.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

/// Placeholder rows shaped like the real table, shown while the first
/// snapshot is in flight.
class TableSkeleton extends StatelessWidget {
  const TableSkeleton({super.key, this.rows = 7, this.columnFlexes = const [3, 2, 2, 2, 2, 2]});

  final int rows;
  final List<int> columnFlexes;

  @override
  Widget build(BuildContext context) {
    // Clipped rather than scrollable: it is a placeholder, and a short window
    // shouldn't produce an overflow while the first snapshot is in flight.
    return Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: List.generate(rows, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < columnFlexes.length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(
                        flex: columnFlexes[i],
                        child: Row(
                          children: [
                            if (i == 0) ...[
                              const SkeletonBox(width: 34, height: 34, radius: 17),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: SkeletonBox(width: double.infinity, height: i == 0 ? 13 : 11),
                            ),
                            const SizedBox(width: 24),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Nothing-to-show view: a soft icon, a heading and a nudge on what to do.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.08),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.18)),
              ),
              child: Icon(icon, size: 30, color: AppTheme.primaryColor.withOpacity(0.85)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13, height: 1.55),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

/// Failure view with the underlying message kept available but de-emphasised.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({super.key, required this.title, required this.error, this.onRetry});

  final String title;
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.error.withOpacity(0.28)),
          ),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppTheme.error, size: 30),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12, height: 1.5),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Try again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: BorderSide(color: AppTheme.error.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
