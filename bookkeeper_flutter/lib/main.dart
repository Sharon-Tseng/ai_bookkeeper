import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
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
// 1. 歡迎頁面
// =========================================
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("AI Bookkeeper", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                const Text("您的智慧財務管理助手", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ecc71),
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MainAppPage())),
                  child: const Text("立即開始", style: TextStyle(fontSize: 20, color: Colors.white)),
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
// 2. 主頁面 (包含 Add Record 與 History)
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
  Uint8List? _webImage;
  bool _isLoading = false;
  final Logger _logger = Logger();

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() { _webImage = bytes; _image = null; });
      } else {
        setState(() { _image = File(pickedFile.path); _webImage = null; });
      }
    }
  }

  Future<void> _uploadData() async {
    final bool hasImage = kIsWeb ? (_webImage != null) : (_image != null);
    if (!hasImage || _urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("請提供收據照片與網址")));
      return;
    }
    setState(() => _isLoading = true);
    try {
      String apiUrl = kIsWeb ? 'http://127.0.0.1:5000/api/upload_receipt' : 'http://10.0.2.2:5000/api/upload_receipt';
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['sheet_url'] = _urlController.text; // Ensure sheet_url is sent
      if (kIsWeb) {
        request.files.add(http.MultipartFile.fromBytes('receipt', _webImage!, filename: 'receipt.png'));
      } else {
        request.files.add(await http.MultipartFile.fromPath('receipt', _image!.path));
      }
      var response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("上傳成功！")));
      } else {
        final respStr = await response.stream.bytesToString();
        debugPrint("Error: $respStr");
      }
    } catch (e) {
      _logger.e("Upload error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Bookkeeper"), backgroundColor: const Color(0xFFa3b8d3)),
      body: _selectedIndex == 0 ? _buildAddRecordView() : HistoryView(sheetUrl: _urlController.text),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.add_a_photo), label: "新增紀錄"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "歷史分析"),
        ],
      ),
    );
  }

  Widget _buildAddRecordView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          TextField(controller: _urlController, decoration: const InputDecoration(labelText: "Google Sheet 網址", border: OutlineInputBorder())),
          const SizedBox(height: 30),
          Container(
            height: 250, width: double.infinity,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(10)),
            child: kIsWeb ? (_webImage == null ? const Center(child: Text("未選取照片")) : Image.memory(_webImage!))
                           : (_image == null ? const Center(child: Text("未選取照片")) : Image.file(_image!)),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.camera_alt), label: const Text("拍照", style: TextStyle(fontSize: 18))),
              ElevatedButton.icon(onPressed: _isLoading ? null : _uploadData, icon: const Icon(Icons.cloud_upload), label: const Text("上傳處理", style: TextStyle(fontSize: 18))),
            ],
          ),
        ],
      ),
    );
  }
}

// =========================================
// 3. 歷史分析頁面 (修正圖表遮擋問題)
// =========================================
class HistoryView extends StatefulWidget {
  final String sheetUrl;
  const HistoryView({super.key, required this.sheetUrl});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  Map<String, dynamic>? _historyData;
  List<String> _selectedMonths = [];
  bool _isLoading = false;

  final TextEditingController _yearCtrl = TextEditingController(text: DateTime.now().year.toString());
  final TextEditingController _monthCtrl = TextEditingController(text: DateTime.now().month.toString().padLeft(2, '0'));

  @override
  void initState() {
    super.initState();
    if (widget.sheetUrl.isNotEmpty) _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final String baseUrl = kIsWeb ? 'http://127.0.0.1:5000' : 'http://10.0.2.2:5000';
      final response = await http.get(Uri.parse('$baseUrl/api/history?sheet_url=${Uri.encodeComponent(widget.sheetUrl)}'));
      if (response.statusCode == 200) {
        setState(() { 
          _historyData = json.decode(response.body); 
          List<String> all = List<String>.from(_historyData!['months']);
          if (all.isNotEmpty && _selectedMonths.isEmpty) _selectedMonths = [all.last];
        });
      } else {
        debugPrint("Error: ${response.body}");
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sheetUrl.isEmpty) return const Center(child: Text("請先在第一頁輸入網址", style: TextStyle(fontSize: 18)));
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_historyData == null) return const Center(child: Text("獲取數據失敗"));

