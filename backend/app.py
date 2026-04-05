from flask import Flask, request
from flask_cors import CORS
from image_matcher import match_single_item, supabase
import os
import threading
import time

app = Flask(__name__)
CORS(app)

# ================= API ROUTE =================
@app.route("/match", methods=["POST"])
def match():
    try:
        data = request.json
        item_id = data.get("item_id")

        if not item_id:
            return {"error": "item_id is required"}, 400

        result = supabase.table("items") \
            .select("*") \
            .eq("id", item_id) \
            .execute()

        if not result.data:
            return {"error": "Item not found"}, 404

        item = result.data[0]

        print(f"🔍 Manual match triggered for item: {item_id}")

        match_single_item(item)

        return {"status": "matching done"}

    except Exception as e:
        print("❌ Match API Error:", e)
        return {"error": str(e)}, 500


# ================= BACKGROUND MATCHER =================
def background_matcher():
    while True:
        try:
            items = supabase.table("items") \
                .select("*") \
                .eq("matched", False) \
                .execute().data

            print(f"🔁 Background matching... {len(items)} items")

            for item in items:
                match_single_item(item)

        except Exception as e:
            print("❌ Background Matcher Error:", e)

        time.sleep(30)  # run every 30 seconds


# ================= RUN SERVER =================
if __name__ == "__main__":
    # 🔥 Start background thread
    threading.Thread(target=background_matcher, daemon=True).start()

    port = int(os.environ.get("PORT", 5000))
    print("🚀 Server starting on port", port)

    app.run(host="0.0.0.0", port=port)