import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Address suggestions via Photon (Komoot) — free, CORS-friendly, no API key.
/// https://photon.komoot.io/
class PhotonAutocompleteService {
  /// Base forward-search endpoint.
  static const _searchBase = 'https://photon.komoot.io/api';

  /// Reverse-geocoding endpoint (no `/api` prefix!).
  static const _reverseBase = 'https://photon.komoot.io/reverse';

  /// Bounding box for Malaysia (minLon,minLat,maxLon,maxLat).
  /// Used to restrict suggestions to the Malaysia region.
  static const _malaysiaBbox = '100.08,1.30,119.27,7.38';

  /// Returns address suggestions with lat/lng and display text. One request, no second call needed.
  static Future<List<({String description, double lat, double lng, String address})>>
      getSuggestions(String input) async {
    if (input.trim().length < 2) return [];
    final q = Uri.encodeQueryComponent(input.trim());
    final url = '$_searchBase/?q=$q&limit=8&lang=en&bbox=$_malaysiaBbox';
    debugPrint('[Photon] getSuggestions input="$input" url=$url');
    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json', 'User-Agent': 'KitaKitarCenter/1.0'},
      );
      debugPrint('[Photon] status=${resp.statusCode}, length=${resp.body.length}');
      if (resp.statusCode != 200) return [];
      final json = jsonDecode(resp.body) as Map<String, dynamic>?;
      if (json == null) return [];
      final features = json['features'] as List<dynamic>? ?? [];
      debugPrint('[Photon] features count=${features.length}');
      final out = <({String description, double lat, double lng, String address})>[];
      for (var i = 0; i < features.length; i++) {
        final feat = features[i] as Map<String, dynamic>?;
        if (feat == null) continue;
        final geom = feat['geometry'] as Map<String, dynamic>?;
        final coords = geom?['coordinates'] as List<dynamic>?;
        if (coords == null || coords.length < 2) continue;
        final lng = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        final props = feat['properties'] as Map<String, dynamic>? ?? {};
        final description = _formatDescription(props);
        final address = description;
        debugPrint(
          '[Photon] suggestion[$i] "$description" lat=$lat lng=$lng',
        );
        out.add((description: description, lat: lat, lng: lng, address: address));
      }
      return out;
    } catch (e) {
      debugPrint('[Photon] ERROR: $e');
      return [];
    }
  }

  static String _formatDescription(Map<String, dynamic> props) {
    final name = props['name'] as String? ?? '';
    final street = props['street'] as String?;
    final housenumber = props['housenumber'] as String?;
    final city = props['city'] as String?;
    final postcode = props['postcode'] as String?;
    final country = props['country'] as String? ?? '';
    final parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    if (street != null && street.isNotEmpty) {
      parts.add(housenumber != null ? '$street $housenumber' : street);
    }
    if (city != null && city.isNotEmpty) parts.add(city);
    if (postcode != null && postcode.isNotEmpty) parts.add(postcode);
    if (country.isNotEmpty) parts.add(country);
    return parts.isEmpty ? 'Location' : parts.join(', ');
  }

  /// Reverse geocode: get address string for a point (e.g. when user taps on map).
  static Future<String?> getAddressForLocation(double lat, double lng) async {
    try {
      final url = '$_reverseBase?lat=$lat&lon=$lng';
      debugPrint('[Photon] reverse url=$url');
      final resp = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json', 'User-Agent': 'KitaKitarCenter/1.0'},
      );
      debugPrint(
        '[Photon] reverse status=${resp.statusCode}, length=${resp.body.length}',
      );
      if (resp.statusCode != 200) return null;
      final json = jsonDecode(resp.body) as Map<String, dynamic>?;
      if (json == null) return null;
      final features = json['features'] as List<dynamic>? ?? [];
      if (features.isEmpty) return null;
      final feat = features.first as Map<String, dynamic>?;
      if (feat == null) return null;
      final props = feat['properties'] as Map<String, dynamic>? ?? {};
      return _formatDescription(props);
    } catch (_) {
      return null;
    }
  }
}
