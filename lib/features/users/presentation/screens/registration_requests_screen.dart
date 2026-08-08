import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/registration_request_entity.dart';
import '../../domain/repositories/registration_request_repository.dart';

class RegistrationRequestsScreen extends StatefulWidget {
  const RegistrationRequestsScreen({super.key});

  @override
  State<RegistrationRequestsScreen> createState() => _RegistrationRequestsScreenState();
}

class _RegistrationRequestsScreenState extends State<RegistrationRequestsScreen> {
  Future<bool> _confirm({required String title, required String message, required Color accent, required String confirmLabel}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.borderColor)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textTertiary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _approveRequest(RegistrationRequestEntity request) async {
    final confirmed = await _confirm(
      title: 'Approve Registration',
      message: 'Approve ${request.name}\'s ${request.type == RegistrationType.driver ? 'driver' : 'house owner'} registration? ${request.type == RegistrationType.driver ? 'They will be added to the Driver Fleet and become assignable.' : 'They will appear in Registered Home Users.'}',
      accent: AppTheme.success,
      confirmLabel: 'Approve',
    );
    if (!confirmed || !mounted) return;

    final repo = Provider.of<RegistrationRequestRepository>(context, listen: false);
    try {
      await repo.approve(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${request.name} approved'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  void _rejectRequest(RegistrationRequestEntity request) async {
    final confirmed = await _confirm(
      title: 'Reject Registration',
      message: 'Reject ${request.name}\'s registration? They will not be added, and this request will be removed from the pending list.',
      accent: AppTheme.error,
      confirmLabel: 'Reject',
    );
    if (!confirmed || !mounted) return;

    final repo = Provider.of<RegistrationRequestRepository>(context, listen: false);
    try {
      await repo.reject(request);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${request.name} rejected'), backgroundColor: AppTheme.textTertiary, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<RegistrationRequestRepository>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Registration Requests', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 6),
        const Text(
          'Drivers and house owners who registered through the app, awaiting your approval.',
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<List<RegistrationRequestEntity>>(
            stream: repo.watchPending(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Could not load registration requests: ${snapshot.error}', style: const TextStyle(color: AppTheme.error)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
              }
              final requests = snapshot.data ?? [];
              if (requests.isEmpty) {
                return const Center(child: Text('No pending registrations. All caught up!', style: TextStyle(color: AppTheme.textTertiary)));
              }

              return ListView.separated(
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _buildPendingRow(requests[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPendingRow(RegistrationRequestEntity request) {
    final isDriver = request.type == RegistrationType.driver;
    final typeColor = isDriver ? AppTheme.primaryColor : AppTheme.accentColor;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [typeColor, Color.lerp(typeColor, Colors.black, 0.3)!]),
                ),
                child: Center(
                  child: Text(
                    request.name.isNotEmpty ? request.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(request.name.isEmpty ? '(no name)' : request.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: typeColor.withOpacity(0.14), borderRadius: BorderRadius.circular(20), border: Border.all(color: typeColor.withOpacity(0.4))),
                          child: Text(isDriver ? 'DRIVER' : 'HOUSE OWNER', style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Submitted ${DateFormat('MMM dd, yyyy • hh:mm a').format(request.submittedAt)}', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 26),
                tooltip: 'Approve',
                onPressed: () => _approveRequest(request),
              ),
              IconButton(
                icon: const Icon(Icons.cancel_outlined, color: AppTheme.error, size: 26),
                tooltip: 'Reject',
                onPressed: () => _rejectRequest(request),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppTheme.borderColor, height: 1),
          const SizedBox(height: 14),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _detailField('Mobile', request.mobile, Icons.call_outlined),
              _detailField('NIC', request.nic, Icons.badge_outlined),
              _detailField('Email', request.email, Icons.mail_outline_rounded),
              if (!isDriver && (request.houseNumber ?? '').isNotEmpty) _detailField('House No', request.houseNumber!, Icons.numbers_rounded),
              if (!isDriver && (request.address ?? '').isNotEmpty) _detailField('Address', request.address!, Icons.location_on_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailField(String label, String value, IconData icon) {
    return SizedBox(
      width: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppTheme.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: const TextStyle(color: AppTheme.textTertiary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value.isEmpty ? '—' : value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
