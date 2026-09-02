import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/admin_search_field.dart';
import '../../../../core/widgets/admin_table.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';

enum _PaymentFilter { all, paid, overdue }

class UserManagementScreen extends StatefulWidget {
  static int adminValidPaymentDays = 30;

  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _query = '';
  _PaymentFilter _filter = _PaymentFilter.all;

  /// Ids currently being written to Firestore, so their row can show progress.
  final Set<String> _updating = {};

  Future<void> _showSettingsDialog() async {
    final controller = TextEditingController(
      text: UserManagementScreen.adminValidPaymentDays.toString(),
    );

    final days = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Payment Rules',
        subtitle: 'Owners are marked Overdue once this many days have passed '
            'since their last recorded payment.',
        icon: Icons.tune_rounded,
        width: 400,
        actions: [
          AppDialogCancelButton(onPressed: () => Navigator.pop(dialogContext)),
          AppDialogActionButton(
            label: 'Apply',
            onPressed: () => Navigator.pop(dialogContext, int.tryParse(controller.text)),
          ),
        ],
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: AppTheme.primaryColor,
          onSubmitted: (value) => Navigator.pop(dialogContext, int.tryParse(value)),
          decoration: const InputDecoration(
            labelText: 'Valid payment days',
            prefixIcon: Icon(Icons.timer_outlined, size: 18, color: AppTheme.textTertiary),
          ),
        ),
      ),
    );

    if (days != null && days > 0 && mounted) {
      setState(() => UserManagementScreen.adminValidPaymentDays = days);
    }
  }

  Future<void> _updatePayment(UserEntity user, bool isPaid) async {
    if (_updating.contains(user.id)) return;

    final repo = Provider.of<UserRepository>(context, listen: false);
    setState(() => _updating.add(user.id));
    try {
      await repo.updatePaymentStatus(user.id, isPaid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${user.ownerName} marked ${isPaid ? 'paid' : 'unpaid'}'),
        backgroundColor: isPaid ? AppTheme.success : AppTheme.textTertiary,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not update: $error'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _updating.remove(user.id));
    }
  }

  List<UserEntity> _visibleUsers(List<UserEntity> users) {
    final query = _query.trim().toLowerCase();
    final validDays = UserManagementScreen.adminValidPaymentDays;

    return users.where((user) {
      final isPaid = user.isEffectivelyPaid(validDays);
      switch (_filter) {
        case _PaymentFilter.paid:
          if (!isPaid) return false;
        case _PaymentFilter.overdue:
          if (isPaid) return false;
        case _PaymentFilter.all:
          break;
      }
      if (query.isEmpty) return true;
      return user.ownerName.toLowerCase().contains(query) ||
          user.houseNumber.toLowerCase().contains(query) ||
          user.nic.toLowerCase().contains(query) ||
          user.mobile.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<UserRepository>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Registered House Owners',
          subtitle: 'Approved residents from the BinGo app, with their collection payment standing.',
          actions: [
            SecondaryActionButton(
              label: 'Payment Rules',
              icon: Icons.tune_rounded,
              onPressed: _showSettingsDialog,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<List<UserEntity>>(
            stream: repo.watchAll(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorStateView(
                  title: 'Could not load registered owners',
                  error: snapshot.error!,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const TableSkeleton(columnFlexes: [3, 2, 2, 2, 2, 2, 2]);
              }

              final users = snapshot.data ?? const <UserEntity>[];
              if (users.isEmpty) {
                return const EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No registered owners yet',
                  message: 'House owners appear here once they register in the '
                      'BinGo app and you approve them under Registration Requests.',
                );
              }

              final validDays = UserManagementScreen.adminValidPaymentDays;
              final paidCount = users.where((u) => u.isEffectivelyPaid(validDays)).length;
              final visible = _visibleUsers(users);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TableToolbar(
                    leading: [
                      AdminSearchField(
                        hintText: 'Search name, house no, NIC or mobile…',
                        width: 340,
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      FilterSegments<_PaymentFilter>(
                        selected: _filter,
                        onSelected: (value) => setState(() => _filter = value),
                        options: [
                          FilterOption(
                            value: _PaymentFilter.all,
                            label: 'All',
                            count: users.length,
                          ),
                          FilterOption(
                            value: _PaymentFilter.paid,
                            label: 'Paid',
                            count: paidCount,
                            color: AppTheme.success,
                          ),
                          FilterOption(
                            value: _PaymentFilter.overdue,
                            label: 'Overdue',
                            count: users.length - paidCount,
                            color: AppTheme.error,
                          ),
                        ],
                      ),
                    ],
                    trailing: [
                      StatChip(
                        label: 'Owners',
                        value: '${users.length}',
                        icon: Icons.home_outlined,
                      ),
                      StatChip(
                        label: 'Paid',
                        value: '$paidCount',
                        icon: Icons.verified_outlined,
                        color: AppTheme.success,
                      ),
                      StatChip(
                        label: 'Overdue',
                        value: '${users.length - paidCount}',
                        icon: Icons.report_gmailerrorred_rounded,
                        color: AppTheme.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: visible.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No owners match your filters',
                            message: _query.isEmpty
                                ? 'Try a different payment status.'
                                : 'Nothing matched "$_query". Check the spelling or clear the search.',
                          )
                        : _buildTable(visible, validDays),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<UserEntity> users, int validDays) {
    return AdminTable<UserEntity>(
      items: users,
      itemLabel: 'owners',
      minWidth: 1120,
      rowKey: (user) => user.id,
      initialSortColumn: 0,
      columns: [
        AdminColumn(
          label: 'Resident',
          flex: 3,
          sortValue: (user) => user.ownerName.toLowerCase(),
          cell: (context, user) => Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withOpacity(0.14),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.25)),
                ),
                child: Center(
                  child: Text(
                    user.ownerName.isNotEmpty ? user.ownerName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user.ownerName.isEmpty ? '(no name)' : user.ownerName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        AdminColumn(
          label: 'House No',
          sortValue: (user) => user.houseNumber.toLowerCase(),
          cell: (context, user) => _MonoCell(user.houseNumber),
        ),
        AdminColumn(
          label: 'NIC',
          sortValue: (user) => user.nic.toLowerCase(),
          cell: (context, user) => _MonoCell(user.nic),
        ),
        AdminColumn(
          label: 'Mobile',
          cell: (context, user) => _MonoCell(user.mobile),
        ),
        AdminColumn(
          label: 'Status',
          sortValue: (user) => user.isEffectivelyPaid(validDays) ? 0 : 1,
          cell: (context, user) {
            final isPaid = user.isEffectivelyPaid(validDays);
            return StatusPill(
              label: isPaid ? 'PAID' : 'OVERDUE',
              color: isPaid ? AppTheme.success : AppTheme.error,
            );
          },
        ),
        AdminColumn(
          label: 'Last Updated',
          sortValue: (user) => user.lastPaymentUpdateDate?.millisecondsSinceEpoch,
          cell: (context, user) => Text(
            user.lastPaymentUpdateDate == null
                ? 'Never'
                : DateFormat('MMM dd, yyyy').format(user.lastPaymentUpdateDate!),
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12.5),
          ),
        ),
        AdminColumn(
          label: 'Payment',
          flex: 3,
          cell: (context, user) => _PaymentToggle(
            isPaid: user.isPaidManually,
            isBusy: _updating.contains(user.id),
            onChanged: (value) => _updatePayment(user, value),
          ),
        ),
      ],
    );
  }
}

class _MonoCell extends StatelessWidget {
  const _MonoCell(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value.isEmpty ? '—' : value,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
    );
  }
}

/// Two-state paid/unpaid switch — one tap instead of opening a dropdown,
/// with the pending write shown in place.
class _PaymentToggle extends StatelessWidget {
  const _PaymentToggle({
    required this.isPaid,
    required this.isBusy,
    required this.onChanged,
  });

  final bool isPaid;
  final bool isBusy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      return Row(
        children: const [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
          ),
          SizedBox(width: 10),
          Text('Saving…', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12.5)),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleHalf(
            label: 'Paid',
            icon: Icons.check_rounded,
            color: AppTheme.success,
            isActive: isPaid,
            onTap: isPaid ? null : () => onChanged(true),
          ),
          const SizedBox(width: 3),
          _ToggleHalf(
            label: 'Unpaid',
            icon: Icons.close_rounded,
            color: AppTheme.error,
            isActive: !isPaid,
            onTap: !isPaid ? null : () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleHalf extends StatelessWidget {
  const _ToggleHalf({
    required this.label,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? color.withOpacity(0.45) : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isActive ? color : AppTheme.textTertiary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : AppTheme.textTertiary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
