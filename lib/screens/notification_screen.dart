import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final supabase = Supabase.instance.client;

  List notifications = [];
  List previousNotifications = [];

  bool loading = true;
  bool isInitialLoad = true;
  String? lastShownNotificationId;
  // ✅ SHOW TOP NOTIFICATION

  @override
  void initState() {
    super.initState();
    fetchNotifications();
    setupRealtime();
  }

  // ✅ FETCH DATA
  Future fetchNotifications() async {
    final user = supabase.auth.currentUser;

    final data = await supabase
        .from('notifications')
        .select()
        .eq('user_id', user!.id)
        .order('created_at', ascending: false);

    if (!mounted) return;

    setState(() {
      notifications = data;
      previousNotifications = data;
      loading = false;
    });
  }

  // ✅ REALTIME LISTENER
  void setupRealtime() {
    final user = supabase.auth.currentUser;

    supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user!.id)
        .listen((data) {
          if (!mounted) return;

          if (data.isEmpty) return;

          final latest = data.first;

          // ❌ Ignore first load (refresh case)
          if (isInitialLoad) {
            isInitialLoad = false;

            lastShownNotificationId = latest['id'];
            previousNotifications = data;
            return;
          }

          // ✅ Only show if NEW notification
          if (latest['id'] != lastShownNotificationId) {
            lastShownNotificationId = latest['id'];
            markAsRead(latest['id']);
          }

          setState(() {
            notifications = data;
          });

          previousNotifications = data;
        });
  }

  // ✅ MARK AS READ
  Future markAsRead(String id) async {
    await supabase.from('notifications').update({'is_read': true}).eq('id', id);
    fetchNotifications();
  }

  // ✅ FORMAT TIME
  String formatTime(String time) {
    final dateTime = DateTime.parse(time).toLocal();
    return "${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(
                  child: Text(
                    "No notifications yet 😴",
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    final isRead = n['is_read'] ?? false;

                    return InkWell(
                      onTap: () => markAsRead(n['id']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isRead
                              ? Colors.white
                              : Colors.green.withOpacity(0.08),
                          border: const Border(
                            bottom: BorderSide(color: Colors.grey, width: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  isRead ? Colors.grey.shade300 : Colors.green,
                              child: const Icon(
                                Icons.notifications,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n['message'] ?? '',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatTime(n['created_at']),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

//////////////////////////////////////////////////////////////
// ✅ THIS MUST BE OUTSIDE (IMPORTANT FIX)
//////////////////////////////////////////////////////////////

class _TopNotificationWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _TopNotificationWidget({
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<Offset> slide;
  late Animation<double> fade;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    ));

    fade = Tween<double>(begin: 0, end: 1).animate(controller);

    controller.forward();

    Future.delayed(const Duration(seconds: 3), () async {
      await controller.reverse();
      widget.onDismiss();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: slide,
        child: FadeTransition(
          opacity: fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade600,
                    Colors.green.shade400,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await controller.reverse();
                      widget.onDismiss();
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
