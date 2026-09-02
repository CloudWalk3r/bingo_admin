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
import '../../domain/entities/driver_entity.dart';
import '../../domain/repositories/driver_repository.dart';

class DriverManagementScreen extends StatefulWidget {
  const DriverManagementScreen({super.key});

  @override
  State<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends State<DriverManagementScreen> {
  String _query = '';

  void _showAddDriverDialog() {
    showDialog(context: context, builder: (_) => const _AddDriverDialog());
  }

  List<DriverEntity> _visibleDrivers(List<DriverEntity> drivers) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return drivers;
    return drivers
        .where((driver) =>
            driver.name.toLowerCase().contains(query) ||
            driver.nic.toLowerCase().contains(query) ||
            driver.mobile.toLowerCase().contains(query) ||
            driver.email.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<DriverRepository>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Driver Fleet',
          subtitle: 'Everyone who can be assigned a collection route.',
          actions: [
            ElevatedButton.icon(
              onPressed: _showAddDriverDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
              label: const Text('Add Driver'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<List<DriverEntity>>(
            stream: repo.watchAll(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorStateView(
                  title: 'Could not load the driver fleet',
                  error: snapshot.error!,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const TableSkeleton(columnFlexes: [3, 2, 2, 3, 1, 2, 2]);
              }

              final drivers = snapshot.data ?? const <DriverEntity>[];
              if (drivers.isEmpty) {
                return EmptyState(
                  icon: Icons.local_shipping_outlined,
                  title: 'No drivers registered',
                  message: 'Add a driver here, or approve a driver registration '
                      'from the Registration Requests screen.',
                  action: ElevatedButton.icon(
                    onPressed: _showAddDriverDialog,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
                    label: const Text('Add Driver'),
                  ),
                );
              }

              final visible = _visibleDrivers(drivers);
              final averageAge = drivers.where((d) => d.age > 0).isEmpty
                  ? 0
                  : drivers.where((d) => d.age > 0).map((d) => d.age).reduce((a, b) => a + b) ~/
                      drivers.where((d) => d.age > 0).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TableToolbar(
                    leading: [
                      AdminSearchField(
                        hintText: 'Search name, NIC, mobile or email…',
                        width: 340,
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ],
                    trailing: [
                      StatChip(
                        label: 'Drivers',
                        value: '${drivers.length}',
                        icon: Icons.local_shipping_outlined,
                      ),
                      if (averageAge > 0)
                        StatChip(
                          label: 'Avg age',
                          value: '$averageAge',
                          icon: Icons.cake_outlined,
                          color: AppTheme.accentColor,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: visible.isEmpty
                        ? EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No drivers match your search',
                            message: 'Nothing matched "$_query".',
                          )
                        : _buildTable(visible),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<DriverEntity> drivers) {
    return AdminTable<DriverEntity>(
      items: drivers,
      itemLabel: 'drivers',
      minWidth: 1100,
      rowKey: (driver) => driver.id,
      initialSortColumn: 0,
      columns: [
        AdminColumn(
          label: 'Driver',
          flex: 3,
          sortValue: (driver) => driver.name.toLowerCase(),
          cell: (context, driver) => Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                ),
                child: Center(
                  child: Text(
                    driver.name.isNotEmpty ? driver.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  driver.name.isEmpty ? '(no name)' : driver.name,
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
          label: 'NIC',
          sortValue: (driver) => driver.nic.toLowerCase(),
          cell: (context, driver) => _PlainCell(driver.nic),
        ),
        AdminColumn(
          label: 'Mobile',
          cell: (context, driver) => _PlainCell(driver.mobile),
        ),
        AdminColumn(
          label: 'Login Email',
          flex: 3,
          sortValue: (driver) => driver.email.toLowerCase(),
          cell: (context, driver) => Tooltip(
            message: driver.email.isEmpty ? 'No login email' : driver.email,
            waitDuration: const Duration(milliseconds: 600),
            child: _PlainCell(driver.email),
          ),
        ),
        AdminColumn(
          label: 'Age',
          flex: 1,
          numeric: true,
          sortValue: (driver) => driver.age,
          cell: (context, driver) => Text(
            driver.age > 0 ? '${driver.age}' : '—',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        AdminColumn(
          label: 'License Renewed',
          sortValue: (driver) => driver.lastLicenseRenewed.millisecondsSinceEpoch,
          cell: (context, driver) => _DateCell(driver.lastLicenseRenewed),
        ),
        AdminColumn(
          label: 'Joined',
          sortValue: (driver) => driver.workStartedDate.millisecondsSinceEpoch,
          cell: (context, driver) => _DateCell(driver.workStartedDate),
        ),
      ],
    );
  }
}

class _PlainCell extends StatelessWidget {
  const _PlainCell(this.value);

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

class _DateCell extends StatelessWidget {
  const _DateCell(this.date);

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Text(
      DateFormat('MMM dd, yyyy').format(date),
      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12.5),
    );
  }
}

class _AddDriverDialog extends StatefulWidget {
  const _AddDriverDialog();

  @override
  State<_AddDriverDialog> createState() => _AddDriverDialogState();
}

class _AddDriverDialogState extends State<_AddDriverDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nicController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();

  DateTime _licenseRenewed = DateTime.now();
  DateTime _workStarted = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nicController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    final repo = Provider.of<DriverRepository>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await repo.addDriver(DriverEntity(
        id: '',
        nic: _nicController.text.trim(),
        name: _nameController.text.trim(),
        mobile: _mobileController.text.trim(),
        email: _emailController.text.trim(),
        age: int.tryParse(_ageController.text) ?? 0,
        lastLicenseRenewed: _licenseRenewed,
        workStartedDate: _workStarted,
      ));
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('${_nameController.text.trim()} added to the fleet'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(SnackBar(
        content: Text('Could not add driver: $error'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Register Driver',
      subtitle: 'They become assignable to collection requests immediately.',
      icon: Icons.person_add_alt_1_rounded,
      width: 460,
      actions: [
        AppDialogCancelButton(onPressed: _isSaving ? null : () => Navigator.pop(context)),
        AppDialogActionButton(
          label: 'Register',
          icon: Icons.person_add_alt_1_rounded,
          isLoading: _isSaving,
          onPressed: _save,
        ),
      ],
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogField(
                label: 'Full Name',
                controller: _nameController,
                icon: Icons.person_outline_rounded,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _DialogField(
                      label: 'NIC',
                      controller: _nicController,
                      icon: Icons.badge_outlined,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _DialogField(
                      label: 'Age',
                      controller: _ageController,
                      icon: Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final age = int.tryParse((value ?? '').trim());
                        if (age == null) return 'Number';
                        if (age < 18 || age > 80) return '18–80';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DialogField(
                label: 'Mobile',
                controller: _mobileController,
                icon: Icons.phone_android_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _DialogField(
                label: 'Login Email',
                controller: _emailController,
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return 'Required';
                  if (!text.contains('@') || !text.contains('.')) return 'Invalid email';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _DatePickerTile(
                label: 'License last renewed',
                date: _licenseRenewed,
                onPicked: (date) => setState(() => _licenseRenewed = date),
              ),
              const SizedBox(height: 12),
              _DatePickerTile(
                label: 'Service started',
                date: _workStarted,
                onPicked: (date) => setState(() => _workStarted = date),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.validator,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      autofocus: autofocus,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: AppTheme.primaryColor,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
        prefixIcon: Icon(icon, size: 18, color: AppTheme.textTertiary),
        errorStyle: const TextStyle(fontSize: 11),
      ),
      validator: validator ??
          (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.label,
    required this.date,
    required this.onPicked,
  });

  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(1980),
          lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM dd, yyyy').format(date),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar_outlined, size: 15, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}
