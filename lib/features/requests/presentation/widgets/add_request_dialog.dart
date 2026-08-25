import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../drivers/domain/entities/driver_entity.dart';
import '../../../drivers/domain/repositories/driver_repository.dart';
import '../../domain/entities/request_entity.dart';
import '../../domain/repositories/request_repository.dart';

class AddRequestDialog extends StatefulWidget {
  final DateTime initialDate;

  const AddRequestDialog({super.key, required this.initialDate});

  @override
  State<AddRequestDialog> createState() => _AddRequestDialogState();
}

class _AddRequestDialogState extends State<AddRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _weightController = TextEditingController();

  late DateTime _pickupDateTime;
  GarbageType _garbageType = GarbageType.biodegradable;
  DriverEntity? _selectedDriver;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _pickupDateTime = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
      now.hour,
      now.minute,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _pickupDateTime,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      setState(() {
        _pickupDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          _pickupDateTime.hour,
          _pickupDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_pickupDateTime),
    );
    if (time != null && mounted) {
      setState(() {
        _pickupDateTime = DateTime(
          _pickupDateTime.year,
          _pickupDateTime.month,
          _pickupDateTime.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final driver = _selectedDriver;
    final request = RequestEntity(
      id: '',
      userName: _nameController.text.trim(),
      userMobile: _mobileController.text.trim(),
      userAddress: _addressController.text.trim(),
      userEmail: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      requestedDateTime: _pickupDateTime,
      garbageType: _garbageType,
      weightInKg: double.tryParse(_weightController.text.trim()) ?? 0,
      status: driver == null ? RequestStatus.pending : RequestStatus.assigned,
      assignedDriverId: driver?.id,
      assignedDriverName: driver?.name,
      assignedDriverMobile: driver?.mobile,
      assignedAt: driver == null ? null : DateTime.now(),
    );

    try {
      final messenger = ScaffoldMessenger.of(context);
      await context.read<RequestRepository>().addRequest(request);
      if (!mounted) return;
      Navigator.pop(context, _pickupDateTime);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            driver == null
                ? 'Request created successfully'
                : 'Request created and assigned to ${driver.name}',
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create request: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0F1B25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.borderColor),
      ),
      title: const Row(
        children: [
          Icon(Icons.add_task_rounded, color: AppTheme.primaryColor),
          SizedBox(width: 12),
          Text(
            'Add Collection Request',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        label: 'House owner name',
                        controller: _nameController,
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _field(
                        label: 'Mobile number',
                        controller: _mobileController,
                        icon: Icons.call_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _field(
                  label: 'Pickup address',
                  controller: _addressController,
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 14),
                _field(
                  label: 'Email (optional)',
                  controller: _emailController,
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  required: false,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<GarbageType>(
                        initialValue: _garbageType,
                        dropdownColor: const Color(0xFF0F1B25),
                        decoration: const InputDecoration(
                          labelText: 'Garbage type',
                          prefixIcon: Icon(Icons.recycling_rounded, size: 18),
                        ),
                        items: GarbageType.values
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(_garbageLabel(type)),
                              ),
                            )
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (value) => setState(
                                () => _garbageType = value ?? _garbageType,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _field(
                        label: 'Estimated weight (kg)',
                        controller: _weightController,
                        icon: Icons.scale_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        required: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _selectDate,
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                        label: Text(
                          DateFormat('MMM dd, yyyy').format(_pickupDateTime),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSaving ? null : _selectTime,
                        icon: const Icon(Icons.schedule_outlined, size: 16),
                        label: Text(
                          DateFormat('hh:mm a').format(_pickupDateTime),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                StreamBuilder<List<DriverEntity>>(
                  stream: context.read<DriverRepository>().watchAll(),
                  builder: (context, snapshot) {
                    final drivers = snapshot.data ?? [];
                    return DropdownButtonFormField<DriverEntity>(
                      initialValue: _selectedDriver,
                      dropdownColor: const Color(0xFF0F1B25),
                      decoration: const InputDecoration(
                        labelText: 'Assign driver (optional)',
                        prefixIcon: Icon(
                          Icons.local_shipping_outlined,
                          size: 18,
                        ),
                      ),
                      items: drivers
                          .map(
                            (driver) => DropdownMenuItem(
                              value: driver,
                              child: Text('${driver.name} • ${driver.mobile}'),
                            ),
                          )
                          .toList(),
                      onChanged: _isSaving
                          ? null
                          : (driver) =>
                                setState(() => _selectedDriver = driver),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _submit,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.add_rounded, size: 18),
          label: Text(_isSaving ? 'Creating...' : 'Create Request'),
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: !_isSaving,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
      ),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? '$label is required'
                : null
          : null,
    );
  }

  String _garbageLabel(GarbageType type) {
    switch (type) {
      case GarbageType.biodegradable:
        return 'Biodegradable';
      case GarbageType.nonBiodegradable:
        return 'Non-biodegradable';
      case GarbageType.glass:
        return 'Glass';
    }
  }
}
