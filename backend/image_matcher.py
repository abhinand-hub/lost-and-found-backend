import cv2
import numpy as np
import requests
import time
from supabase import create_client

SUPABASE_URL = "https://twhahfakfvuunofvatbh.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR3aGFoZmFrZnZ1dW5vZnZhdGJoIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2OTg0MzE1NCwiZXhwIjoyMDg1NDE5MTU0fQ.qPvbzCoIAPb2byDu30rHE_UEDFF7qqmVqx-w4wnjQoE"

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)


# ---------------- IMAGE LOADER ----------------
def load_image(url):
    try:
        response = requests.get(url, timeout=10)
        if response.status_code != 200:
            return None

        img_array = np.asarray(bytearray(response.content), dtype=np.uint8)
        return cv2.imdecode(img_array, cv2.IMREAD_COLOR)
    except:
        return None


# ---------------- PREPROCESSING ----------------



# ---------------- IMAGE COMPARISON ----------------
def compare_images(url1, url2):
    print("🖼️ Image1:", url1)
    print("🖼️ Image2:", url2)

    img1 = load_image(url1)
    img2 = load_image(url2)

    if img1 is None or img2 is None:
        print("❌ Image loading failed")
        return 0

    # 🔥 Apply preprocessing
   


# ---------------- MAIN MATCHING LOOP ----------------
def match_single_item(new_item):
    items = supabase.table("items") \
        .select("*") \
        .eq("status", "active") \
        .eq("matched", False) \
        .execute().data

    print("Total items:", len(items))

    for item in items:

        if item["id"] == new_item["id"]:
            continue

        if item["type"] == new_item["type"]:
            continue

        if item["user_id"] == new_item["user_id"]:
            continue

        img1 = new_item.get("image_url")
        img2 = item.get("image_url")

        if not img1 or not img2:
            continue

        print(f"\nChecking {new_item['title']} VS {item['title']}")

        score = compare_images(img1, img2)
        print("Similarity score:", score)

        if score > 70:
            print("✅ MATCH FOUND")

            lost_item = new_item if new_item["type"] == "lost" else item
            found_item = item if new_item["type"] == "lost" else new_item

            # Insert match
            supabase.table("matches").insert({
                "lost_item_id": lost_item["id"],
                "found_item_id": found_item["id"],
                "lost_user_id": lost_item["user_id"],
                "found_user_id": found_item["user_id"],
                "score": score
            }).execute()

            # Update items (ONLY ONCE)
            supabase.table("items").update({
                "status": "matched",
                "matched": True,
                "matched_with": found_item["id"]
            }).eq("id", lost_item["id"]).execute()

            supabase.table("items").update({
                "status": "matched",
                "matched": True,
                "matched_with": lost_item["id"]
            }).eq("id", found_item["id"]).execute()

            # 🔔 Notifications

            # LOST USER
            lost_message = f"🎉 Match found for {lost_item['title']}"

            existing_notification_lost = supabase.table("notifications") \
                .select("*") \
                .eq("user_id", lost_item["user_id"]) \
                .eq("item_id", lost_item["id"]) \
                .eq("message", lost_message) \
                .execute()

            if not existing_notification_lost.data:
                supabase.table("notifications").insert({
                    "user_id": lost_item["user_id"],
                    "message": lost_message,
                    "item_id": lost_item["id"],
                    "is_read": False
                }).execute()

            # FOUND USER
            found_message = f"🎉 Match found for {found_item['title']}"

            existing_notification_found = supabase.table("notifications") \
                .select("*") \
                .eq("user_id", found_item["user_id"]) \
                .eq("item_id", found_item["id"]) \
                .eq("message", found_message) \
                .execute()

            if not existing_notification_found.data:
                supabase.table("notifications").insert({
                    "user_id": found_item["user_id"],
                    "message": found_message,
                    "item_id": found_item["id"],
                    "is_read": False
                }).execute()


