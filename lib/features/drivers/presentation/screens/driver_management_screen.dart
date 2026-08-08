import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/driver_entity.dart';
import '../../domain/repositories/driver_repository.dart';

class DriverManagementScreen extends StatefulWidget {
  const DriverManagementScreen({super.key});

  @override
  State<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen> {
  void _showAddDriverDialog() {
    final formKey = GlobalKey<FormState>();
    final nicController = TextEditingController();
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final emailController = TextEditingController();
    final ageController = TextEditingController();
    DateTime licenseRenewed = DateTime.now();
    DateTime workStarted = DateTime.now();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F1B25),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.borderColor)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Register Driver', style: TextStyle(color: Colors.white, fontSize: 20)),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 450,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        _buildField('Full Name', nameController, Icons.person_outline_rounded),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildField('NIC', nicController, Icons.badge_outlined)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildField('Age', ageController, Icons.cake_outlined, isNumeric: true)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildField('Mobile', mobileController, Icons.phone_android_outlined),
                        const SizedBox(height: 16),
                        _buildField('Login Email', emailController, Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress),
                        const SizedBox(height: 20),
                        _buildDatePicker('License Renewed', licenseRenewed, (d) => setStateDialog(() => licenseRenewed = d)),
                        const SizedBox(height: 12),
                        _buildDatePicker('Service Started', workStarted, (d) => setStateDialog(() => workStarted = d)),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppTheme.textTertiary))),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    if (formKey.currentState!.validate()) {
                      setStateDialog(() => isLoading = true);
                      try {
                        final repo = Provider.of<DriverRepository>(context, listen: false);
                        await repo.addDriver(DriverEntity(
                          id: '', nic: nicController.text, name: nameController.text,
                          mobile: mobileController.text, email: emailController.text.trim(),
                          age: int.tryParse(ageController.text) ?? 0,
                          lastLicenseRenewed: licenseRenewed, workStartedDate: workStarted,
                        ));
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Driver registered!'), backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating));
                        }
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
                      } finally {
                        if (mounted) setStateDialog(() => isLoading = false);
                      }
                    }
                  },
                  child: isLoading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Register'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, {bool isNumeric = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType ?? (isNumeric ? TextInputType.number : TextInputType.text),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18, color: AppTheme.textTertiary)),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildDatePicker(String label, DateTime date, Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (d != null) onPick(d);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderColor)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                const SizedBox(height: 2),
                Text(DateFormat('yyyy-MM-dd').format(date), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<DriverRepository>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Driver Fleet', style: Theme.of(context).textTheme.displayLarge),
            ElevatedButton.icon(
              onPressed: _showAddDriverDialog,
              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
              label: const Text('Add Driver'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
            )
          ],
        ),
        const SizedBox(height: 32),
        Expanded(
          child: StreamBuilder<List<DriverEntity>>(
            stream: repo.watchAll(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
              final drivers = snapshot.data ?? [];
              if (drivers.isEmpty) return const Center(child: Text('No drivers found.', style: TextStyle(color: AppTheme.textTertiary)));

              return Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: drivers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _buildDriverRow(drivers[index]),
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
          Expanded(flex: 3, child: _HeaderLabel('DRIVER')),
          Expanded(flex: 2, child: _HeaderLabel('NIC')),
          Expanded(flex: 2, child: _HeaderLabel('MOBILE')),
          Expanded(flex: 2, child: _HeaderLabel('LOGIN EMAIL')),
          Expanded(flex: 1, child: _HeaderLabel('AGE')),
          Expanded(flex: 2, child: _HeaderLabel('LICENSE DATE')),
          Expanded(flex: 2, child: _HeaderLabel('JOINED')),
        ],
      ),
    );
  }

  Widget _buildDriverRow(DriverEntity driver) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderColor)),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.primaryGradient),
                  child: Center(child: Text(driver.name.isNotEmpty ? driver.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                ),
                const SizedBox(width: 12),
                Text(driver.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(driver.nic, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Expanded(flex: 2, child: Text(driver.mobile, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Expanded(flex: 2, child: Text(driver.email, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 1, child: Text(driver.age.toString(), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
          Expanded(flex: 2, child: Text(DateFormat('MMM dd, yyyy').format(driver.lastLicenseRenewed), style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13))),
          Expanded(flex: 2, child: Text(DateFormat('MMM dd, yyyy').format(driver.workStartedDate), style: const TextStyle(color: AppTheme.textTertiary, fontSize: 13))),
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
