import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';

// Model to represent an image and its upload status
class ImageItem {
  final Uint8List imageData;
  String status;
  final String fileName;

  ImageItem({
    required this.imageData,
    this.status = 'Pending',
    required this.fileName,
  });
}

// State management using Provider
class ImageUploadProvider extends ChangeNotifier {
  List<ImageItem> _images = [];
  bool _isConnected = false;
  StreamSubscription? _connectivitySubscription;

  List<ImageItem> get images => _images;
  bool get isConnected => _isConnected;

  ImageUploadProvider() {
    _initConnectivity();
  }

  void _initConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    _isConnected = connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
    notifyListeners();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      bool newConnectionStatus = results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi);
      if (newConnectionStatus != _isConnected) {
        _isConnected = newConnectionStatus;
        notifyListeners();
        if (_isConnected) {
          _uploadPendingImages();
        }
      }
    });
  }

  Future<void> addImage(Uint8List imageData, String fileName) async {
    _images.add(ImageItem(imageData: imageData, fileName: fileName));
    notifyListeners();
    if (_isConnected) {
      await _uploadImage(_images.last);
    }
  }

  Future<void> _uploadImage(ImageItem image) async {
    if (image.status != 'Pending') return;

    image.status = 'Uploading';
    notifyListeners();

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://httpbin.org/post'),
      );
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        image.imageData,
        filename: image.fileName,
      ));

      var response = await request.send();
      if (response.statusCode == 200) {
        image.status = 'Success';
      } else {
        image.status = 'Failed';
      }
    } catch (e) {
      image.status = 'Failed';
    }
    notifyListeners();
  }

  Future<void> _uploadPendingImages() async {
    for (var image in _images.where((img) => img.status == 'Pending')) {
      await _uploadImage(image);
    }
  }

  Future<void> retryUpload(ImageItem image) async {
    if (image.status == 'Failed' && _isConnected) {
      image.status = 'Pending';
      notifyListeners();
      await _uploadImage(image);
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ImageUploadProvider(),
      child: MaterialApp(
        title: 'Offline Image Upload',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: Colors.grey[100],
          cardTheme: CardTheme(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            shadowColor: Colors.black.withOpacity(0.2),
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ),
        home: const ImageUploadScreen(),
      ),
    );
  }
}

class ImageUploadScreen extends StatelessWidget {
  const ImageUploadScreen({super.key});

  Future<void> _pickImages(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    try {
      final List<XFile>? pickedFiles = await picker.pickMultiImage();
      if (pickedFiles != null) {
        for (var file in pickedFiles) {
          final bytes = await file.readAsBytes();
          Provider.of<ImageUploadProvider>(context, listen: false)
              .addImage(bytes, file.name);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking images: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Image Upload'),
        elevation: 0,
        backgroundColor: Colors.blue[700],
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Consumer<ImageUploadProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: provider.isConnected ? Colors.green[100] : Colors.red[100],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            provider.isConnected ? Icons.wifi : Icons.wifi_off,
                            color: provider.isConnected ? Colors.green[800] : Colors.red[800],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            provider.isConnected ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: provider.isConnected ? Colors.green[800] : Colors.red[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _pickImages(context),
                      icon: const Icon(Icons.image, size: 20),
                      label: const Text('Pick Images'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: provider.images.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No images selected',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
                    : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.6,
                  ),
                  itemCount: provider.images.length,
                  itemBuilder: (context, index) {
                    final image = provider.images[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  image.imageData,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 120,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              image.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Flexible(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Status: ${image.status}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: image.status == 'Success'
                                            ? Colors.green
                                            : image.status == 'Failed'
                                            ? Colors.red
                                            : Colors.orange,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (image.status == 'Failed') ...[
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.refresh, size: 20),
                                      onPressed: () => provider.retryUpload(image),
                                      color: Colors.blue,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}