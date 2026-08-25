import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/enums.dart';
import '../../domain/entities/request_entity.dart';
import '../../domain/repositories/request_repository.dart';
import '../../../drivers/domain/entities/driver_entity.dart';
import '../../../drivers/domain/repositories/driver_repository.dart';

class UserRequestsScreen extends StatefulWidget {
  const UserRequestsScreen({super.key});

  @override
  State<UserRequestsScreen> createState() => _UserRequestsScreenState();
}

class _UserRequestsScreenState extends State<UserRequestsScreen> {
  DateTime _selectedDate = DateTime.now();

  void _showAssignDriverDialog(RequestEntity request) {
    final driverRepo = Provider.of<DriverRepository>(context, listen: false);
    final requestRepo = Provider.of<RequestRepository>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F1B25),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppTheme.borderColor)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Assign Driver', style: TextStyle(color: Colors.white, fontSize: 20))),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: StreamBuilder<List<DriverEntity>>(
              stream: driverRepo.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)));
                }
                final drivers = snapshot.data ?? [];
                if (drivers.isEmpty) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: Text('No registered drivers yet.', style: TextStyle(color: AppTheme.textTertiary))),
                  );
                }
                return SizedBox(
                  height: 320,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: drivers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final driver = drivers[index];
                      final bool isCurrentlyAssigned = request.assignedDriverId == driver.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          try {
                            await requestRepo.assignDriver(request.id, driver);
                            if (dialogContext.mounted) Navigator.pop(dialogContext);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('${driver.name} assigned to this pickup'),
                                backgroundColor: AppTheme.success,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isCurrentlyAssigned ? AppTheme.primaryColor.withOpacity(0.12) : Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isCurrentlyAssigned ? AppTheme.primaryColor.withOpacity(0.5) : AppTheme.borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.primaryGradient),
                                child: Center(child: Text(driver.name.isNotEmpty ? driver.name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(driver.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text(driver.mobile, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                                  ],
                                ),
                              ),
                              if (isCurrentlyAssigned) const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: AppTheme.textTertiary))),
          ],
        );
      },
    );
  }

  void _updateStatus(RequestEntity request, RequestStatus newStatus) async {
    final repo = Provider.of<RequestRepository>(context, listen: false);
    try {
      await repo.updateStatus(request.id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Marked as ${newStatus.name}'),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  Color _getGarbageColor(GarbageType type) {
    switch (type) {
      case GarbageType.biodegradable: return Colors.greenAccent;
      case GarbageType.nonBiodegradable: return Colors.orangeAccent;
      case GarbageType.glass: return Colors.lightBlueAccent;
    }
  }

  IconData _getGarbageIcon(GarbageType type) {
    switch (type) {
      case GarbageType.biodegradable: return Icons.eco_rounded;
      case GarbageType.nonBiodegradable: return Icons.delete_outline_rounded;
      case GarbageType.glass: return Icons.wine_bar_rounded;
    }
  }

  String _getGarbageLabel(GarbageType type) {
    switch (type) {
      case GarbageType.biodegradable: return 'Biodegradable';
      case GarbageType.nonBiodegradable: return 'Non-biodegradable';
      case GarbageType.glass: return 'Glass';
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<RequestRepository>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Collection Requests', style: Theme.of(context).textTheme.displayLarge),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Request'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                ),
                const SizedBox(width: 12),
                _buildDatePicker(context),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        Expanded(
          child: StreamBuilder<List<RequestEntity>>(
            stream: repo.watchByDate(_selectedDate),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
              final requests = snapshot.data ?? [];
              if (requests.isEmpty) return Center(child: Text('No requests for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}', style: const TextStyle(color: AppTheme.textTertiary)));

              return Column(
                children: [
                  _buildTableHeader(),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: requests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _buildRequestRow(requests[index]),
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

  Widget _buildTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: const [
          Expanded(flex: 3, child: _HeaderLabel('USER')),
          Expanded(flex: 2, child: _HeaderLabel('GARBAGE TYPE')),
          Expanded(flex: 1, child: _HeaderLabel('TIME')),
          Expanded(flex: 2, child: _HeaderLabel('STATUS')),
          Expanded(flex: 2, child: _HeaderLabel('DRIVER')),
          Expanded(flex: 2, child: _HeaderLabel('ACTION')),
        ],
      ),
    );
  }

  Widget _buildRequestRow(RequestEntity request) {
    final gColor = _getGarbageColor(request.garbageType);
    Color statusColor = AppTheme.warning;
    if (request.status == RequestStatus.assigned) statusColor = AppTheme.info;
    if (request.status == RequestStatus.collected) statusColor = AppTheme.success;
    if (request.status == RequestStatus.rejected) statusColor = AppTheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderColor)),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(request.userAddress, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: gColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(_getGarbageIcon(request.garbageType), color: gColor, size: 16)),
                const SizedBox(width: 10),
                Text(_getGarbageLabel(request.garbageType), style: TextStyle(color: gColor, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          Expanded(flex: 1, child: Text(DateFormat('HH:mm').format(request.requestedDateTime), style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withOpacity(0.4))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor)),
                    const SizedBox(width: 6),
                    Text(request.status.name.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(flex: 2, child: _buildDriverCell(request)),
          Expanded(
            flex: 2,
            child: Theme(
              data: Theme.of(context).copyWith(canvasColor: const Color(0xFF0F1B25)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RequestStatus>(
                  value: request.status,
                  icon: const Icon(Icons.expand_more, color: AppTheme.primaryColor, size: 18),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: RequestStatus.values.map((s) {
                    Color c = AppTheme.warning;
                    if (s == RequestStatus.assigned) c = AppTheme.info;
                    if (s == RequestStatus.collected) c = AppTheme.success;
                    if (s == RequestStatus.rejected) c = AppTheme.error;
                    return DropdownMenuItem(value: s, child: Text(s.name.capitalize(), style: TextStyle(color: c, fontWeight: FontWeight.bold)));
                  }).toList(),
                  onChanged: (val) { if (val != null) _updateStatus(request, val); },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCell(RequestEntity request) {
    final bool canAssign = request.status == RequestStatus.pending || request.status == RequestStatus.assigned;
    if (request.assignedDriverId == null) {
      return canAssign
          ? OutlinedButton.icon(
              onPressed: () => _showAssignDriverDialog(request),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
              label: const Text('Assign'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          : const Text('—', style: TextStyle(color: AppTheme.textTertiary));
    }
    return InkWell(
      onTap: canAssign ? () => _showAssignDriverDialog(request) : null,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_shipping_rounded, color: AppTheme.info, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              request.assignedDriverName ?? 'Driver',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (d != null) setState(() => _selectedDate = d);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.borderColor)),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            Text(DateFormat('MMM dd, yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
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

extension StringExtension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
