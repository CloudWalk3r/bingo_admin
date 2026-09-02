import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/admin_search_field.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../domain/entities/registration_request_entity.dart';
import '../../domain/repositories/registration_request_repository.dart';

enum _TypeFilter { all, drivers, houseOwners }

class RegistrationRequestsScreen extends StatefulWidget {
  const RegistrationRequestsScreen({super.key});

  @override
  State<RegistrationRequestsScreen> createState() => _RegistrationRequestsScreenState();
}

class _RegistrationRequestsScreenState extends State<RegistrationRequestsScreen> {
  String _query = '';
  _TypeFilter _filter = _TypeFilter.all;

  /// Requests with an approve/reject write in flight.
  final Set<String> _processing = {};

  Future<void> _review(RegistrationRequestEntity request, {required bool approve}) async {
    if (_processing.contains(request.id)) return;

    final isDriver = request.type == RegistrationType.driver;
    final name = request.name.isEmpty ? 'this applicant' : request.name;

    final confirmed = await showAppConfirmDialog(
      context,
      title: approve ? 'Approve registration' : 'Reject registration',
      icon: approve ? Icons.verified_outlined : Icons.person_off_outlined,
      accent: approve ? AppTheme.success : AppTheme.error,
      confirmLabel: approve ? 'Approve' : 'Reject',
      confirmIcon: approve ? Icons.check_rounded : Icons.close_rounded,
      message: approve
          ? (isDriver
                ? 'Approve $name as a driver? They join the Driver Fleet and become assignable to collection routes.'
                : 'Approve $name as a house owner? They appear under Registered House Owners.')
          : 'Reject $name\'s registration? They will not be added, and the request leaves this list.',
    );
    if (!confirmed || !mounted) return;

    final repo = Provider.of<RegistrationRequestRepository>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _processing.add(request.id));

    try {
      if (approve) {
        await repo.approve(request);
      } else {
        await repo.reject(request);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('$name ${approve ? 'approved' : 'rejected'}'),
          backgroundColor: approve ? AppTheme.success : AppTheme.textTertiary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save: $error'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing.remove(request.id));
    }
  }

