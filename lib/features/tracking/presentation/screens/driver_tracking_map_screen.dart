import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/map_pin.dart';

class _AssignedDriverInfo {
  final String driverId;
  final String driverName;
  final String requestAddress;

  _AssignedDriverInfo({
    required this.driverId,
    required this.driverName,
    required this.requestAddress,
  });
}

class DriverTrackingMapScreen extends StatefulWidget {
  const DriverTrackingMapScreen({super.key});

  @override
  State<DriverTrackingMapScreen> createState() => _DriverTrackingMapScreenState();
}

class _DriverTrackingMapScreenState extends State<DriverTrackingMapScreen> {
  static const LatLng _defaultCenter = LatLng(6.9271, 79.8612); // Colombo, Sri Lanka

  final MapController _mapController = MapController();
  int _lastFittedMarkerCount = -1;

  void _focusOnMarkers(List<LatLng> points, {bool force = false}) {
    if (points.isEmpty) return;
    if (!force && points.length == _lastFittedMarkerCount) return;
    _lastFittedMarkerCount = points.length;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (points.length == 1) {
        _mapController.move(points.first, 15);
      } else {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.fromLTRB(60, 100, 60, 60),
          ),
        );
      }
    });
  }

  bool _isToday(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Live Driver Tracking', style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 6),
        const Text(
          "Every driver assigned to a pickup today, live on the map.",
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('requests')
                .where('status', isEqualTo: 'assigned')
                .snapshots(),
            builder: (context, requestSnap) {
              if (requestSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
              }

              final Map<String, _AssignedDriverInfo> assignedToday = {};
              for (final doc in requestSnap.data?.docs ?? <QueryDocumentSnapshot>[]) {
                final data = doc.data() as Map<String, dynamic>;
                final driverId = data['assignedDriverId'] as String?;
                if (driverId == null) continue;
                final assignedAt = data['assignedAt'];
                final assignedDate = assignedAt is Timestamp ? assignedAt.toDate() : null;
                if (!_isToday(assignedDate)) continue;
                assignedToday[driverId] = _AssignedDriverInfo(
                  driverId: driverId,
                  driverName: data['assignedDriverName'] ?? 'Driver',
                  requestAddress: data['userAddress'] ?? '',
                );
              }

              if (assignedToday.isEmpty) {
                return const Center(
                  child: Text('No drivers assigned to a pickup today yet.', style: TextStyle(color: AppTheme.textTertiary)),
                );
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('driver_locations').snapshots(),
                builder: (context, locationSnap) {
                  final markers = <Marker>[];

                  for (final doc in locationSnap.data?.docs ?? <QueryDocumentSnapshot>[]) {
                    final info = assignedToday[doc.id];
                    if (info == null) continue;
                    final data = doc.data() as Map<String, dynamic>;
                    final lat = (data['lat'] as num?)?.toDouble();
                    final lng = (data['lng'] as num?)?.toDouble();
                    if (lat == null || lng == null) continue;

                    markers.add(
                      Marker(
                        point: LatLng(lat, lng),
                        width: 190,
                        height: 120,
                        alignment: Alignment.bottomCenter,
                        child: MapPin(
                          icon: Icons.local_shipping_rounded,
                          color: AppTheme.primaryColor,
                          title: info.driverName,
                          subtitle: info.requestAddress,
                        ),
                      ),
                    );
                  }

                  final points = markers.map((m) => m.point).toList();
                  final center = points.isNotEmpty ? points.first : _defaultCenter;
                  _focusOnMarkers(points);

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(initialCenter: center, initialZoom: points.isEmpty ? 12 : 13),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.bingo.admin',
                            ),
                            MarkerLayer(markers: markers),
                          ],
                        ),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF07121A).withOpacity(0.85),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: AppTheme.borderColor),
                            ),
                            child: Text(
                              '${markers.length} of ${assignedToday.length} assigned driver(s) live',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: FloatingActionButton(
                            heroTag: 'focusDrivers',
                            backgroundColor: AppTheme.primaryColor,
                            tooltip: 'Focus on drivers',
                            onPressed: points.isEmpty ? null : () => _focusOnMarkers(points, force: true),
                            child: const Icon(Icons.center_focus_strong_rounded, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

