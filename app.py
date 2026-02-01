import os
from flask import Flask, json, render_template, request, redirect, url_for
import PIL.Image as Image
import re
import sqlite3
from agent_tools import load_raw_expense_data
from agents import AccountAgents

def get_spreadsheet_id(url):
    pattern = r"/d/([a-zA-Z0-9-_]+)"
    match = re.search(pattern, url)
    return match.group(1) if match else None

def init_db():
    db_path = '/tmp/bookkeeper.db' if os.environ.get('VERCEL') else 'bookkeeper.db'
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    # Store user-sheet relationships
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS user_sheets(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            sheet_url TEXT NOT NULL,
            UNIQUE(username, sheet_url)
        )''')
    conn.commit()
    conn.close()
init_db()

def save_user_sheet(username, sheet_url):
    db_path = '/tmp/bookkeeper.db' if os.environ.get('VERCEL') else 'bookkeeper.db'
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    try:
        cursor.execute('''
            INSERT INTO user_sheets (username, sheet_url)
            VALUES (?, ?)
        ''', (username, sheet_url))
        conn.commit()
    except sqlite3.IntegrityError:
        pass
    conn.close()

def get_user_sheets(username):
    db_path = '/tmp/bookkeeper.db' if os.environ.get('VERCEL') else 'bookkeeper.db'
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('SELECT sheet_url FROM user_sheets WHERE username = ?', (username,))
    urls = [row[0] for row in cursor.fetchall()]
    conn.close()
    return urls
    
# Flask application setup
app = Flask(__name__)

@app.route('/')
def welcome():
    return render_template('welcome.html', result=None, sheet_url="")

@app.route('/app', methods=['GET', 'POST'])
def index():
    result = None
    sheet_url = request.args.get('sheet_url', '')
    username= 'default_user'  
    saved_sheets = get_user_sheets(username)

    if request.method == 'POST':
        sheet_url = request.form.get('sheet_url')
        file = request.files.get('receipt')
        
        if sheet_url:
            save_user_sheet(username, sheet_url)
            saved_sheets = get_user_sheets(username) 

        spreadsheet_id = get_spreadsheet_id(sheet_url)
        if file and spreadsheet_id:
            img = Image.open(file.stream)
            try:
                result = AccountAgents.run_bookkeeper(img, spreadsheet_id)
            except Exception as e:
                result = f"Error: {str(e)}"
        else:
            result = "Error: Invalid URL or No File."

    return render_template('add_record.html', result=result, sheet_url=sheet_url, saved_sheets=saved_sheets)

@app.route('/clear')
def clear_all():
    return redirect(url_for('index'))

@app.route('/view_history', methods=['GET', 'POST'])
def view_history():
    username = request.args.get('username', 'default_user') 
    saved_sheets = get_user_sheets(username)
    
    sheet_url = ""
    if request.method == 'POST':
        sheet_url = request.form.get('sheet_url')
        if sheet_url:
            save_user_sheet(username, sheet_url)
            saved_sheets = get_user_sheets(username)
    else:
        sheet_url = request.args.get('sheet_url', '')

    if not sheet_url:
        return render_template('view_history.html', history={}, sheet_url="", saved_sheets=saved_sheets, total_trend={})

    spreadsheet_id = get_spreadsheet_id(sheet_url)
    if not spreadsheet_id:
        return "Error: Invalid Google Sheet URL."

    raw_data = load_raw_expense_data(spreadsheet_id)

    # Get monthly data for chart
    months = raw_data.get("months", [])
    data = raw_data.get("data", {})

    # Calculate total spending trend
    total_trend = {month: sum(categories.values()) for month, categories in data.items()}

    # Transform data to JSON format for charting
    return render_template('view_history.html', history=data, sheet_url=sheet_url, saved_sheets=saved_sheets, total_trend=total_trend)

@app.route('/clear_history')
def clear_history():
    return redirect(url_for('view_history'))

if __name__ == '__main__':
    print("Starting Flask Server at http://127.0.0.1:5000")
    app.run(debug=True, port=5000)