import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadImage(dynamic imageFile, String userId) async {
    try {
      String filePath;
      if (imageFile is File) {
        filePath = imageFile.path;
      } else if (imageFile is XFile) {
        filePath = imageFile.path;
      } else {
        throw Exception('Unsupported file type');
      }

      final fileName = path.basename(filePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('users')
          .child(userId)
          .child('$timestamp$fileName');

      if (imageFile is File) {
        await ref.putFile(imageFile);
      } else if (imageFile is XFile) {
        await ref.putFile(File(imageFile.path));
      }

      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      rethrow;
    }
  }
}

