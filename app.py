from flask import Flask, json, render_template, request, redirect, url_for
import PIL.Image as Image
import re
from agent_tools import load_raw_expense_data
from agents import AccountAgents

def get_spreadsheet_id(url):
    pattern = r"/d/([a-zA-Z0-9-_]+)"
    match = re.search(pattern, url)
    return match.group(1) if match else None

app = Flask(__name__)

@app.route('/')
def welcome():
    return render_template('welcome.html', result=None, sheet_url="")

@app.route('/app', methods=['GET', 'POST'])
def index():
    result = None
    sheet_url = ""
    if request.method == 'POST':
        sheet_url = request.form.get('sheet_url')
        file = request.files.get('receipt')
        
        spreadsheet_id = get_spreadsheet_id(sheet_url)
        if file and spreadsheet_id:
            img = Image.open(file.stream)
            try:
                result = AccountAgents.run_bookkeeper(img, spreadsheet_id)
            except Exception as e:
                result = f"Error: {str(e)}"
        else:
            result = "Error: Invalid URL or No File."

    return render_template('add_record.html', result=result, sheet_url=sheet_url)

@app.route('/clear')
def clear_all():
    return redirect(url_for('add_record'))

@app.route('/view_history', methods=['GET', 'POST'])
def view_history():
    if request.method == 'POST':
        sheet_url = request.form.get('sheet_url')
    else:
        sheet_url = request.args.get('sheet_url', '')

    if not sheet_url:
        return render_template('view_history.html', history = {}, sheet_url="")

    spreadsheet_id = get_spreadsheet_id(sheet_url)
    if not spreadsheet_id:
        return "Error: Invalid Google Sheet URL."

    raw_data = load_raw_expense_data(spreadsheet_id)

    # Get monthly data for chart
    months = raw_data.get("months", [])
    data = raw_data.get("data", {})

    # Transform data to JSON format for charting
    return render_template('view_history.html',history= data, sheet_url=sheet_url)

@app.route('/clear_history')
def clear_history():
    return redirect(url_for('view_history'))

if __name__ == '__main__':
    print("Starting Flask Server at http://127.0.0.1:5000")
    app.run(debug=True, port=5000)