    Set<String> categorySet = {};
    for (var m in _selectedMonths) {
      if (_historyData!['data'][m] != null) categorySet.addAll((_historyData!['data'][m] as Map).keys.cast<String>());
    }
    List<String> categoryList = categorySet.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("新增對比月份", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: TextField(controller: _yearCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "年份", border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _monthCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "月份", border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              ElevatedButton(onPressed: () {
                String m = "${_yearCtrl.text}-${_monthCtrl.text.padLeft(2, '0')}";
                if (!_selectedMonths.contains(m)) setState(() => _selectedMonths.add(m));
              }, child: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: _selectedMonths.map((m) => InputChip(label: Text(m), onDeleted: () => setState(() => _selectedMonths.remove(m)))).toList()),
          const SizedBox(height: 40),

          if (_selectedMonths.isNotEmpty) ...[
            const Text("分類消費堆疊對比", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            _buildChart(categoryList),
            const SizedBox(height: 60), // 增加間距避免表格擠上來
            const Text("詳細報表", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildDataTable(categoryList),
          ]
        ],
      ),
    );
  }

  Widget _buildChart(List<String> categories) {
    // 計算所有顯示柱子的最大高度，手動設定 maxY 以移除左上角那個奇怪的數字
    double maxVal = 0;
    for (var cat in categories) {
      double sum = _selectedMonths.fold(0.0, (s, m) => s + (_historyData!['data'][m]?[cat] ?? 0).toDouble());
      if (sum > maxVal) maxVal = sum;
    }

    return SizedBox(
      height: 450, // 加高容器
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal == 0 ? 100 : maxVal * 1.1, // 自動動態計算 maxY，多給 10% 空間
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60, // 增加底部預留空間給文字
                getTitlesWidget: (v, meta) {
                  if (v.toInt() >= categories.length) return const SizedBox();
                  return SideTitleWidget(
                    meta: meta,
                    space: 12,
                    child: Transform.rotate(
                      angle: -0.5, // 旋轉文字避免遮擋
                      child: Text(
                        categories[v.toInt()],
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 45),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // 徹底關掉頂部標題，去掉左上角數字
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: categories.asMap().entries.map((e) {
            double totalY = _selectedMonths.fold(0.0, (sum, m) => sum + (_historyData!['data'][m]?[e.value] ?? 0).toDouble());
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: totalY,
                  width: 32,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  rodStackItems: _buildRodStacks(e.value),
                )
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  List<BarChartRodStackItem> _buildRodStacks(String cat) {
    List<BarChartRodStackItem> items = [];
    double currentHeight = 0;
    for (int i = 0; i < _selectedMonths.length; i++) {
      double val = (_historyData!['data'][_selectedMonths[i]]?[cat] ?? 0).toDouble();
      if (val > 0) {
        items.add(BarChartRodStackItem(currentHeight, currentHeight + val, Colors.primaries[i % Colors.primaries.length].withOpacity(0.85)));
        currentHeight += val;
      }
    }
    return items;
  }

  Widget _buildDataTable(List<String> categories) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.blueGrey[50]),
        columns: [
          const DataColumn(label: Text('分類', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ..._selectedMonths.map((m) => DataColumn(label: Text(m, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))).toList(),
          const DataColumn(label: Text('小計', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ],
        rows: [
          ...categories.map((cat) {
            double rowTotal = 0;
            return DataRow(cells: [
              DataCell(Text(cat, style: const TextStyle(fontSize: 16))),
              ..._selectedMonths.map((m) {
                double v = (_historyData!['data'][m]?[cat] ?? 0).toDouble();
                rowTotal += v;
                return DataCell(Text('\$${v.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16)));
              }),
              DataCell(Text('\$${rowTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue))),
            ]);
          }),
          DataRow(cells: [
            const DataCell(Text('總計', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ..._selectedMonths.map((m) {
              double colTotal = (_historyData!['data'][m] as Map).values.fold(0.0, (s, v) => s + v);
              return DataCell(Text('\$${colTotal.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)));
            }),
            DataCell(Text('\$${_getGrandTotal().toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red))),
          ]),
        ],
      ),
    );
  }

  double _getGrandTotal() {
    double grand = 0;
    for (var m in _selectedMonths) {
      if (_historyData!['data'][m] != null) {
        grand += (_historyData!['data'][m] as Map).values.fold(0.0, (s, v) => s + v);
      }
    }
    return grand;
  }
}