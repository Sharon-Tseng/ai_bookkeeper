from flask import Flask, render_template_string, request
import io
import PIL.Image as Image
import re
from agents import AccountAgents

app = Flask(__name__)
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title> Sharon's AI Bookkeeper </title>
    <style>
        body { font-family: sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; line-height: 1.6; }
        .box { border: 1px solid #ccc; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        input[type="text"], input[type="file"] { width: 100%; margin: 10px 0; padding: 10px; }
        button { background: #007bff; color: white; border: none; padding: 10px 20px; cursor: pointer; border-radius: 5px; }
        .result { background: #f4f4f4; padding: 15px; border-left: 5px solid #007bff; white-space: pre-wrap; }
    </style>
</head>
<body>
    <h1>📸 My AI Bookkeeper </h1>
    
    <div class="box">
        <h3>Step 1: Configuration</h3>
        <form method="POST" enctype="multipart/form-data">
            <label>Google Sheet URL:</label>
            <input type="text" name="sheet_url" placeholder="Paste URL here..." required value="{{ sheet_url }}">
            <p><small>Service Email: <code>bookkeeper-agent@utopian-nimbus-482915-d0.iam.gserviceaccount.com</code></small></p>
            
            <hr>
            <h3>Step 2: Upload Receipt</h3>
            <input type="file" name="receipt" accept="image/*" required>
            <br><br>
            <button type="submit">🚀 Process </button>
        </form>
    </div>

    {% if result %}
    <div class="box">
        <h3>Result:</h3>
        <div class="result">{{ result }}</div>
        <div class="button-container" style="margin-top: 15px;">
            <button type = "button" onclick="window.location.href='{{ sheet_url }}'">Open Google Sheet</button>
            <button type = "button" onclick="window.location.href='/'">Process Another Receipt</button>
        </div>
       


    </div>
    {% endif %}
</body>
</html>
"""

def get_spreadsheet_id(url):
    pattern = r"/d/([a-zA-Z0-9-_]+)"
    match = re.search(pattern, url)
    return match.group(1) if match else None

@app.route('/', methods=['GET', 'POST'])
def index():
    result = None
    sheet_url = ""
    if request.method == 'POST':
        sheet_url = request.form.get('sheet_url')
        file = request.files.get('receipt')
        
        spreadsheet_id = get_spreadsheet_id(sheet_url)
        if file and spreadsheet_id:
            # Standard Flask file processing
            img = Image.open(file.stream)
            try:
                # Call your existing agents logic
                result = AccountAgents.run_bookkeeper(img, spreadsheet_id)
            except Exception as e:
                result = f"Error: {str(e)}"
        else:
            result = "Error: Invalid URL or No File."

    return render_template_string(HTML_TEMPLATE, result=result, sheet_url=sheet_url)

if __name__ == '__main__':
    print("Starting Flask Server at http://127.0.0.1:5000")
    app.run(debug=True, port=5000)