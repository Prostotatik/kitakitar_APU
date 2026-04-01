// Implementation for web: uses JS Places API (no CORS). See web/index.html.

import 'dart:js_util' as js_util;
import 'dart:js' as js;

class PlacesAutocompleteService {
  static Future<List<({String description, String placeId})>> getSuggestions(
    String input,
  ) async {
    if (input.trim().length < 2) return [];
    if (js.context['getPlacesSuggestions'] == null) return [];
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final promise = js_util.callMethod(
            js.context, 'getPlacesSuggestions', [input.trim()]);
        final result = await js_util.promiseToFuture(promise);
        final dartResult = js_util.dartify(result) as Map<String, dynamic>?;
        if (dartResult == null) return [];
        if (dartResult['status'] == 'OK') {
          final list = dartResult['predictions'] as List<dynamic>? ?? [];
          return list
              .map((e) {
                final m = e as Map<String, dynamic>;
                return (
                  description: m['description'] as String? ?? '',
                  placeId: m['place_id'] as String? ?? '',
                );
              })
              .where((e) =>
                  e.description.isNotEmpty && e.placeId.isNotEmpty)
              .toList();
        }
        if (dartResult['status'] != 'NOT_LOADED') return [];
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  static Future<({double lat, double lng, String address})?>
      getLocationByPlaceId(String placeId) async {
    if (js.context['getPlaceDetails'] == null) return null;
    try {
      final promise =
          js_util.callMethod(js.context, 'getPlaceDetails', [placeId]);
      final result = await js_util.promiseToFuture(promise);
      if (result == null) return null;
      final dartResult = js_util.dartify(result) as Map<String, dynamic>?;
      if (dartResult == null) return null;
      final lat = (dartResult['lat'] as num?)?.toDouble();
      final lng = (dartResult['lng'] as num?)?.toDouble();
      final address = dartResult['address'] as String? ?? '';
      if (lat == null || lng == null) return null;
      return (
        lat: lat,
        lng: lng,
        address: address.isNotEmpty ? address : '$lat, $lng'
      );
    } catch (_) {
      return null;
    }
  }
}
