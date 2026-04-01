import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:kitakitar_mobile/services/qr_service.dart';
import 'package:kitakitar_mobile/providers/auth_provider.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final QRService _qrService = QRService();
  bool _isProcessing = false;

  static const String _kQrPayloadPrefix = 'KITAKITAR_QR:';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleQRScan(String rawValue) async {
    if (_isProcessing) return;

    // Validate and extract QR id from payload
    if (!rawValue.startsWith(_kQrPayloadPrefix)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR code. Please scan KitaKitar code.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final qrId = rawValue.substring(_kQrPayloadPrefix.length).trim();
    if (qrId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR code payload.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final userId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to claim points.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await _qrService.scanQRCode(qrId, userId);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Received ${result['pointsUser'] ?? 0} points!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && !_isProcessing) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  _handleQRScan(code);
                }
              }
            },
          ),
          // Overlay for visual design
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.green,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
