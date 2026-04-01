// Stub for non-web (e.g. analyzer). center_web is web-only; this is for conditional import.

class PlacesAutocompleteService {
  static Future<List<({String description, String placeId})>> getSuggestions(
    String input,
  ) async =>
      [];

  static Future<({double lat, double lng, String address})?> getLocationByPlaceId(
    String placeId,
  ) async =>
      null;
}
