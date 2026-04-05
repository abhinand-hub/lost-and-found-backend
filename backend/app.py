from flask import Flask, request
from flask_cors import CORS
from image_matcher import match_single_item, supabase
import os

app = Flask(__name__)
CORS(app)

@app.route("/match", methods=["POST"])
def match():
    data = request.json
    item_id = data.get("item_id")

    item = supabase.table("items") \
        .select("*") \
        .eq("id", item_id) \
        .execute().data[0]

    match_single_item(item)

    return {"status": "matching done"}

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    app.run(host="0.0.0.0", port=port)