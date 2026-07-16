import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/photon_autocomplete_service.dart';

/// Default map position (Malaysia, near geographic center).
const double _defaultLat = 4.21;
const double _defaultLng = 101.98;

/// One address suggestion (Photon returns lat/lng directly, no second request).
typedef _Suggestion = ({
  String description,
  double lat,
  double lng,
  String address,
});

/// Address picker: map with search bar on top. Type address → suggestions (Photon);
/// tap suggestion → marker + camera. Tap on map to set marker.
class AddressMapPicker extends StatefulWidget {
  const AddressMapPicker({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialAddress,
    required this.onLocationSelected,
    this.height = 280,
  });

  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;
  final void Function(double lat, double lng, String address) onLocationSelected;
  final double height;

  @override
  State<AddressMapPicker> createState() => _AddressMapPickerState();
}

class _AddressMapPickerState extends State<AddressMapPicker> {
  GoogleMapController? _mapController;
  LatLng? _markerPosition;
  final TextEditingController _addressController = TextEditingController();
  Set<Marker> _markers = {};
  List<_Suggestion> _suggestions = [];
  bool _suggestionsLoading = false;
  bool _reverseGeocoding = false;
  Timer? _debounceTimer;
  String _status = '';
  bool _hasSearchSelection = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[AddressMapPicker] initState '
        'initialLat=${widget.initialLat}, initialLng=${widget.initialLng}, '
        'initialAddress="${widget.initialAddress}"');
    _syncFromWidget();
  }

  /// Sync only on first build. Avoids parent rebuilds (e.g. in profile) overwriting
  /// user input and moving the marker while they type or select an address.
  void _syncFromWidget() {
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _addressController.text = widget.initialAddress!;
    }
    if (widget.initialLat != null && widget.initialLng != null) {
      final pos = LatLng(widget.initialLat!, widget.initialLng!);
      debugPrint(
        '[AddressMapPicker] _syncFromWidget set marker from initial: '
        'lat=${widget.initialLat}, lng=${widget.initialLng}',
      );
      _markerPosition = pos;
      _markers = {
        Marker(
          markerId: const MarkerId('center'),
          position: pos,
        ),
      };
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _addressController.dispose();
    super.dispose();
  }

  LatLng get _initialCamera =>
      _markerPosition ?? const LatLng(_defaultLat, _defaultLng);

  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _suggestionsLoading = false;
      });
      return;
    }
    setState(() => _suggestionsLoading = true);
    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      debugPrint('[AddressMapPicker] query="$value" → fetching Photon suggestions');
      final list = await PhotonAutocompleteService.getSuggestions(value);
      if (!mounted) return;
      setState(() {
        _suggestions = list;
        _suggestionsLoading = false;
      });
      debugPrint(
        '[AddressMapPicker] Photon suggestions count=${list.length} '
        'for query="$value"',
      );
    });
  }

  void _onSuggestionTap(_Suggestion s) {
    debugPrint(
      '[AddressMapPicker] onSuggestionTap '
      '"${s.description}" lat=${s.lat}, lng=${s.lng}',
    );
    final position = LatLng(s.lat, s.lng);
    setState(() {
      _suggestions = [];
      _addressController.text = s.address;
      _markerPosition = position;
      _markers = {
        Marker(
          markerId: const MarkerId('center'),
          position: position,
        ),
      };
      _status =
          'Coordinates: ${s.lat.toStringAsFixed(4)}, ${s.lng.toStringAsFixed(4)}.';
      _hasSearchSelection = true;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 15),
    );
    debugPrint(
      '[AddressMapPicker] marker updated & camera animated to '
      'lat=${position.latitude}, lng=${position.longitude}',
    );
    debugPrint(
      '[AddressMapPicker] calling onLocationSelected '
      'lat=${s.lat}, lng=${s.lng}',
    );
    widget.onLocationSelected(s.lat, s.lng, s.address);
  }

  void _onMapTap(LatLng position) {
    // If location was already chosen from search suggestions, ignore accidental
    // map taps (they can be triggered while interacting with the overlay).
    if (_hasSearchSelection) {
      debugPrint(
        '[AddressMapPicker] onMapTap ignored because location already set from search',
      );
      return;
    }

    final lat = position.latitude;
    final lng = position.longitude;
    debugPrint(
      '[AddressMapPicker] onMapTap lat=$lat, lng=$lng',
    );
    final coordsStr =
        '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    setState(() {
      _markerPosition = position;
      _markers = {
        Marker(
          markerId: const MarkerId('center'),
          position: position,
        ),
      };
      _status =
          'Coordinates: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}. Looking up address…';
      _reverseGeocoding = true;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, 15),
    );
    PhotonAutocompleteService.getAddressForLocation(lat, lng).then((address) {
      if (!mounted) return;
      final resolved = address ?? coordsStr;
      setState(() {
        _addressController.text = resolved;
        _status =
            'Coordinates: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}.';
        _reverseGeocoding = false;
      });
      debugPrint(
        '[AddressMapPicker] reverse geocode resolved="$resolved" '
        'for lat=$lat, lng=$lng',
      );
      widget.onLocationSelected(lat, lng, resolved);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Address and coordinates',
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GoogleMap(
                    key: ValueKey(
                      '${_markerPosition?.latitude}_${_markerPosition?.longitude}',
                    ),
                    initialCameraPosition: CameraPosition(
                      target: _initialCamera,
                      zoom: _markerPosition != null ? 15 : 10,
                    ),
                    onMapCreated: (GoogleMapController c) {
                      _mapController = c;
                      debugPrint(
                        '[AddressMapPicker] GoogleMap created. '
                        'initialCamera=$_initialCamera, '
                        'marker=$_markerPosition',
                      );
                    },
                    onTap: _onMapTap,
                    markers: _markers,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            hintText: 'Search address on map',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _reverseGeocoding
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                          onChanged: _onQueryChanged,
                        ),
                        if (_suggestions.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(12)),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _suggestions.length,
                              itemBuilder: (context, i) {
                                final s = _suggestions[i];
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.location_on_outlined,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  title: Text(
                                    s.description,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  onTap: () => _onSuggestionTap(s),
                                );
                              },
                            ),
                          )
                        else if (_suggestionsLoading)
                          Container(
                            padding: const EdgeInsets.all(12),
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_status.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            _status,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }
}
