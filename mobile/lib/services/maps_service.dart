import 'package:geolocator/geolocator.dart';
import 'package:kitakitar_mobile/models/center_model.dart';
import 'package:kitakitar_mobile/models/ai_scan_model.dart';

class MapsService {
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // km
  }

  List<CenterModel> filterCentersByMaterials(
    List<CenterModel> centers,
    List<DetectedMaterial> detectedMaterials,
  ) {
    final materialTypes = detectedMaterials.map((m) => m.type).toSet();
    
    return centers.where((center) {
      // This is simplified - in production, check center.materials subcollection
      return true; // Placeholder
    }).toList();
  }

  CenterModel? getRecommendedCenter(
    List<CenterModel> centers,
    Position? userLocation,
    List<DetectedMaterial> detectedMaterials,
  ) {
    if (centers.isEmpty || userLocation == null) return null;

    // Sort by: distance + points (higher is better)
    centers.sort((a, b) {
      final distA = calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        a.location.latitude,
        a.location.longitude,
      );
      final distB = calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        b.location.latitude,
        b.location.longitude,
      );

      // Combine distance (lower is better) and points (higher is better)
      final scoreA = a.points / (distA + 1);
      final scoreB = b.points / (distB + 1);

      return scoreB.compareTo(scoreA);
    });

    return centers.first;
  }
}

