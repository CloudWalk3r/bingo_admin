import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/admin_search_field.dart';
import '../../../../core/widgets/admin_table.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../drivers/domain/entities/driver_entity.dart';
import '../../../drivers/domain/repositories/driver_repository.dart';
import '../../domain/entities/request_entity.dart';
import '../../domain/repositories/request_repository.dart';
import '../widgets/add_request_dialog.dart';

/// Presentation metadata for the request statuses and garbage types, kept in
/// one place so the table, the filters and the dialogs stay in agreement.
class RequestVisuals {
  const RequestVisuals._();

  static Color statusColor(RequestStatus status) => switch (status) {
        RequestStatus.pending => AppTheme.warning,
        RequestStatus.assigned => AppTheme.info,
        RequestStatus.collected => AppTheme.success,
        RequestStatus.rejected => AppTheme.error,
      };

  static IconData statusIcon(RequestStatus status) => switch (status) {
        RequestStatus.pending => Icons.schedule_rounded,
        RequestStatus.assigned => Icons.local_shipping_rounded,
        RequestStatus.collected => Icons.check_circle_rounded,
        RequestStatus.rejected => Icons.block_rounded,
      };

  static String statusLabel(RequestStatus status) => switch (status) {
        RequestStatus.pending => 'Pending',
        RequestStatus.assigned => 'Assigned',
        RequestStatus.collected => 'Collected',
        RequestStatus.rejected => 'Rejected',
      };

  static Color garbageColor(GarbageType type) => switch (type) {
        GarbageType.biodegradable => Colors.greenAccent,
        GarbageType.nonBiodegradable => Colors.orangeAccent,
        GarbageType.glass => Colors.lightBlueAccent,
      };

  static IconData garbageIcon(GarbageType type) => switch (type) {
        GarbageType.biodegradable => Icons.eco_rounded,
        GarbageType.nonBiodegradable => Icons.delete_outline_rounded,
        GarbageType.glass => Icons.wine_bar_rounded,
      };

  static String garbageLabel(GarbageType type) => switch (type) {
        GarbageType.biodegradable => 'Biodegradable',
        GarbageType.nonBiodegradable => 'Non-biodegradable',
        GarbageType.glass => 'Glass',
      };
}

class UserRequestsScreen extends StatefulWidget {
  const UserRequestsScreen({super.key});

  @override
  State<UserRequestsScreen> createState() => _UserRequestsScreenState();
}

class _UserRequestsScreenState extends State<UserRequestsScreen> {
  DateTime _selectedDate = DateTime.now();
  String _query = '';
  RequestStatus? _statusFilter;

  /// Requests with a status write in flight.
  final Set<String> _updating = {};

  Future<void> _showAddRequestDialog() async {
    final requestDate = await showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddRequestDialog(initialDate: _selectedDate),
    );
    if (requestDate != null && mounted) {
      setState(() => _selectedDate = requestDate);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  void _shiftDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
  }

  Future<void> _updateStatus(RequestEntity request, RequestStatus status) async {
    if (_updating.contains(request.id)) return;

    final repo = Provider.of<RequestRepository>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _updating.add(request.id));

