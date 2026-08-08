import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/user_repository.dart';

class UserManagementScreen extends StatefulWidget {
  static int adminValidPaymentDays = 30;
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  void _showSettingsDialog() {
    final ctrl = TextEditingController(text: UserManagementScreen.adminValidPaymentDays.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F1B25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.borderColor)),
        title: const Text('Payment Configuration', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Number of valid payment days:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Days', prefixIcon: Icon(Icons.timer_outlined, size: 18)),
            ),
            const SizedBox(height: 12),
            const Text('Users are auto-marked "Overdue" after this many days since last payment.', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppTheme.textTertiary))),
          ElevatedButton(
            onPressed: () {
              setState(() => UserManagementScreen.adminValidPaymentDays = int.tryParse(ctrl.text) ?? 30);
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _updatePayment(UserEntity user, bool isPaid) async {
    final repo = Provider.of<UserRepository>(context, listen: false);
    try {
      await repo.updatePaymentStatus(user.id, isPaid);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated ${user.ownerName}'), backgroundColor: AppTheme.primaryColor, behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<UserRepository>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Registered House Owners', style: Theme.of(context).textTheme.displayLarge),
            OutlinedButton.icon(
              onPressed: _showSettingsDialog,
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Payment Rules'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primaryColor, side: const BorderSide(color: AppTheme.primaryColor), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Expanded(
          child: StreamBuilder<List<UserEntity>>(
            stream: repo.watchAll(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Could not load users: ${snapshot.error}', style: const TextStyle(color: AppTheme.error)));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
              final users = snapshot.data ?? [];
              if (users.isEmpty) return const Center(child: Text('No users found.', style: TextStyle(color: AppTheme.textTertiary)));

              return Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _buildUserRow(users[index]),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: const [
          Expanded(flex: 3, child: _HeaderLabel('RESIDENT')),
          Expanded(flex: 2, child: _HeaderLabel('HOUSE NO')),
          Expanded(flex: 2, child: _HeaderLabel('NIC')),
          Expanded(flex: 2, child: _HeaderLabel('MOBILE')),
          Expanded(flex: 2, child: _HeaderLabel('STATUS')),
          Expanded(flex: 2, child: _HeaderLabel('LAST UPDATED')),
          Expanded(flex: 2, child: _HeaderLabel('ACTION')),
        ],
      ),
    );
  }

  Widget _buildUserRow(UserEntity user) {
    final isPaid = user.isEffectivelyPaid(UserManagementScreen.adminValidPaymentDays);
    final statusColor = isPaid ? AppTheme.success : AppTheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryColor.withOpacity(0.15)),
                  child: const Icon(Icons.person_rounded, color: AppTheme.primaryColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(user.ownerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(user.houseNumber, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Expanded(flex: 2, child: Text(user.nic, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Expanded(flex: 2, child: Text(user.mobile, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor)),
                    const SizedBox(width: 6),
                    Text(isPaid ? 'PAID' : 'OVERDUE', style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(flex: 2, child: Text(user.lastPaymentUpdateDate != null ? DateFormat('MMM dd, yyyy').format(user.lastPaymentUpdateDate!) : 'Never', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12))),
          Expanded(
            flex: 2,
            child: Theme(
              data: Theme.of(context).copyWith(canvasColor: const Color(0xFF0F1B25)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<bool>(
                  value: user.isPaidManually,
                  icon: const Icon(Icons.expand_more, color: AppTheme.primaryColor, size: 18),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: [
                    DropdownMenuItem(value: true, child: Text('Mark Paid', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold))),
                    DropdownMenuItem(value: false, child: Text('Mark Unpaid', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.bold))),
                  ],
                  onChanged: (val) { if (val != null) _updatePayment(user, val); },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  final String text;
  const _HeaderLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2));
}
