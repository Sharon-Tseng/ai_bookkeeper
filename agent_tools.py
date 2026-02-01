import json
import os
from langchain.tools import tool
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
from langchain_core.runnables import RunnableConfig
from datetime import datetime
from collections import defaultdict

# Set up Google Sheets API credentials
SCOPES = ['https://www.googleapis.com/auth/spreadsheets']

# Helper function to write data to Google Sheets
def load_raw_expense_data(spreadsheet_id: str):
    creds = os.getenv("GOOGLE_APP_CREDENTIALS", None)
    info = json.loads(creds)
    info['private_key'] = info['private_key'].replace('\\n', '\n')
    creds = Credentials.from_service_account_info(info, scopes=SCOPES)
    service = build('sheets', 'v4', credentials=creds)

    result = service.spreadsheets().values().get(
        spreadsheetId=spreadsheet_id,
        range="Sheet1!A:E"
    ).execute()
    values = result.get('values', [])
    
    monthly_data = defaultdict(lambda: defaultdict(float))
    for row in values[1:]:
        if len(row) < 5:
            continue
        data_str, _, _, amount_str, category = row[:5]
        amount = float(str(amount_str).replace('$', '').replace(',', ''))

        month_key = ""
        for fmt in ("%Y/%m/%d", "%Y-%m-%d", "%Y/%m", "%Y-%m", "%d/%m/%Y", "%d-%m-%Y"):
            try:
                date_obj = datetime.strptime(data_str, fmt)
                month_key = date_obj.strftime("%Y-%m")
                break
            except ValueError:
                continue

        if month_key:
            monthly_data[month_key][category] += amount

    sorted_months = sorted(monthly_data.keys())
    return {"months": sorted_months, "data": {month: monthly_data[month] for month in sorted_months}}


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
def analyze_expenses(config: RunnableConfig) -> str:
    """
    讀取 Google Sheets 並生成每月消費文字報告，用於前端 chart 顯示。
    格式:
    Monthly Spending Report (YYYY-MM):
    - 類別1: $金額
    - 類別2: $金額
    總消費: $金額
    """
    spreadsheet_id = config.get("configurable", {}).get("SPREADSHEET_ID")
    raw_data = load_raw_expense_data(spreadsheet_id)

    if "error" in raw_data:
        return raw_data["error"]

    months = raw_data["months"]
    if not months:
        return "No data available."

    latest_month = months[-1]
    month_data = raw_data["data"].get(latest_month, {})

    total_spending = sum(month_data.values())

    report = f"Monthly Spending Report ({latest_month}):\n"
    for cat, amt in month_data.items():
        report += f"- {cat}: ${amt:.2f}\n"
    report += f"Total Spending: ${total_spending:.2f}\n"

    return report
    
@tool("expense_data_tool")
def get_expense_data_json(config: RunnableConfig) -> str:
    """
    從 Google Sheets 讀取消費資料，並整理為 JSON 方便 AI 分析。
    回傳格式:
    {
        "months": ["2024-12", "2025-01"],
        "data": {
            "2024-12": {"餐飲": 2500, "交通": 900},
            "2025-01": {"餐飲": 3000, "交通": 1200}
        }
    }
    """
    spreadsheet_id = config.get("configurable", {}).get("SPREADSHEET_ID")
    data = load_raw_expense_data(spreadsheet_id)
    
    return json.dumps(data, ensure_ascii=False)