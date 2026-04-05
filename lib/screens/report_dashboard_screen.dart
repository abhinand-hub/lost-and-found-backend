import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'report_item_screen.dart';
import 'match_details_screen.dart';
import 'global_notification.dart';

class ReportDashboardScreen extends StatefulWidget {
  const ReportDashboardScreen({super.key});

  @override
  State<ReportDashboardScreen> createState() => _ReportDashboardScreenState();
}

class _ReportDashboardScreenState extends State<ReportDashboardScreen> {
  final supabase = Supabase.instance.client;

  List reports = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();

    final user = supabase.auth.currentUser;

    supabase
        .from('items')
        .stream(primaryKey: ['id'])
        .eq('user_id', user!.id)
        .listen((data) {
          if (!mounted) return;

          setState(() {
            reports = data;
            loading = false;
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Reports"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("New Report"),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (_) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.search_off),
                      title: const Text("Report Lost Item"),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ReportItemScreen(type: "lost"),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: const Text("Report Found Item"),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ReportItemScreen(type: "found"),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final item = reports[index];

                return Card(
                  color: item['status'] == 'matched'
                      ? Colors.green.shade50
                      : item['status'] == 'recovered'
                          ? Colors.blueGrey.shade50
                          : null,
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: item['image_url'] != null
                        ? Image.network(item['image_url'], width: 60)
                        : const Icon(Icons.image),
                    title: Text(item['title']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${item['category']} • ${item['location']}"),
                        const SizedBox(height: 4),

                        /// ⭐ STATUS LABEL
                        if (item['status'] == 'matched' &&
                            item['matched'] == true)
                          const Row(
                            children: [
                              Icon(Icons.verified,
                                  color: Colors.green, size: 18),
                              SizedBox(width: 6),
                              Text(
                                "Match Found",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        else if (item['status'] == 'recovered')
                          const Row(
                            children: [
                              Icon(Icons.inventory_2,
                                  color: Colors.blueGrey, size: 18),
                              SizedBox(width: 6),
                              Text(
                                "Recovered",
                                style: TextStyle(
                                  color: Colors.blueGrey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        else
                          const Text(
                            "AI is searching...",
                            style: TextStyle(color: Colors.grey),
                          ),
                      ],
                    ),

                    /// ⭐ TAP LOGIC
                    onTap: () async {
                      if (item['status'] != 'matched') {
                        GlobalNotification.show(
                            context, "AI still searching match");

                        return;
                      }

                      final matchList = await supabase
                          .from('matches')
                          .select()
                          .or('lost_item_id.eq.${item['id']},found_item_id.eq.${item['id']}')
                          .limit(1);

                      if (matchList.isEmpty) {
                        GlobalNotification.show(
                            context, "Match data not ready");

                        return;
                      }

                      final match = matchList.first;

                      final otherItemId = match['lost_item_id'] == item['id']
                          ? match['found_item_id']
                          : match['lost_item_id'];

                      final otherItem = await supabase
                          .from('items')
                          .select()
                          .eq('id', otherItemId)
                          .maybeSingle();

                      if (otherItem == null) {
                        GlobalNotification.show(
                            context, "Matched item not accessible");
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MatchDetailsScreen(
                            myItem: item,
                            matchedItem: otherItem,
                            score: match['score'],
                          ),
                        ),
                      );
                    },

                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportItemScreen(
                              item: item,
                              type: item['type'],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
