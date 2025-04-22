import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map App with Permission Handling',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final LatLng _initialCenter = const LatLng(-6.200000, 106.816666);
  Marker? _currentMarker;
  Timer? _debounceTimer;
  double? _currentLat;
  double? _currentLng;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleLocationPermission() async {
    final status = await Permission.location.status;

    if (status.isDenied) {
      await _showPermissionDialog(
        "Aplikasi membutuhkan akses lokasi",
        "Izinkan akses lokasi untuk menampilkan posisi Anda di peta",
      );
    }

    if (status.isPermanentlyDenied) {
      await _showSettingsDialog();
      return;
    }

    final result = await Permission.location.request();
    if (result.isDenied) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Izin lokasi diperlukan untuk fitur ini'),
        );
      }
    }
  }

  Future<void> _showPermissionDialog(String title, String message) async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await openAppSettings();
                },
                child: const Text('Buka Pengaturan'),
              ),
            ],
          ),
    );
  }

  Future<void> _showSettingsDialog() async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Izin Dihentikan Selamanya'),
            content: const Text(
              'Buka pengaturan untuk mengaktifkan izin lokasi',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Nanti'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await openAppSettings();
                },
                child: const Text('Buka Pengaturan'),
              ),
            ],
          ),
    );
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _showEnableLocationDialog();
        return;
      }

      await _handleLocationPermission();

      final permissionStatus = await Permission.location.status;
      if (!permissionStatus.isGranted) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      LatLng coords = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;

        _currentMarker = Marker(
          point: coords,
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 40),
                duration: const Duration(seconds: 2),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Container(
                    width: value,
                    height: value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withAlpha(
                        ((1 - (value / 40)) * 255).toInt(),
                      ),
                    ),
                  );
                },
                onEnd: () {
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              const Icon(Icons.my_location, color: Colors.blue, size: 36),
            ],
          ),
        );
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(_buildSnackBar('Error: ${e.toString()}'));
      }
    }
  }

  SnackBar _buildSnackBar(String message) {
    return SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Future<void> _searchAndNavigate() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    try {
      List<Location> results = await locationFromAddress(query);
      if (results.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(_buildSnackBar('Lokasi tidak ditemukan'));
        }
        return;
      }

      Location loc = results.first;
      LatLng coords = LatLng(loc.latitude, loc.longitude);

      setState(() {
        _currentLat = loc.latitude;
        _currentLng = loc.longitude;

        _currentMarker = Marker(
          point: coords,
          child: const Icon(Icons.place, color: Colors.red, size: 36),
        );
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(_buildSnackBar('Gagal mencari lokasi: ${e.toString()}'));
      }
    }
  }

  Future<void> _showEnableLocationDialog() async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Lokasi Dimatikan'),
            content: const Text('Aktifkan layanan lokasi untuk melanjutkan'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                  Navigator.pop(context);
                },
                child: const Text('Aktifkan'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _initialCenter, initialZoom: 12),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.app',
              ),
              if (_currentMarker != null)
                MarkerLayer(markers: [_currentMarker!]),
            ],
          ),
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 4),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchAndNavigate(),
                      decoration: const InputDecoration(
                        hintText: 'Cari lokasi...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _searchAndNavigate,
                  ),
                ],
              ),
            ),
          ),
          if (_currentLat != null && _currentLng != null)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 4),
                  ],
                ),
                child: Text(
                  'Latitude: ${_currentLat!.toStringAsFixed(6)}, '
                  'Longitude: ${_currentLng!.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await _determinePosition();
          if (_currentMarker != null) {
            _mapController.move(_currentMarker!.point, 17);
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
