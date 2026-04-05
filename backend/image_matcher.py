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
def preprocess_image(img):
    # 1. Resize
    img = cv2.resize(img, (400, 400))

    # 2. Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # 3. Noise Reduction
    gray = cv2.GaussianBlur(gray, (5, 5), 0)

    # 4. Normalization
    gray = cv2.equalizeHist(gray)

    # 5. Background reduction (center crop)
    h, w = gray.shape
    gray = gray[int(h * 0.1):int(h * 0.9), int(w * 0.1):int(w * 0.9)]

    # 6. Edge Enhancement
    edges = cv2.Canny(gray, 100, 200)

    return edges


# ---------------- IMAGE COMPARISON ----------------
def compare_images(url1, url2):
    img1 = load_image(url1)
    img2 = load_image(url2)

    if img1 is None or img2 is None:
        return 0

    # 🔥 Apply preprocessing
    proc1 = preprocess_image(img1)
    proc2 = preprocess_image(img2)

    orb = cv2.ORB_create(nfeatures=1500)

    kp1, des1 = orb.detectAndCompute(proc1, None)
    kp2, des2 = orb.detectAndCompute(proc2, None)

    if des1 is None or des2 is None:
        return 0

    bf = cv2.BFMatcher(cv2.NORM_HAMMING)
    matches = bf.knnMatch(des1, des2, k=2)

    good = []
    for m, n in matches:
        if m.distance < 0.75 * n.distance:
            good.append(m)

    return len(good)


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


