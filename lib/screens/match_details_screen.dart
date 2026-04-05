import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'global_notification.dart';
import 'package:url_launcher/url_launcher.dart';

class MatchDetailsScreen extends StatelessWidget {
  final Map myItem;
  final Map matchedItem;
  final int score;

  const MatchDetailsScreen({
    super.key,
    required this.myItem,
    required this.matchedItem,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    /// ⭐ SIMILARITY CALCULATION
    double similarity = (score / 150).clamp(0, 1);
    int percent = (similarity * 100).toInt();

    /// OPTIONAL COLOR LOGIC
    Color getColor(int percent) {
      if (percent > 80) return Colors.green;
      if (percent > 60) return Colors.orange;
      return Colors.red;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Match Found 🎉"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// ⭐ MODEL MATCH CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  /// ⭐ IMAGES + SCORE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      /// LEFT IMAGE
                      Column(
                        children: [
                          const Text("User Upload"),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              myItem['image_url'] ?? '',
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.image, size: 80),
                            ),
                          ),
                        ],
                      ),

                      /// ⭐ SCORE CENTER
                      Column(
                        children: [
                          Text(
                            "$percent%",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: getColor(percent),
                            ),
                          ),
                          const Text("Similarity"),
                        ],
                      ),

                      /// RIGHT IMAGE
                      Column(
                        children: [
                          const Text("Database Match"),
                          const SizedBox(height: 8),
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  matchedItem['image_url'] ?? '',
                                  height: 100,
                                  width: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.image, size: 80),
                                ),
                              ),

                              /// ✅ MATCH ICON
                              const Positioned(
                                bottom: 4,
                                right: 4,
                                child: CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.green,
                                  child: Icon(Icons.check,
                                      size: 16, color: Colors.white),
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// ⭐ PROGRESS BAR
                  LinearProgressIndicator(
                    value: similarity,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(10),
                    backgroundColor: Colors.grey.shade300,
                    color: getColor(percent),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Matched Item",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// ⭐ DETAILS
            Text(
              "📍 Location: ${matchedItem['location']}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              "📞 Contact: ${matchedItem['contact']}",
              style: const TextStyle(fontSize: 16),
            ),

            const Spacer(),

            /// ⭐ BUTTONS
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.call),
                    label: const Text("Call Owner"),
                    onPressed: () {
                      final phone = matchedItem['contact'];

                      if (phone == null || phone.toString().isEmpty) {
                        GlobalNotification.show(context, "No contact number ❌");
                        return;
                      }

                      showModalBottomSheet(
                        context: context,
                        builder: (_) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.call),
                              title: const Text("Call"),
                              onTap: () async {
                                final Uri uri = Uri.parse("tel:$phone");
                                await launchUrl(uri);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.message),
                              title: const Text("SMS"),
                              onTap: () async {
                                final Uri uri = Uri.parse("sms:$phone");
                                await launchUrl(uri);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text("Mark Recovered"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () async {
                      await supabase.from('items').update(
                          {'status': 'recovered'}).eq('id', myItem['id']);

                      await supabase.from('items').update(
                          {'status': 'recovered'}).eq('id', matchedItem['id']);

                      if (!context.mounted) return;

                      // ✅ SHOW TOP NOTIFICATION HERE
                      GlobalNotification.show(
                        context,
                        "Item marked as recovered ✅",
                      );

                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
