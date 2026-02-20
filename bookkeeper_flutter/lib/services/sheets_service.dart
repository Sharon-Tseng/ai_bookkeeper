import 'dart:convert';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'secrets.dart';

class SheetsService {
  static const _scopes = [sheets.SheetsApi.spreadsheetsScope];

  Future<sheets.SheetsApi> _getSheetsApi() async {
    final accountCredentials = ServiceAccountCredentials.fromJson(googleServiceAccountJson);
    final client = await clientViaServiceAccount(accountCredentials, _scopes);
    return sheets.SheetsApi(client);
  }

  // Extract spreadsheet ID from URL
  String? getSpreadsheetId(String url) {
    RegExp regExp = RegExp(r"/d/([a-zA-Z0-9-_]+)");
    var match = regExp.firstMatch(url);
    return match?.group(1);
  }

  Future<void> writeToSheet(String spreadsheetId, Map<String, dynamic> data) async {
    final api = await _getSheetsApi();
    
    // Data format from AI: {date: "YYYY-MM-DD", items: [{name: "", amount: 10, category: ""}, ...]}
    String date = data['date'] ?? '';
    List items = data['items'] ?? [];

    for (var item in items) {
       // Row format: Date, Item, Amount, Category
       // Assuming columns A, B, C, D
       var row = [
         date,
         '', // Place (keep empty for now or extract if available)
         item['name'] ?? '',
         item['amount'] ?? 0,
         item['category'] ?? ''
       ];

       var valueRange = sheets.ValueRange()..values = [row];
       
       await api.spreadsheets.values.append(
         valueRange, 
         spreadsheetId, 
         'Sheet1!A:E', 
         valueInputOption: 'USER_ENTERED'
       );
    }
  }

  Future<Map<String, dynamic>> loadRawExpenseData(String spreadsheetId) async {
    try {
      final api = await _getSheetsApi();
      final result = await api.spreadsheets.values.get(spreadsheetId, 'Sheet1!A:E');
      final values = result.values;

      if (values == null || values.isEmpty) {
        return {"months": [], "data": {}};
      }

         // Try to detect header row for column mapping
         final headerRow = values.isNotEmpty ? values.first : [];
         int dateIndex = -1;
         int amountIndexHeader = -1;
         int categoryIndexHeader = -1;

         String normalizeHeader(dynamic value) {
            return value.toString().trim().toLowerCase();
         }

         bool headerMatches(String header, List<String> candidates) {
            for (final candidate in candidates) {
               if (header == candidate) return true;
               if (header.contains(candidate)) return true;
            }
            return false;
         }

         for (int i = 0; i < headerRow.length; i++) {
            final header = normalizeHeader(headerRow[i]);
            if (dateIndex == -1 && headerMatches(header, ['date', '日期', '交易日期'])) {
               dateIndex = i;
            }
            if (amountIndexHeader == -1 && headerMatches(header, ['amount', 'spending amount', '金額', '金额', '支出', '花費'])) {
               amountIndexHeader = i;
            }
            if (categoryIndexHeader == -1 && headerMatches(header, ['category', '分類', '类別', '类别', '類別'])) {
               categoryIndexHeader = i;
            }
         }

         final bool hasHeader = dateIndex != -1 || amountIndexHeader != -1 || categoryIndexHeader != -1;
         final rowsToProcess = values.length > 1 && hasHeader ? values.sublist(1) : values;

      // { "YYYY-MM": { "Category": Amount } }
      Map<String, Map<String, double>> monthlyData = {};
      Set<String> months = {};

         for (var row in rowsToProcess) {
            if (row.isEmpty) continue;

      final int effectiveDateIndex = dateIndex == -1 ? 0 : dateIndex;
      if (row.length <= effectiveDateIndex) continue;
      String dateStr = row[effectiveDateIndex].toString();
        // Skip header if it was mixed in data or invalid date
        if (dateStr.toLowerCase() == 'date') continue;

        // Try parse date
        try {
          // normalize "2024/01/31" to "2024-01-31" to extract YYYY-MM
          dateStr = dateStr.replaceAll('/', '-');
          List<String> parts = dateStr.split('-');
          String monthKey = "";
          if (parts.length >= 2) {
            // Assume YYYY-MM-DD or DD-MM-YYYY
            // If first part is 4 digits, it's year.
            if (parts[0].length == 4) {
              monthKey = "${parts[0]}-${parts[1].padLeft(2, '0')}";
            } else if (parts.length == 3 && parts[2].length == 4) {
               // DD-MM-YYYY
               monthKey = "${parts[2]}-${parts[1].padLeft(2, '0')}";
            } else {
               // fallback
               monthKey = dateStr.substring(0, 7); 
            }
          } else {
             continue;
          }

          months.add(monthKey);
          if (!monthlyData.containsKey(monthKey)) {
            monthlyData[monthKey] = {};
          }

               double amount = 0.0;
               String category = "Uncategorized";

               int effectiveAmountIndex = amountIndexHeader;
               int effectiveCategoryIndex = categoryIndexHeader;

               bool isAmount(dynamic val) {
                  if (val == null) return false;
                  final cleaned = val.toString().replaceAll(RegExp(r'[^0-9.]'), '');
                  return cleaned.isNotEmpty && double.tryParse(cleaned) != null;
               }

               // Header-based mapping if available
               if (effectiveAmountIndex != -1 && row.length > effectiveAmountIndex) {
                  try {
                     amount = double.parse(row[effectiveAmountIndex].toString().replaceAll(RegExp(r'[^0-9.]'), ''));
                  } catch (_) {}
               }
               if (effectiveCategoryIndex != -1 && row.length > effectiveCategoryIndex) {
                  category = row[effectiveCategoryIndex].toString();
               }

               // Heuristic fallback when headers are missing or empty
               if (effectiveAmountIndex == -1 || amount == 0.0) {
                  if (row.length > 3 && isAmount(row[3])) {
                     effectiveAmountIndex = 3;
                  } else if (row.length > 2 && isAmount(row[2])) {
                     effectiveAmountIndex = 2;
                  }

                  if (effectiveAmountIndex != -1) {
                     try {
                        amount = double.parse(row[effectiveAmountIndex].toString().replaceAll(RegExp(r'[^0-9.]'), ''));
                     } catch (_) {}
                     if (row.length > effectiveAmountIndex + 1) {
                        category = row[effectiveAmountIndex + 1].toString();
                     }
                  }
               }

               // Final sanity for category
               final catClean = category.replaceAll(RegExp(r'[^0-9.]'), '');
               if (category.trim().isEmpty || DateTime.tryParse(category.replaceAll('/', '-')) != null) {
                  category = "Uncategorized";
               } else if (catClean.isNotEmpty && double.tryParse(catClean) != null) {
                  // Category looks numeric: don't display it as category.
                  category = "Uncategorized";
               }

          monthlyData[monthKey]![category] = (monthlyData[monthKey]![category] ?? 0.0) + amount;

        } catch (e) {
          print("Error processing row $row: $e");
        }
      }

      List<String> sortedMonths = months.toList()..sort();
      
      return {
        "months": sortedMonths,
        "data": monthlyData
      };

    } catch (e) {
       print("Error loading sheet data: $e");
       return {"months": [], "data": {}};
    }
  }
}
