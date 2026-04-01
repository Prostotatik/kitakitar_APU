import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kitakitar_mobile/services/ai_service.dart';
import 'package:kitakitar_mobile/services/firestore_service.dart';
import 'package:kitakitar_mobile/services/storage_service.dart';
import 'package:kitakitar_mobile/providers/auth_provider.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final AIService _aiService = AIService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  void _showImageSourcePicker() {
    if (_isProcessing) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose how to add a photo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF4CAF50)),
                title: const Text('Take a photo'),
                subtitle: const Text('Capture your waste with the camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndProcessImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF4CAF50)),
                title: const Text('Choose from gallery'),
                subtitle: const Text('Upload a photo from your gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndProcessImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isProcessing = true;
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;
      if (userId == null) return;

      // Upload image to storage
      final imageUrl = await _storageService.uploadImage(
        File(image.path),
        userId,
      );

      // Detect materials with AI
      final scanResult = await _aiService.detectMaterials(image.path);

      // Save AI scan to Firestore
      await _firestoreService.saveAiScan(
        userId,
        imageUrl,
        scanResult.materials.map((m) => m.toMap()).toList(),
        preparationTip: scanResult.preparationTip,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        // Navigate to result screen
        context.push('/scan-result', extra: {
          'detectedMaterials': scanResult.materials,
          'preparationTip': scanResult.preparationTip,
          'imagePath': image.path,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan'),
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: _isProcessing ? null : _showImageSourcePicker,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green.shade50,
                    Colors.green.shade100,
                  ],
                ),
              ),
              child: _isProcessing
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Processing image...'),
                        ],
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 100,
                            color: Color(0xFF4CAF50),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'Tap to scan',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Take or choose a photo of your waste',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 24,
            child: FloatingActionButton(
              heroTag: 'scan_history',
              backgroundColor: Colors.white,
              onPressed: () => context.push('/scan-history'),
              child: const Icon(Icons.history, color: Color(0xFF4CAF50)),
            ),
          ),
        ],
      ),
    );
  }
}

