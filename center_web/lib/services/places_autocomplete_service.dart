// Delegates to web (JS Places API) or stub. See web/index.html for getPlacesSuggestions / getPlaceDetails.

import 'places_autocomplete_stub.dart'
    if (dart.library.html) 'places_autocomplete_web.dart' as impl;
// On web: uses JS Places API. Otherwise: stub (center_web is web-only).

class PlacesAutocompleteService {
  static Future<List<({String description, String placeId})>> getSuggestions(
        String input) =>
      impl.PlacesAutocompleteService.getSuggestions(input);

  static Future<({double lat, double lng, String address})?>
      getLocationByPlaceId(String placeId) =>
      impl.PlacesAutocompleteService.getLocationByPlaceId(placeId);
}
