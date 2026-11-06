import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import '../../screens/owner/location_pick.dart';

class LocationSheet extends StatefulWidget {
  const LocationSheet({super.key});

  static Future<PickedPlace?> show(BuildContext context) {
    return showModalBottomSheet<PickedPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocationSheet(),
    );
  }

  @override
  State<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<LocationSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<PickedPlace> _results = [];
  bool _searching = false;
  bool _locating = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _nominatim(String path, Map<String, dynamic> query) async {
    final res = await Dio().get(
      'https://nominatim.openstreetmap.org/$path',
      queryParameters: query,
      options: Options(headers: {'User-Agent': 'KoCourt-Owner/1.0'}),
    );
    final data = res.data;
    if (data is List) {
      return data.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
    }
    if (data is Map) return [Map<String, dynamic>.from(data)];
    return [];
  }

  void _search(String value) {
    _debounce?.cancel();
    final text = value.trim();
    if (text.length < 2) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      try {
        final rows = await _nominatim('search', {
          'q': text,
          'format': 'json',
          'addressdetails': '1',
          'limit': '8',
          'countrycodes': 'in',
        });
        if (!mounted) return;
        setState(() {
          _results = [for (final row in rows) placeFromSearch(row)].whereType<PickedPlace>().toList();
          _error = null;
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _searching = false;
          _error = 'Could not search locations.';
        });
      }
    });
  }

  Future<void> _currentLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission is off. Search for an area instead.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)),
      );
      if (!mounted) return;
      final rows = await _nominatim('reverse', {
        'lat': position.latitude,
        'lon': position.longitude,
        'format': 'json',
        'addressdetails': '1',
      });
      final place = rows.isEmpty
          ? PickedPlace(label: 'Current location', lat: position.latitude, lng: position.longitude)
          : placeFromSearch({
              ...rows.first,
              'lat': position.latitude,
              'lon': position.longitude,
            });
      if (!mounted || place == null) return;
      Navigator.pop(context, place);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not read the current location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Choose location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search city or area',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _locating
                    ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.my_location, size: 18, color: AppColors.primary),
              ),
              title: const Text('Current location', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Use this phone’s GPS'),
              onTap: _locating ? null : _currentLocation,
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final place in _results)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(place.label),
                      onTap: () => Navigator.pop(context, place),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
