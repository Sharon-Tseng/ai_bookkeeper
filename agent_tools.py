import json
import os
from langchain.tools import tool
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
from langchain_core.runnables import RunnableConfig

# Set up Google Sheets API credentials
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']

@tool("google_sheet_writer")
def write_to_sheets(data_json: str, config: RunnableConfig) -> str:
    """
    將結構化的 JSON 消費數據包含日期、消費場所、消費物品、消費金額與消費類目寫入 Google Sheets
    輸入應該是JSON 字符串，格式如下：{"date": "2024-01-01", "place": "example place", "item": "example item", "spending amount": 123.45, "category": "example category"}
    """
    configurable = config.get("configurable", {})
    spreadsheet_id = configurable.get("SPREADSHEET_ID", None)

    creds_str = os.getenv("GOOGLE_APP_CREDENTIALS", None)

    if not spreadsheet_id:
        return "SPREADSHEET_ID is not configured."
    if not creds_str:
        return "GOOGLE_APP_CREDENTIALS is not configured."
    
    
    try:
        # parse json credentials
        info = json.loads(creds_str)
        info['private_key'] = info['private_key'].replace('\\n', '\n')
        
        creds = Credentials.from_service_account_info(info, scopes=SCOPES)
        service = build('sheets', 'v4', credentials=creds)
        data = json.loads(data_json)
        values = [
            data.get("date",""), 
            data.get("place",""),
            data.get("item",""), 
            data.get("spending amount",0), 
            data.get("category","others")
        ]

        # Write data to Google Sheets (last row)
        result = service.spreadsheets().values().append(
            spreadsheetId=spreadsheet_id,
            range="Sheet1!A:E",
            valueInputOption="RAW",
            insertDataOption="INSERT_ROWS",
            body={"values": [values]}
        ).execute()
    
        return f"Successfully wrote data: {result.get('updates').get('updatedCells')} cells updated."
    
    except Exception as e:
        return f"Error writing to Google Sheets: {str(e)}" 
    
@tool("google_sheet_analyzer")
def analyze_sheets(config: RunnableConfig) -> str:
    """
    讀取並分析 Google Sheets 中的消費數據，並生成消費報告以及提供省錢建議
    """
    configurable = config.get("configurable", {})
    spreadsheet_id = configurable.get("SPREADSHEET_ID", None)
    creds_str = os.getenv("GOOGLE_APP_CREDENTIALS", None)

    if not spreadsheet_id:
        return "SPREADSHEET_ID is not configured."
    if not creds_str:
        return "GOOGLE_APP_CREDENTIALS is not configured."
    
    try:
        info = json.loads(creds_str)
        info['private_key'] = info['private_key'].replace('\\n', '\n')
        
        creds = Credentials.from_service_account_info(info, scopes=SCOPES)
        service = build('sheets', 'v4', credentials=creds)

        # Read data from Google Sheets
        result = service.spreadsheets().values().get(
            spreadsheetId=spreadsheet_id,
            range="Sheet1!A:E"
        ).execute()
        values = result.get('values', [])

        if not values or len(values) < 2:
            return "No data found in the spreadsheet."

        # Summarize spending
        summary = {}
        for row in values:
            if len(row) >= 2:
                try:
                    amount = float(str(row[0]).replace('$', '').replace(',', ''))
                    category = row[1]
                    summary[category] = summary.get(category, 0) + amount
                except ValueError:
                    continue
        
        report = "Monthly Spending Report:\n"
        for cat, amt in summary.items():
            report += f"- {cat}: ${amt:.2f}\n"
        return report
    
    except Exception as e:
        return f"Error analyzing Google Sheets: {str(e)}"