    try {
      await repo.updateStatus(request.id, status);
      messenger.showSnackBar(SnackBar(
        content: Text('${request.userName} marked ${RequestVisuals.statusLabel(status).toLowerCase()}'),
        backgroundColor: RequestVisuals.statusColor(status),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      messenger.showSnackBar(SnackBar(
        content: Text('Could not update: $error'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _updating.remove(request.id));
    }
  }

  void _showAssignDriverDialog(RequestEntity request) {
    showDialog(
      context: context,
      builder: (_) => _AssignDriverDialog(request: request),
    );
  }

  List<RequestEntity> _visibleRequests(List<RequestEntity> requests) {
    final query = _query.trim().toLowerCase();

    return requests.where((request) {
      if (_statusFilter != null && request.status != _statusFilter) return false;
      if (query.isEmpty) return true;
      return request.userName.toLowerCase().contains(query) ||
          request.userAddress.toLowerCase().contains(query) ||
          request.userMobile.toLowerCase().contains(query) ||
          (request.assignedDriverName ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<RequestRepository>(context);
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Collection Requests',
          subtitle: 'Pickups scheduled for '
              '${isToday ? 'today' : DateFormat('EEEE, MMM dd, yyyy').format(_selectedDate)}.',
          actions: [
            _DateStepper(
              date: _selectedDate,
              onPrevious: () => _shiftDate(-1),
              onNext: () => _shiftDate(1),
              onTap: _pickDate,
              onToday: isToday ? null : () => setState(() => _selectedDate = DateTime.now()),
            ),
            ElevatedButton.icon(
              onPressed: _showAddRequestDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Request'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<List<RequestEntity>>(
            stream: repo.watchByDate(_selectedDate),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorStateView(
                  title: 'Could not load collection requests',
                  error: snapshot.error!,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const TableSkeleton(columnFlexes: [3, 2, 1, 2, 2, 3]);
              }

              final requests = snapshot.data ?? const <RequestEntity>[];
              if (requests.isEmpty) {
                return EmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'No requests for this day',
                  message: 'Nothing is scheduled for '
                      '${DateFormat('MMM dd, yyyy').format(_selectedDate)}. '
                      'Pick another date or log a request yourself.',
                  action: ElevatedButton.icon(
                    onPressed: _showAddRequestDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Request'),
                  ),
                );
              }

              final visible = _visibleRequests(requests);
              final totalKg = requests.fold<double>(0, (sum, r) => sum + r.weightInKg);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TableToolbar(
                    leading: [
                      AdminSearchField(
                        hintText: 'Search resident, address or driver…',
                        width: 320,
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      FilterSegments<RequestStatus?>(
                        selected: _statusFilter,
                        onSelected: (value) => setState(() => _statusFilter = value),
                        options: [
                          FilterOption(value: null, label: 'All', count: requests.length),
                          for (final status in RequestStatus.values)
                            FilterOption(
                              value: status,
                              label: RequestVisuals.statusLabel(status),
                              count: requests.where((r) => r.status == status).length,
                              color: RequestVisuals.statusColor(status),
                            ),
                        ],
                      ),
                    ],
                    trailing: [
                      StatChip(
                        label: 'Requests',
                        value: '${requests.length}',
                        icon: Icons.assignment_outlined,
                      ),
                      StatChip(
                        label: 'Total weight',
                        value: '${totalKg.toStringAsFixed(1)} kg',
                        icon: Icons.scale_outlined,
                        color: AppTheme.accentColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: visible.isEmpty
                        ? const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No requests match your filters',
                            message: 'Try a different status or clear the search.',
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

  Widget _buildTable(List<RequestEntity> requests) {
    return AdminTable<RequestEntity>(
      items: requests,
      itemLabel: 'requests',
      minWidth: 1180,
      rowKey: (request) => request.id,
      initialSortColumn: 2,
      columns: [
        AdminColumn(
          label: 'Resident',
          flex: 3,
          sortValue: (request) => request.userName.toLowerCase(),
          cell: (context, request) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                request.userName.isEmpty ? '(no name)' : request.userName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                request.userAddress.isEmpty ? '—' : request.userAddress,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        AdminColumn(
          label: 'Garbage Type',
          sortValue: (request) => request.garbageType.index,
          cell: (context, request) {
            final color = RequestVisuals.garbageColor(request.garbageType);
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(RequestVisuals.garbageIcon(request.garbageType), color: color, size: 15),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    RequestVisuals.garbageLabel(request.garbageType),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ),
              ],
            );
          },
        ),
        AdminColumn(
          label: 'Weight',
          flex: 1,
          numeric: true,
          sortValue: (request) => request.weightInKg,
          cell: (context, request) => Text(
            request.weightInKg > 0 ? '${request.weightInKg.toStringAsFixed(1)} kg' : '—',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        AdminColumn(
          label: 'Time',
          flex: 1,
          sortValue: (request) => request.requestedDateTime.millisecondsSinceEpoch,
          cell: (context, request) => Text(
            DateFormat('HH:mm').format(request.requestedDateTime),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        AdminColumn(
          label: 'Status',
          sortValue: (request) => request.status.index,
          cell: (context, request) => StatusPill(
            label: RequestVisuals.statusLabel(request.status).toUpperCase(),
            color: RequestVisuals.statusColor(request.status),
            icon: RequestVisuals.statusIcon(request.status),
          ),
        ),
        AdminColumn(
          label: 'Driver',
          sortValue: (request) => (request.assignedDriverName ?? '').toLowerCase(),
          cell: (context, request) => _DriverCell(
            request: request,
            onAssign: () => _showAssignDriverDialog(request),
          ),
        ),
        AdminColumn(
          label: 'Set Status',
          flex: 2,
          cell: (context, request) => _StatusSelector(
            status: request.status,
            isBusy: _updating.contains(request.id),
            onChanged: (status) => _updateStatus(request, status),
          ),
        ),
      ],
    );
  }
}

/// Date control in the page header: step a day at a time, jump back to today,
/// or open the calendar.
class _DateStepper extends StatelessWidget {
  const _DateStepper({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onTap,
    this.onToday,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTap;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            color: AppTheme.primaryColor,
            tooltip: 'Previous day',
            splashRadius: 18,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
          ),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
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
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            color: AppTheme.primaryColor,
            tooltip: 'Next day',
            splashRadius: 18,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
          ),
          if (onToday != null)
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 4),
              child: InkWell(
                onTap: onToday,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Today',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DriverCell extends StatelessWidget {
  const _DriverCell({required this.request, required this.onAssign});

  final RequestEntity request;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final canAssign = request.status == RequestStatus.pending ||
        request.status == RequestStatus.assigned;

    if (request.assignedDriverId == null) {
      if (!canAssign) {
        return const Text('—', style: TextStyle(color: AppTheme.textTertiary));
      }
      return InkWell(
        onTap: onAssign,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.person_add_alt_1_rounded, size: 13, color: AppTheme.primaryColor),
              SizedBox(width: 6),
              Text(
                'Assign',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Tooltip(
      message: canAssign ? 'Tap to reassign' : 'Assigned driver',
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        onTap: canAssign ? onAssign : null,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.local_shipping_rounded, color: AppTheme.info, size: 15),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  request.assignedDriverName ?? 'Driver',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({
    required this.status,
    required this.isBusy,
    required this.onChanged,
  });

  final RequestStatus status;
  final bool isBusy;
  final ValueChanged<RequestStatus> onChanged;

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

    return Theme(
      data: Theme.of(context).copyWith(canvasColor: AppDialog.surface),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<RequestStatus>(
            value: status,
            isDense: true,
            isExpanded: true,
            borderRadius: BorderRadius.circular(12),
            icon: const Icon(Icons.expand_more_rounded, color: AppTheme.primaryColor, size: 17),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: RequestStatus.values.map((value) {
              final color = RequestVisuals.statusColor(value);
              return DropdownMenuItem(
                value: value,
                child: Row(
                  children: [
                    Icon(RequestVisuals.statusIcon(value), size: 14, color: color),
                    const SizedBox(width: 8),
                    Text(
                      RequestVisuals.statusLabel(value),
                      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null && value != status) onChanged(value);
            },
          ),
        ),
      ),
    );
  }
}

class _AssignDriverDialog extends StatefulWidget {
  const _AssignDriverDialog({required this.request});

  final RequestEntity request;

  @override
  State<_AssignDriverDialog> createState() => _AssignDriverDialogState();
}

class _AssignDriverDialogState extends State<_AssignDriverDialog> {
  String _query = '';
  String? _assigningDriverId;

  Future<void> _assign(DriverEntity driver) async {
    if (_assigningDriverId != null) return;

    final repo = Provider.of<RequestRepository>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _assigningDriverId = driver.id);

    try {
      await repo.assignDriver(widget.request.id, driver);
      navigator.pop();
      messenger.showSnackBar(SnackBar(
        content: Text('${driver.name} assigned to this pickup'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() => _assigningDriverId = null);
      messenger.showSnackBar(SnackBar(
        content: Text('Could not assign: $error'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final driverRepo = Provider.of<DriverRepository>(context, listen: false);

    return AppDialog(
      title: 'Assign Driver',
      subtitle: '${widget.request.userName} • '
          '${widget.request.userAddress.isEmpty ? 'no address' : widget.request.userAddress}',
      icon: Icons.local_shipping_rounded,
      width: 440,
      actions: [
        AppDialogCancelButton(label: 'Close', onPressed: () => Navigator.pop(context)),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminSearchField(
            hintText: 'Search drivers…',
            width: double.infinity,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: StreamBuilder<List<DriverEntity>>(
              stream: driverRepo.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryColor),
                  );
                }

                final all = snapshot.data ?? const <DriverEntity>[];
                if (all.isEmpty) {
                  return const EmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'No drivers yet',
                    message: 'Register a driver before assigning pickups.',
                  );
                }

                final query = _query.trim().toLowerCase();
                final drivers = query.isEmpty
                    ? all
                    : all
                        .where((driver) =>
                            driver.name.toLowerCase().contains(query) ||
                            driver.mobile.toLowerCase().contains(query))
                        .toList();

                if (drivers.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching drivers',
                  );
                }

                return ListView.separated(
                  itemCount: drivers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final driver = drivers[index];
                    final isAssigned = widget.request.assignedDriverId == driver.id;
                    final isAssigning = _assigningDriverId == driver.id;

                    return InkWell(
                      onTap: isAssigned || _assigningDriverId != null
                          ? null
                          : () => _assign(driver),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: isAssigned
                              ? AppTheme.primaryColor.withOpacity(0.12)
                              : Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isAssigned
                                ? AppTheme.primaryColor.withOpacity(0.5)
                                : AppTheme.borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
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
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driver.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  Text(
                                    driver.mobile,
                                    style: const TextStyle(
                                      color: AppTheme.textTertiary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isAssigning)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryColor,
                                ),
                              )
                            else if (isAssigned)
                              const StatusPill(
                                label: 'ASSIGNED',
                                color: AppTheme.primaryColor,
                                compact: true,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
