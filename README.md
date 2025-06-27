Image 

# Overview
The Image Upload App named image is a Flutter-based mobile application designed to allow users to select multiple images from their device gallery and upload them to a mock server, even in offline scenarios. The app temporarily stores selected images in memory (RAM) and automatically uploads them when an internet connection (via Wi-Fi or mobile data) is restored. It features real-time connectivity monitoring, a user-friendly interface, and retry functionality for failed uploads.

# Requirement
Version: 1.0.0+1
SDK: Dart 3.6.0
Platform: Cross-platform (Android, iOS)
Purpose: Demonstrate offline image upload with in-memory storage using Flutter.

# Content of Readme file
1. Prerequisites
2. Setup Instructions
3. Project Structure
4. How the App Works
Step 1: Initialization and Connectivity Monitoring
Step 2: Image Selection and In-Memory Storage
Step 3: Upload Logic
Step 4: User Interface

   

# Prerequisites

Flutter SDK: Version 3.22.0 or later (compatible with Dart 3.6.0).
Dart SDK: Version 3.6.0.
IDE: Android Studio, VS Code, or any Flutter-supported editor.
Emulator/Device: Android emulator or physical device with developer mode enabled.
Internet Connection: Required for initial setup and mock server communication.

# Setup Instructions

Clone the Repository:

Clone this project or copy the provided code into a new Flutter project directory.

Install Dependencies:

Open the terminal in the project directory and run:flutter pub get

This installs all dependencies listed in pubspec.yaml.

Run the App:

Connect an emulator or physical device.
Run the app using:flutter run

# Ensure the device has permissions to access the gallery (granted during runtime). #

# Permissions:

On Android, add the following to AndroidManifest.xml (if not auto-generated):<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />


On iOS, update Info.plist with:<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to select images.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need access to save images.</string>



# Project Structure

lib/main.dart: The main entry point containing the app's logic and UI.
pubspec.yaml: Configuration file defining the project version, dependencies, and assets. it contains all requirements for running app

How the App Works
Step 1: Initialization and Connectivity Monitoring
by using
# Class: ImageUploadProvider
Process:
Upon app startup, the ImageUploadProvider initializes by checking the device's connectivity status using connectivity_plus.
The _initConnectivity method uses Connectivity().checkConnectivity() to determine if Wi-Fi or mobile data is available.
A StreamSubscription listens for connectivity changes via onConnectivityChanged, updating the _isConnected state and triggering auto-upload when online.

it is part of the code
# Key Code:void _initConnectivity() async {
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
  if (_isConnected) _uploadPendingImages();
  }
  });
 } #


# Outcome: The UI reflects "Online" or "Offline" status dynamically.

Step 2: Image Selection and In-Memory Storage
by using
Class: ImageUploadScreen
Process:
The _pickImages method uses image_picker to allow multiple image selections from the gallery.
Selected images are converted to Uint8List (binary data) and stored in the _images list within ImageUploadProvider as ImageItem objects.
If the device is online, the upload process begins immediately; otherwise, images remain in memory with a "Pending" status.

 # part of code 
  Key Code:Future<void> _pickImages(BuildContext context) async {
   final ImagePicker picker = ImagePicker();
   try {
   final List<XFile>? pickedFiles = await picker.pickMultiImage();
   if (pickedFiles != null) {
   for (var file in pickedFiles) {
   final bytes = await file.readAsBytes();
   Provider.of<ImageUploadProvider>(context, listen: false).addImage(bytes, file.name);
     }
    }
  } catch (e) {
   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking images: $e')));  }
}


# Outcome: Images are stored in RAM without disk usage, meeting the in-memory storage requirement.

Step 3: Upload Logic
by using
 Class: ImageUploadProvider
Process:
The _uploadImage method sends the image data as a multipart/form-data POST request to https://httpbin.org/post (a mock API endpoint).
If the response status is 200, the image status updates to "Success"; otherwise, it becomes "Failed" or remains "Pending" if offline.
The _uploadPendingImages method iterates through all pending images when connectivity is restored.
The retryUpload method allows retrying failed uploads when online.

# part of code
   Key Code:Future<void> _uploadImage(ImageItem image) async {
   if (image.status != 'Pending') return;
   image.status = 'Uploading';
   notifyListeners();
     try {
   var request = http.MultipartRequest('POST', Uri.parse('https://httpbin.org/post'));
   request.files.add(http.MultipartFile.fromBytes('image', image.imageData, filename: image.fileName));
   var response = await request.send();
    if (response.statusCode == 200) image.status = 'Success';
   else image.status = 'Failed';
   } catch (e) {
   image.status = 'Failed';
   }
    notifyListeners();
  }


# Outcome: Images are uploaded automatically or manually retried, with status updates reflected in the UI.

Step 4: User Interface
by using 
Class: ImageUploadScreen
Process:
The UI is built using Consumer<ImageUploadProvider> to react to state changes.
A styled AppBar and a connection status banner display the current network state.
A "Pick Images" button triggers image selection, and a GridView shows images with filenames and statuses (colored text for "Success," "Failed," or "Pending").
A retry IconButton appears for failed uploads.

the part of code 
# Key Code:GridView.builder(
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
 child: Image.memory(image.imageData, fit: BoxFit.cover, width: double.infinity, height: 120),
  ),
 ),
  const SizedBox(height: 8),
  Text(image.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), textAlign: TextAlign.center),
  const SizedBox(height: 4),
  Row(
   mainAxisAlignment: MainAxisAlignment.center,
  children: [
  Text('Status: ${image.status}', style: TextStyle(
   fontSize: 11,
  color: image.status == 'Success' ? Colors.green : image.status == 'Failed' ? Colors.red : Colors.orange,
   ), overflow: TextOverflow.ellipsis),
   if (image.status == 'Failed') ...[
   const SizedBox(width: 4),
   IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: () => provider.retryUpload(image), color: Colors.blue),
              ],
       ],
      ),
    ],
     ),
   ),
  );
   },
  )

# Limitations
1. Memory Usage: Storing large images in RAM may cause performance issues on low-memory devices.
2. Mock API: Relies on httpbin.org/post, which may be unreliable or rate-limited.
3. No Persistence: Images are lost on app restart due to in-memory storage.

# Outcome: A responsive, visually appealing interface that updates in real-time.

# Key Features

  Offline Support: Stores images in memory when offline and uploads them when online.
  Real-Time Connectivity: Monitors Wi-Fi and mobile data status.
  Multiple Image Upload: Supports selecting and uploading multiple images.
  Retry Mechanism: Allows retrying failed uploads.
  User Feedback: Displays status (Success, Pending, Failed) with color-coded text.

# Dependencies

  flutter: Core Flutter SDK.
  cupertino_icons: iOS-style icons.
  image_picker (1.1.2): For gallery image selection.
  connectivity_plus (6.1.4): For network connectivity monitoring.
  provider (6.1.5): For state management.
  http (1.4.0): For HTTP requests to the mock API.

# simple user module
1. click on the pick image button
2. choose the image or multiple images
3. see it the app show online or offline in case if it is online a status uploading comes
4. it the offline appear a status pending is shown as it turn online the image automatically uploaded
5. if shown failed status click on the retry icon it is will be successful
