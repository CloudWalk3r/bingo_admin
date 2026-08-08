import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:biongo_admin/core/theme/app_theme.dart';
import 'package:biongo_admin/core/constants/enums.dart';
import 'package:biongo_admin/features/requests/domain/entities/request_entity.dart';
import 'package:biongo_admin/features/requests/domain/repositories/request_repository.dart';
import 'package:biongo_admin/features/drivers/domain/entities/driver_entity.dart';
import 'package:biongo_admin/features/drivers/domain/repositories/driver_repository.dart';

enum _Period { today, week, month, year, custom }

class _PeriodOption {
  final _Period period;
  final String label;
  const _PeriodOption(this.period, this.label);
}

class _GarbageInfo {
  final GarbageType type;
  final String label;
  final Color color;
  final IconData icon;
  const _GarbageInfo(this.type, this.label, this.color, this.icon);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _Period _period = _Period.today;
  DateTimeRange? _customRange;

  static const _periodOptions = [
    _PeriodOption(_Period.today, 'Today'),
    _PeriodOption(_Period.week, 'This Week'),
    _PeriodOption(_Period.month, 'This Month'),
    _PeriodOption(_Period.year, 'This Year'),
    _PeriodOption(_Period.custom, 'Custom Range'),
  ];

  static const _garbageTypes = [
    _GarbageInfo(GarbageType.biodegradable, 'Biodegradable (දිරණ)', Colors.greenAccent, Icons.eco_rounded),
    _GarbageInfo(GarbageType.nonBiodegradable, 'Non-biodegradable (නොදිරණ)', Colors.orangeAccent, Icons.delete_outline_rounded),
    _GarbageInfo(GarbageType.glass, 'Glass (වීදුරු)', Colors.lightBlueAccent, Icons.wine_bar_rounded),
  ];

