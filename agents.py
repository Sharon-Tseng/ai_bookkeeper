import os
import base64
from langchain_google_genai import ChatGoogleGenerativeAI
from langgraph.prebuilt import create_react_agent
from agent_tools import write_to_sheets
from io import BytesIO
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()
# Import API key
os.environ["GOOGLE_API_KEY"] = os.getenv("GOOGLE_API_KEY")

gemini_llm = ChatGoogleGenerativeAI(model="gemini-flash-latest", temperature=0)
bookkeeper_graph_agent = create_react_agent(gemini_llm, [write_to_sheets])

class AccountAgents:
    @staticmethod
    def run_bookkeeper(image_data, spreadsheet_id):
        buffered = BytesIO()
        image_data.save(buffered, format="PNG")
        image_data = base64.b64encode(buffered.getvalue()).decode("utf-8")

        inputs = {
            "messages": [
                ("user",
                 [{"type": "text", "text": "請分析這張收據照片，提取日期、項目、金額、分類，並使用 write_to_sheets 工具存入 Google Sheets。"},
                  {"type": "image_url", 
                   "image_url": {"url": f"data:image/png;base64,{image_data}"}
                  }
                 ]
                )
            ]
        }

        config = {
            "configurable": {
                "SPREADSHEET_ID": spreadsheet_id
            }
        }

        response = bookkeeper_graph_agent.invoke(inputs, config=config)
        return response["messages"][-1].content
    
    # @staticmethod
    # def expense_analysis