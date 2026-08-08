import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:biongo_admin/core/theme/app_theme.dart';
import 'package:biongo_admin/features/live_tracking/domain/entities/driver_location_entity.dart';
import 'package:biongo_admin/features/live_tracking/domain/repositories/driver_location_repository.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  String? _selectedSafeEmail;
  Timer? _ticker;

  /// Cached once so the [StreamBuilder] does not subscribe/unsubscribe on
  /// every rebuild (e.g. when the periodic ticker triggers setState).
  Stream<List<DriverLocationEntity>>? _stream;

  /// Tracks whether we've already auto-fitted the camera to the first batch
  /// of drivers that appeared. Without this, the map stays at the fallback
  /// center after drivers finally come online.
  bool _didInitialFit = false;

  static const LatLng _fallbackCenter = LatLng(6.0530, 80.5320);

  @override
  void initState() {
    super.initState();
    _stream = context.read<DriverLocationRepository>().watchAll();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _focusDriver(DriverLocationEntity driver) {
    setState(() => _selectedSafeEmail = driver.safeEmail);
    _safeMapOp(() {
      _mapController.move(LatLng(driver.latitude, driver.longitude), 16);
    });
  }

  void _fitAll(List<DriverLocationEntity> drivers) {
    if (drivers.isEmpty) return;
    _safeMapOp(() {
      if (drivers.length == 1) {
        _mapController.move(
          LatLng(drivers.first.latitude, drivers.first.longitude),
          15,
        );
        return;
      }
      final points = drivers
          .map((d) => LatLng(d.latitude, d.longitude))
          .toList(growable: false);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(80),
          maxZoom: 15,
        ),
      );
    });
  }

  /// Some map ops throw if called before the [FlutterMap] is actually mounted
  /// (e.g. auto-fit during the very first build). Guard via a post-frame callback.
  void _safeMapOp(VoidCallback op) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        op();
      } catch (_) {
        // Swallow: map may not be laid out yet, or controller is disposed.
      }
    });
  }

  void _reconcileAfterData(List<DriverLocationEntity> drivers) {
    // Drop selection if the selected driver disappeared.
    if (_selectedSafeEmail != null &&
        !drivers.any((d) => d.safeEmail == _selectedSafeEmail)) {
      _selectedSafeEmail = null;
    }
    // Auto-fit the first time data arrives.
    if (!_didInitialFit && drivers.isNotEmpty) {
      _didInitialFit = true;
      _fitAll(drivers);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DriverLocationEntity>>(
      stream: _stream,
      builder: (context, snapshot) {
        final drivers = snapshot.data ?? const <DriverLocationEntity>[];
        final onlineCount =
            drivers.where((d) => d.isOnline && !d.isStale).length;
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;
        final error = snapshot.error;

        _reconcileAfterData(drivers);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 980;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  total: drivers.length,
                  online: onlineCount,
                  onFitAll: drivers.isEmpty ? null : () => _fitAll(drivers),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _buildBody(
                    isLoading: isLoading,
                    error: error,
                    drivers: drivers,
                    isNarrow: isNarrow,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBody({
    required bool isLoading,
    required Object? error,
    required List<DriverLocationEntity> drivers,
    required bool isNarrow,
  }) {
    if (error != null && drivers.isEmpty) {
      return _ErrorState(
        message: 'Could not load live tracking data.\n$error',
      );
    }
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    final mapCard = _MapCard(
      controller: _mapController,
      drivers: drivers,
      selectedSafeEmail: _selectedSafeEmail,
      onMarkerTap: _focusDriver,
      fallbackCenter: _fallbackCenter,
    );

    final sidebar = _DriverSidebar(
      drivers: drivers,
      selectedSafeEmail: _selectedSafeEmail,
      onSelect: _focusDriver,
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: mapCard),
          const SizedBox(height: 16),
          SizedBox(height: 260, child: sidebar),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: mapCard),
        const SizedBox(width: 24),
        SizedBox(width: 340, child: sidebar),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.error.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 32),
            const SizedBox(height: 12),
            const Text(
              'Live tracking unavailable',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int total;
  final int online;
  final VoidCallback? onFitAll;

  const _Header({
    required this.total,
    required this.online,
    required this.onFitAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Tracking',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Real-time positions of drivers currently on duty',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        _StatPill(
          label: 'Online',
          value: online.toString(),
          color: AppTheme.success,
        ),
        const SizedBox(width: 12),
        _StatPill(
          label: 'Total tracked',
          value: total.toString(),
          color: AppTheme.primaryColor,
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: onFitAll,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            side: const BorderSide(color: AppTheme.borderColor),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.center_focus_strong_outlined, size: 18),
          label: const Text('Fit all'),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  final MapController controller;
  final List<DriverLocationEntity> drivers;
  final String? selectedSafeEmail;
  final ValueChanged<DriverLocationEntity> onMarkerTap;
  final LatLng fallbackCenter;

  const _MapCard({
    required this.controller,
    required this.drivers,
    required this.selectedSafeEmail,
    required this.onMarkerTap,
    required this.fallbackCenter,
  });

  @override
  Widget build(BuildContext context) {
    final initialCenter = drivers.isNotEmpty
        ? LatLng(drivers.first.latitude, drivers.first.longitude)
        : fallbackCenter;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: drivers.isEmpty ? 11 : 14,
              minZoom: 3,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.bingo.admin',
              ),
              MarkerLayer(
                markers: drivers.map((d) {
                  final isSelected = d.safeEmail == selectedSafeEmail;
                  return Marker(
                    point: LatLng(d.latitude, d.longitude),
                    width: 160,
                    height: 60,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => onMarkerTap(d),
                      child: _DriverMarker(
                        driver: d,
                        isSelected: isSelected,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          if (drivers.isEmpty)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: AppTheme.backgroundColor.withOpacity(0.55),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_off_outlined,
                        color: AppTheme.textTertiary,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No drivers currently sharing location',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Drivers appear here once they go On Duty in the mobile app.',
                        style: TextStyle(
                          color: AppTheme.textTertiary.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DriverMarker extends StatelessWidget {
  final DriverLocationEntity driver;
  final bool isSelected;

  const _DriverMarker({required this.driver, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final online = driver.isOnline && !driver.isStale;
    final color = !online
        ? AppTheme.textTertiary
        : isSelected
            ? AppTheme.accentColor
            : AppTheme.primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor.withOpacity(0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.6)),
          ),
          child: Text(
            driver.driverName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: isSelected ? 22 : 18,
          height: isSelected ? 22 : 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.55),
                blurRadius: isSelected ? 14 : 8,
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
          child: const Icon(
            Icons.local_shipping,
            size: 12,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _DriverSidebar extends StatelessWidget {
  final List<DriverLocationEntity> drivers;
  final String? selectedSafeEmail;
  final ValueChanged<DriverLocationEntity> onSelect;

  const _DriverSidebar({
    required this.drivers,
    required this.selectedSafeEmail,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_alt_outlined,
                color: AppTheme.accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Active Drivers',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${drivers.length}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.borderColor, height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: drivers.isEmpty
                ? Center(
                    child: Text(
                      'No active drivers yet.',
                      style: TextStyle(
                        color: AppTheme.textTertiary.withOpacity(0.9),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: drivers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = drivers[i];
                      return _DriverRow(
                        driver: d,
                        selected: d.safeEmail == selectedSafeEmail,
                        onTap: () => onSelect(d),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DriverRow extends StatelessWidget {
  final DriverLocationEntity driver;
  final bool selected;
  final VoidCallback onTap;

  const _DriverRow({
    required this.driver,
    required this.selected,
    required this.onTap,
  });

  String _relativeUpdated() {
    final t = driver.updatedAt;
    if (t == null) return 'Unknown';
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 10) return 'just now';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, HH:mm').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final online = driver.isOnline && !driver.isStale;
    final statusColor = online ? AppTheme.success : AppTheme.textTertiary;
    final rawSpeed = driver.speed.isFinite ? driver.speed : 0.0;
    final speedKmh = (rawSpeed * 3.6).clamp(0.0, 999.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withOpacity(0.10)
              : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor.withOpacity(0.4)
                : AppTheme.borderColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_shipping,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    driver.driverName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    driver.driverEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip(online ? 'Online' : 'Offline', statusColor),
                      const SizedBox(width: 6),
                      _chip(
                        '${speedKmh.toStringAsFixed(0)} km/h',
                        AppTheme.info,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _relativeUpdated(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