  DateTimeRange _getRange() {
    final now = DateTime.now();
    switch (_period) {
      case _Period.today:
        final s = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: s, end: s.add(const Duration(days: 1)));
      case _Period.week:
        final s = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(start: DateTime(s.year, s.month, s.day), end: now);
      case _Period.month:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
      case _Period.year:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
      case _Period.custom:
        return _customRange ?? DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    }
  }

  List<RequestEntity> _filterByRange(List<RequestEntity> all, DateTimeRange range) {
    return all.where((r) =>
      !r.requestedDateTime.isBefore(range.start) &&
      r.requestedDateTime.isBefore(range.end)
    ).toList();
  }

  double _sumKg(List<RequestEntity> list, GarbageType type, {bool collectedOnly = false}) {
    return list
        .where((r) => r.garbageType == type && (!collectedOnly || r.status == RequestStatus.collected))
        .fold(0.0, (sum, r) => sum + r.weightInKg);
  }

  int _countOf(List<RequestEntity> list, GarbageType type, {bool collectedOnly = false}) {
    return list
        .where((r) => r.garbageType == type && (!collectedOnly || r.status == RequestStatus.collected))
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final requestRepo = Provider.of<RequestRepository>(context);
    final driverRepo = Provider.of<DriverRepository>(context);

    return StreamBuilder<List<RequestEntity>>(
      stream: requestRepo.watchAll(),
      builder: (context, requestSnap) {
        return StreamBuilder<List<DriverEntity>>(
          stream: driverRepo.watchAll(),
          builder: (context, driverSnap) {
            final allRequests = requestSnap.data ?? [];
            final allDrivers = driverSnap.data ?? [];
            final now = DateTime.now();

            final todayStart = DateTime(now.year, now.month, now.day);
            final todayAll = allRequests.where((r) =>
              !r.requestedDateTime.isBefore(todayStart) &&
              r.requestedDateTime.isBefore(todayStart.add(const Duration(days: 1)))
            ).toList();
            final todayCollected = todayAll.where((r) => r.status == RequestStatus.collected).length;

            final range = _getRange();
            final periodRequests = _filterByRange(allRequests, range);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Dashboard', style: Theme.of(context).textTheme.displayLarge),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                          boxShadow: [BoxShadow(color: AppTheme.primaryColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: const CircleAvatar(backgroundColor: Colors.transparent, child: Icon(Icons.person, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Top metric cards
                  Wrap(
                    spacing: 20, runSpacing: 20,
                    children: [
                      _MetricCard(title: "Today's Requests", value: todayAll.length.toString(), icon: Icons.assignment_outlined, color: AppTheme.primaryColor),
                      _MetricCard(title: "Today Collected", value: todayCollected.toString(), icon: Icons.check_circle_outline_rounded, color: AppTheme.success),
                      _MetricCard(title: "Total Drivers", value: allDrivers.length.toString(), icon: Icons.local_shipping_outlined, color: AppTheme.info),
                      _MetricCard(title: "All-time Requests", value: allRequests.length.toString(), icon: Icons.list_alt_rounded, color: AppTheme.warning),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Analytics Section
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          runSpacing: 12,
                          children: [
                            const Text('Garbage Analytics', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            Wrap(
                              spacing: 8,
                              children: _periodOptions.map((opt) {
                                final isSelected = _period == opt.period;
                                return GestureDetector(
                                  onTap: () async {
                                    if (opt.period == _Period.custom) {
                                      final picked = await showDateRangePicker(
                                        context: context,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                        initialDateRange: _customRange,
                                        builder: (context, child) => Theme(
                                          data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primaryColor, onPrimary: Colors.white)),
                                          child: child!,
                                        ),
                                      );
                                      if (picked != null) setState(() { _period = _Period.custom; _customRange = picked; });
                                    } else {
                                      setState(() => _period = opt.period);
                                    }
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      gradient: isSelected ? AppTheme.primaryGradient : null,
                                      color: isSelected ? null : Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: isSelected ? Colors.transparent : AppTheme.borderColor),
                                    ),
                                    child: Text(opt.label, style: TextStyle(
                                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    )),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        if (_period == _Period.custom) ...[
                          const SizedBox(height: 16),
                          _buildCustomRangePicker(),
                        ],
                        const SizedBox(height: 24),
                        const Divider(color: AppTheme.borderColor),
                        const SizedBox(height: 16),
                        _buildGarbageStatsTable(periodRequests),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Charts Row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final totalW = constraints.maxWidth;
                      final barW = (totalW * 0.60).clamp(300.0, 700.0);
                      final pieW = (totalW * 0.36).clamp(260.0, 400.0);
                      return Wrap(
                        spacing: 24, runSpacing: 24,
                        crossAxisAlignment: WrapCrossAlignment.start,
                        children: [
                          SizedBox(width: barW, child: _buildBarChart(allRequests)),
                          SizedBox(width: pieW, child: _buildPieChart(allRequests)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomRangePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          initialDateRange: _customRange,
          builder: (context, child) => Theme(
            data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppTheme.primaryColor, onPrimary: Colors.white)),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _customRange = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.date_range_rounded, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            Text(
              _customRange != null
                ? '${DateFormat('MMM dd, yyyy').format(_customRange!.start)}  →  ${DateFormat('MMM dd, yyyy').format(_customRange!.end)}'
                : 'Select date range',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined, size: 14, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildGarbageStatsTable(List<RequestEntity> filtered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: const [
              Expanded(flex: 4, child: _TableHeader('TYPE')),
              Expanded(flex: 2, child: _TableHeader('REQUESTS')),
              Expanded(flex: 2, child: _TableHeader('TOTAL kg')),
              Expanded(flex: 2, child: _TableHeader('COLLECTED')),
              Expanded(flex: 2, child: _TableHeader('COLLECTED kg')),
            ],
          ),
        ),
        ..._garbageTypes.map((info) {
          final reqCount = _countOf(filtered, info.type);
          final reqKg   = _sumKg(filtered, info.type);
          final colCount = _countOf(filtered, info.type, collectedOnly: true);
          final colKg   = _sumKg(filtered, info.type, collectedOnly: true);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: info.color.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: info.color.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: info.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                        child: Icon(info.icon, color: info.color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Flexible(child: Text(info.label, style: TextStyle(color: info.color, fontWeight: FontWeight.bold, fontSize: 13))),
                    ],
                  ),
                ),
                Expanded(flex: 2, child: _StatItem(value: '$reqCount', label: 'requests')),
                Expanded(flex: 2, child: _StatItem(value: '${reqKg.toStringAsFixed(1)} kg', label: 'requested')),
                Expanded(flex: 2, child: _StatItem(value: '$colCount', label: 'collected', color: AppTheme.success)),
                Expanded(flex: 2, child: _StatItem(value: '${colKg.toStringAsFixed(1)} kg', label: 'collected', color: AppTheme.success)),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildBarChart(List<RequestEntity> requests) {
    Map<int, double> bio = {0:0,1:0,2:0,3:0,4:0,5:0,6:0};
    Map<int, double> nonBio = {0:0,1:0,2:0,3:0,4:0,5:0,6:0};
    for (var r in requests) {
      int d = r.requestedDateTime.weekday - 1;
      if (r.garbageType == GarbageType.biodegradable) bio[d] = bio[d]! + 1;
      else if (r.garbageType == GarbageType.nonBiodegradable) nonBio[d] = nonBio[d]! + 1;
    }
    double maxY = 10;
    final all = [...bio.values, ...nonBio.values];
    if (all.isNotEmpty) {
      final m = all.reduce((a, b) => a > b ? a : b);
      if (m > maxY) maxY = m + 2;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Weekly Requests', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 28),
            SizedBox(
              height: 280,
              child: BarChart(BarChartData(
                alignment: BarChartAlignment.spaceAround, maxY: maxY,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 36,
                    getTitlesWidget: (v, m) {
                      const s = TextStyle(color: AppTheme.textTertiary, fontWeight: FontWeight.bold, fontSize: 11);
                      const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
                      return SideTitleWidget(meta: m, space: 8, child: Text(days[v.toInt().clamp(0,6)], style: s));
                    },
                  )),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: (maxY/5).ceilToDouble(), getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(7, (i) => BarChartGroupData(barsSpace: 6, x: i, barRods: [
                  BarChartRodData(toY: bio[i]!, color: AppTheme.primaryColor, width: 11, borderRadius: BorderRadius.circular(4)),
                  BarChartRodData(toY: nonBio[i]!, color: AppTheme.accentColor, width: 11, borderRadius: BorderRadius.circular(4)),
                ])),
              )),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _dot(AppTheme.primaryColor, 'Biodegradable'),
              const SizedBox(width: 24),
              _dot(AppTheme.accentColor, 'Non-biodegradable'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(List<RequestEntity> requests) {
    final collected = requests.where((r) => r.status == RequestStatus.collected).length;
    final pending   = requests.where((r) => r.status == RequestStatus.pending).length;
    final rejected  = requests.where((r) => r.status == RequestStatus.rejected).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Collection Status', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 28),
            SizedBox(
              height: 180,
              child: PieChart(PieChartData(
                sectionsSpace: 4, centerSpaceRadius: 45,
                sections: [
                  if (collected > 0) PieChartSectionData(color: AppTheme.success, value: collected.toDouble(), title: '', radius: 20),
                  if (pending > 0)   PieChartSectionData(color: AppTheme.warning, value: pending.toDouble(), title: '', radius: 20),
                  if (rejected > 0)  PieChartSectionData(color: AppTheme.error,   value: rejected.toDouble(), title: '', radius: 20),
                  if (collected == 0 && pending == 0 && rejected == 0) PieChartSectionData(color: Colors.white12, value: 1, title: '', radius: 20),
                ],
              )),
            ),
            const SizedBox(height: 20),
            _statusRow(AppTheme.success, 'Collected', collected),
            const SizedBox(height: 8),
            _statusRow(AppTheme.warning, 'Pending', pending),
            const SizedBox(height: 8),
            _statusRow(AppTheme.error, 'Rejected', rejected),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(Color c, String l, int n) => Row(children: [
    Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: c, boxShadow: [BoxShadow(color: c.withOpacity(0.4), blurRadius: 4)])),
    const SizedBox(width: 10),
    Expanded(child: Text(l, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
    Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  ]);

  Widget _dot(Color c, String l) => Row(children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: c)),
    const SizedBox(width: 8),
    Text(l, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
  ]);
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatItem({required this.value, required this.label, this.color = Colors.white});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;
  const _MetricCard({required this.title, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderColor)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ])),
      ]),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1));
}