  List<RegistrationRequestEntity> _visibleRequests(List<RegistrationRequestEntity> requests) {
    final query = _query.trim().toLowerCase();

    return requests.where((request) {
      switch (_filter) {
        case _TypeFilter.drivers:
          if (request.type != RegistrationType.driver) return false;
        case _TypeFilter.houseOwners:
          if (request.type != RegistrationType.houseOwner) return false;
        case _TypeFilter.all:
          break;
      }
      if (query.isEmpty) return true;
      return request.name.toLowerCase().contains(query) ||
          request.mobile.toLowerCase().contains(query) ||
          request.nic.toLowerCase().contains(query) ||
          request.email.toLowerCase().contains(query);
    }).toList()..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<RegistrationRequestRepository>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'Registration Requests',
          subtitle:
              'Drivers and house owners who signed up through the app, awaiting your approval.',
        ),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<List<RegistrationRequestEntity>>(
            stream: repo.watchPending(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorStateView(
                  title: 'Could not load registration requests',
                  error: snapshot.error!,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _RequestCardSkeleton();
              }

              final requests = snapshot.data ?? const <RegistrationRequestEntity>[];
              if (requests.isEmpty) {
                return const EmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'All caught up',
                  message: 'No registrations are waiting for review right now.',
                );
              }

              final driverCount = requests.where((r) => r.type == RegistrationType.driver).length;
              final visible = _visibleRequests(requests);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TableToolbar(
                    leading: [
                      AdminSearchField(
                        hintText: 'Search name, NIC, mobile or email…',
                        width: 320,
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      FilterSegments<_TypeFilter>(
                        selected: _filter,
                        onSelected: (value) => setState(() => _filter = value),
                        options: [
                          FilterOption(
                            value: _TypeFilter.all,
                            label: 'All',
                            count: requests.length,
                          ),
                          FilterOption(
                            value: _TypeFilter.drivers,
                            label: 'Drivers',
                            count: driverCount,
                          ),
                          FilterOption(
                            value: _TypeFilter.houseOwners,
                            label: 'House Owners',
                            count: requests.length - driverCount,
                            color: AppTheme.accentColor,
                          ),
                        ],
                      ),
                    ],
                    trailing: [
                      StatChip(
                        label: 'Pending',
                        value: '${requests.length}',
                        icon: Icons.pending_actions_rounded,
                        color: AppTheme.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: visible.isEmpty
                        ? const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No requests match your filters',
                            message: 'Try a different type or clear the search.',
                          )
                        : ListView.separated(
                            itemCount: visible.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final request = visible[index];
                              return _RequestCard(
                                key: ValueKey(request.id),
                                request: request,
                                isProcessing: _processing.contains(request.id),
                                onApprove: () => _review(request, approve: true),
                                onReject: () => _review(request, approve: false),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatefulWidget {
  const _RequestCard({
    super.key,
    required this.request,
    required this.isProcessing,
    required this.onApprove,
    required this.onReject,
  });

  final RegistrationRequestEntity request;
  final bool isProcessing;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final isDriver = request.type == RegistrationType.driver;
    final typeColor = isDriver ? AppTheme.primaryColor : AppTheme.accentColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _hovered ? Colors.white.withOpacity(0.045) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hovered ? typeColor.withOpacity(0.35) : AppTheme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [typeColor, Color.lerp(typeColor, Colors.black, 0.35)!],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      request.name.isNotEmpty ? request.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            request.name.isEmpty ? '(no name)' : request.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          StatusPill(
                            label: isDriver ? 'DRIVER' : 'HOUSE OWNER',
                            color: typeColor,
                            icon: isDriver ? Icons.local_shipping_rounded : Icons.home_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Submitted ${DateFormat('MMM dd, yyyy • hh:mm a').format(request.submittedAt)}',
                        style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (widget.isProcessing)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      _ReviewButton(
                        label: 'Reject',
                        icon: Icons.close_rounded,
                        color: AppTheme.error,
                        filled: false,
                        onPressed: widget.onReject,
                      ),
                      const SizedBox(width: 10),
                      _ReviewButton(
                        label: 'Approve',
                        icon: Icons.check_rounded,
                        color: AppTheme.success,
                        filled: true,
                        onPressed: widget.onApprove,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(color: AppTheme.borderColor, height: 1),
            const SizedBox(height: 16),
            Wrap(
              spacing: 32,
              runSpacing: 14,
              children: [
                _DetailField(label: 'Mobile', value: request.mobile, icon: Icons.call_outlined),
                _DetailField(label: 'NIC', value: request.nic, icon: Icons.badge_outlined),
                _DetailField(
                  label: 'Email',
                  value: request.email,
                  icon: Icons.mail_outline_rounded,
                ),
                if (!isDriver && (request.houseNumber ?? '').isNotEmpty)
                  _DetailField(
                    label: 'House No',
                    value: request.houseNumber!,
                    icon: Icons.numbers_rounded,
                  ),
                if (!isDriver && (request.address ?? '').isNotEmpty)
                  _DetailField(
                    label: 'Address',
                    value: request.address!,
                    icon: Icons.location_on_outlined,
                    width: 300,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewButton extends StatelessWidget {
  const _ReviewButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: color.withOpacity(filled ? 0.18 : 0.06),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withOpacity(filled ? 0.55 : 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    required this.icon,
    this.width = 210,
  });

  final String label;
  final String value;
  final IconData icon;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppTheme.textTertiary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? '—' : value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCardSkeleton extends StatelessWidget {
  const _RequestCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: List.generate(3, (index) {
            return Container(
              height: 150,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      SkeletonBox(width: 46, height: 46, radius: 23),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 180, height: 15),
                          SizedBox(height: 8),
                          SkeletonBox(width: 220, height: 11),
                        ],
                      ),
                      Spacer(),
                      SkeletonBox(width: 90, height: 36, radius: 11),
                      SizedBox(width: 10),
                      SkeletonBox(width: 90, height: 36, radius: 11),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: const [
                      SkeletonBox(width: 150, height: 30),
                      SizedBox(width: 32),
                      SkeletonBox(width: 150, height: 30),
                      SizedBox(width: 32),
                      SkeletonBox(width: 150, height: 30),
                    ],
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
