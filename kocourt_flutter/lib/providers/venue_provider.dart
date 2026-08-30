import 'package:flutter/material.dart';
import '../core/api.dart';

class VenueProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _venues = [];
  List<Map<String, dynamic>> _ghostPlaces = [];
  Set<int> _favorites = {};
  bool _isLoading = false;
  bool _isGhostLoading = false;
  bool _fetched = false;
  String _selectedSport = 'All';
  int _selectedRadius = 25;
  String _searchText = '';
  double? _userLat;
  double? _userLng;

  List<Map<String, dynamic>> get venues => _venues;
  List<Map<String, dynamic>> get ghostPlaces => _ghostPlaces;
  Set<int> get favorites => _favorites;
  bool get isLoading => _isLoading;
  bool get isGhostLoading => _isGhostLoading;
  bool get fetched => _fetched;
  String get selectedSport => _selectedSport;
  int get selectedRadius => _selectedRadius;
  String get searchText => _searchText;
  double? get userLat => _userLat;
  double? get userLng => _userLng;

  void setLocation(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
    notifyListeners();
  }

  void setSearchText(String text) {
    _searchText = text;
    notifyListeners();
  }

  void clearLocation() {
    _userLat = null;
    _userLng = null;
    notifyListeners();
  }

  void setSport(String sport) {
    _selectedSport = sport;
    notifyListeners();
    fetchVenues();
  }

  void setRadius(int radius) {
    _selectedRadius = radius;
    notifyListeners();
    if (_userLat != null && _userLng != null) fetchVenues();
  }

  Future<void> fetchVenues() async {
    _isLoading = true;
    notifyListeners();
    try {
      final params = <String, dynamic>{};
      if (_userLat != null && _userLng != null) {
        params['lat'] = _userLat;
        params['lng'] = _userLng;
        params['radius'] = _selectedRadius;
      } else if (_searchText.isNotEmpty) {
        params['location'] = _searchText;
      }
      if (_selectedSport != 'All') params['type'] = _selectedSport;

      final res = await Api().get('/courts', params: params);
      _venues = List<Map<String, dynamic>>.from(
        (res.data['records'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {
      _venues = [];
    } finally {
      _isLoading = false;
      _fetched = true;
      notifyListeners();
    }
  }

  Future<void> fetchGhostPlaces({int? userId}) async {
    if (_userLat == null || _userLng == null) return;
    _isGhostLoading = true;
    notifyListeners();
    try {
      final params = <String, dynamic>{
        'lat': _userLat,
        'lng': _userLng,
      };
      if (userId != null) params['user_id'] = userId;
      final res = await Api().get('/nearby-places', params: params);
      _ghostPlaces = List<Map<String, dynamic>>.from(
        (res.data['places'] ?? []).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (_) {
      _ghostPlaces = [];
    } finally {
      _isGhostLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFavorites(int userId) async {
    try {
      final res = await Api().get('/favorites', params: {'user_id': userId});
      _favorites = Set<int>.from((res.data['ids'] ?? []).map((e) => e is int ? e : int.parse(e.toString())));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> toggleFavorite(int courtId, int userId) async {
    try {
      final res = await Api().post('/favorites', data: {'user_id': userId, 'court_id': courtId});
      if (res.data['favorited'] == true) {
        _favorites.add(courtId);
      } else {
        _favorites.remove(courtId);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> sendInterest(Map<String, dynamic> place, int userId) async {
    try {
      final res = await Api().post('/service-requests', data: {
        'place_id': place['id'],
        'user_id': userId,
      });
      place['user_requested'] = true;
      place['request_count'] = res.data['request_count'];
      notifyListeners();
    } catch (_) {}
  }
}
