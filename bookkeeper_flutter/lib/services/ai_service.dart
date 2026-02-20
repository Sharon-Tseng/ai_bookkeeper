import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';

class AIService {
  // TODO: Replace with your actual API Key or use --dart-define=GOOGLE_API_KEY=...
  static const String _apiKey = 'AIzaSyAAm6-v4RaX4z5Ik30gQbuFqVw1f2QHXfE'; 

  late final GenerativeModel _model;

  AIService() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash', 
      apiKey: _apiKey,
    );
  }

  Future<Map<String, dynamic>> analyzeReceipt(Uint8List imageBytes) async {
    final prompt = TextPart("""
請分析這張收據照片，提取日期、項目、金額、分類。
日期可能分為以下兩種:
1. 格式為 YYYY/MM/DD 或 YYYY-MM-DD
2. 格式為 YYYY/MM 或 YYYY-MM
3. 格式為 DD/MM/YYYY 或 DD-MM-YYYY

將提取出的結果整理成 JSON 格式，包含以下欄位：
- date: 日期字串 (YYYY-MM-DD)
- items: 陣列，每個元素包含：
  - name: 項目名稱
  - amount: 金額 (數字)
  - category: 分類 (例如: 餐飲, 交通, 購物, 娛樂, 其他)

請只回傳純 JSON 字串，不要包含 Markdown 標記 (```json ... ```)。
""");

    final imagePart = DataPart('image/jpeg', imageBytes);

    try {
      final response = await _model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      String? responseText = response.text;
      if (responseText == null) {
        throw Exception("Empty response from AI");
      }

      // Clean up markdown code blocks if present
      responseText = responseText.replaceAll('```json', '').replaceAll('```', '').trim();

      return jsonDecode(responseText);
    } catch (e) {
      print("AI Analysis Error: $e");
      rethrow;
    }
  }
}
