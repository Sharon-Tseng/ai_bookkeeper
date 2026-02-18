import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';

void main() {
  runApp(const BookkeeperApp());
}

class BookkeeperApp extends StatelessWidget {
  const BookkeeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Bookkeeper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // 對應你的 style.css: .btn-primary 顏色
        primarySwatch: Colors.green,
        primaryColor: const Color(0xFF2ecc71),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'sans-serif',
      ),
      home: const WelcomePage(),
    );
  }
}

// =========================================
// 1. WELCOME PAGE (對應 welcome.html)
// =========================================
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        // 對應你的 style.css: .welcome-page 的漸層
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2c3e50), Color(0xFF3498db)],
          ),
        ),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            padding: const EdgeInsets.all(40),
            // 對應 .welcome-container 的毛玻璃/半透明感
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Welcome to AI Bookkeeper!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Your intelligent assistant for managing your financial records with ease.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ecc71),
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const MainAppPage()));
                  },
                  child: const Text("Get Started", style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================
// 2. MAIN APP PAGE (導覽列 + Add Record)
// =========================================
class MainAppPage extends StatefulWidget {
  const MainAppPage({super.key});

  @override
  State<MainAppPage> createState() => _MainAppPageState();
}

class _MainAppPageState extends State<MainAppPage> {
  int _selectedIndex = 0;
  final TextEditingController _urlController = TextEditingController();
  File? _image;
  Uint8List? _webImage; // For web
  bool _isLoading = false;

  // 拍照功能
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      if (kIsWeb) {
        // For web, use bytes
        final bytes = await pickedFile.readAsBytes();
        if (mounted) {
          setState(() {
            _webImage = bytes;
          });
        }
      } else {
        // For mobile/desktop, use File
        if (mounted) {
          setState(() {
            _image = File(pickedFile.path);
          });
        }
      }
    }
  }

  final Logger _logger = Logger();

  // 對應原本 app.py 的 upload_receipt 邏輯
  Future<void> _uploadData() async {
    if (_image == null || _urlController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // 注意：手機模擬器連線電腦後端通常使用 10.0.0.2 或電腦 IP
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('http://10.0.2.2:5000/api/upload_receipt')
      );
      request.fields['sheet_url'] = _urlController.text;
      request.files.add(await http.MultipartFile.fromPath('receipt', _image!.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Success!")));
      }
    } catch (e) {
      _logger.e("Error uploading data", error: e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Bookkeeper"),
        backgroundColor: const Color(0xFFa3b8d3), // 對應 .top-nav
      ),
      body: _selectedIndex == 0 ? _buildAddRecordView() : _buildHistoryView(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add_a_photo), label: "Add Record"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
        ],
      ),
    );
  }

  // 建立 Add Record 畫面 (對應 add_record.html)
  Widget _buildAddRecordView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Step 1: Configuration", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: "Google Sheet URL",
              border: OutlineInputBorder(),
              hintText: "Paste your spreadsheet URL here",
            ),
          ),
          const SizedBox(height: 30),
          const Text("Step 2: Upload Receipt", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Center(
            child: kIsWeb
                ? (_webImage == null
                    ? const Text("No image selected.")
                    : Image.memory(_webImage!, height: 200))
                : (_image == null
                    ? const Text("No image selected.")
                    : Image.file(_image!, height: 200)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.camera_alt), label: const Text("Camera")),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _uploadData, 
                icon: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.cloud_upload), 
                label: const Text("Process")
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 建立 History 畫面 (對應 view_history.html)
  Widget _buildHistoryView() {
    return const Center(
      child: Text("History & Charts will be displayed here\n(Use fl_chart package for visualization)"),
    );
  }
}