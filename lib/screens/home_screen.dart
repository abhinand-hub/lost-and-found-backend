import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'item_details_screen.dart';
import 'report_dashboard_screen.dart';
import 'notification_screen.dart';
import 'global_notification.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Brand Colors
  static const Color primaryBrandColor = Color(0xFF4F8FBF);
  static const Color secondaryBrandColor = Color(0xFF5FA8D3);
  final supabase = Supabase.instance.client;
  final user = Supabase.instance.client.auth.currentUser;
  String? profileName;
  String? avatarUrl;
  String? lastShownNotificationId;
  @override
  void initState() {
    super.initState();
    _loadProfile();
    listenForNotifications();
  }

  void listenForNotifications() async {
    final user = supabase.auth.currentUser;
    final prefs = await SharedPreferences.getInstance();

    supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user!.id)
        .listen((data) async {
          if (!mounted) return;
          if (data.isEmpty) return;

          final latest = data.last;

          final storedId = prefs.getString("last_notification_id");

          // ❌ already shown before (even after refresh)
          if (latest['id'].toString() == storedId) return;

          // ❌ skip read ones
          if (latest['is_read'] == true) return;

          // ✅ SAVE permanently
          await prefs.setString(
            "last_notification_id",
            latest['id'].toString(),
          );

          // ✅ mark as read
          await supabase
              .from('notifications')
              .update({'is_read': true}).eq('id', latest['id']);

          if (!mounted) return;

          // 🔥 SHOW ONLY ONCE EVER
          GlobalNotification.show(
            context,
            latest['message'] ?? "New notification",
          );
        });
  }

  /// Logout function
  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  /// Navigate to screen
  void _navigateToScreen(Widget screen) {
    Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) {
      _loadProfile(); // refresh sidebar
    });
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle(); // ✅ FIX

    if (!mounted) return;

    if (data != null) {
      setState(() {
        profileName = data['full_name'];
        avatarUrl = data['avatar_url'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Very light gray/off-white
      appBar: AppBar(
        title: const Text(
          "ILOST",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.5,
            color: primaryBrandColor,
            shadows: [
              Shadow(
                offset: Offset(0, 2),
                blurRadius: 6,
                color: Colors.black26,
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: primaryBrandColor,
        // Hamburger icon opens drawer
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: primaryBrandColor),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF48BB78), primaryBrandColor],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationScreen(),
                ),
              );
            },
          )
        ],
      ),
      drawer: _Sidebar(
        primaryColor: primaryBrandColor,
        secondaryColor: secondaryBrandColor,
        username: profileName ?? user?.email ?? "User",
        avatarUrl: avatarUrl,
        onProfileTap: () => _navigateToScreen(const ProfileScreen()),
        onReportTap: () => _navigateToScreen(const ReportDashboardScreen()),
        onLogoutTap: _logout,
      ),
      body: const HomeContent(
        primaryColor: primaryBrandColor,
        secondaryColor: secondaryBrandColor,
      ),
    );
  }
}

/// Professional Sidebar
class _Sidebar extends StatelessWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onProfileTap;
  final VoidCallback onReportTap;
  final VoidCallback onLogoutTap;
  final String username;
  final String? avatarUrl;
  const _Sidebar({
    required this.primaryColor,
    required this.secondaryColor,
    required this.username,
    required this.avatarUrl,
    required this.onProfileTap,
    required this.onReportTap,
    required this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Header with avatar and name
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: primaryColor,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person, color: Colors.white, size: 35)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  username,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          // Menu items
          ListTile(
            leading: Icon(Icons.person_outline, color: primaryColor),
            title: const Text(
              "Profile",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            onTap: onProfileTap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          ),
          ListTile(
            leading: Icon(Icons.report_outlined, color: primaryColor),
            title: const Text(
              "Report Item",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            onTap: onReportTap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          ),
          const Spacer(),
          // Logout at bottom
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              "Logout",
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500, color: Colors.red),
            ),
            onTap: onLogoutTap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Professional Home Content
class HomeContent extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;

  const HomeContent({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  List items = [];
  bool loading = true;
  String searchQuery = "";
  String selectedCategory = "All";
  @override
  void initState() {
    super.initState();
    listenToItems(); // ✅ realtime
  }

  void listenToItems() async {
    // initial load
    final initialData =
        await supabase.from('items').select().order('date', ascending: false);

    if (!mounted) return;

    setState(() {
      items = initialData;
    });

    // realtime listener
    supabase
        .channel('items_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'items',
          callback: (payload) {
            print("CHANGE DETECTED: ${payload.eventType}");

            fetchItems(); // 🔥 refresh instantly
          },
        )
        .subscribe();
  }

  Future<void> fetchItems() async {
    final response =
        await supabase.from('items').select().order('date', ascending: false);

    if (!mounted) return; // ✅ ADD THIS

    setState(() {
      items = response;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    List filteredItems = items.where((item) {
      final title = (item['title'] ?? "").toString().toLowerCase();
      final category = (item['category'] ?? "");

      final matchesSearch = title.contains(searchQuery);
      final matchesCategory =
          selectedCategory == "All" || category == selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverToBoxAdapter(
            child: _HeaderSection(
              primaryColor: widget.primaryColor,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          sliver: SliverToBoxAdapter(
            child: _SimpleSearchBar(
              primaryColor: widget.primaryColor,
              searchController: _searchController,
              onSearch: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(
            child: _CategoriesRow(
              primaryColor: widget.primaryColor,
              selectedCategory: selectedCategory,
              onCategorySelected: (category) {
                setState(() {
                  selectedCategory = category;
                });
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                (context, index) => _LostItemCard(
                      primaryColor: widget.primaryColor,
                      secondaryColor: widget.secondaryColor,
                      item: filteredItems[index],
                    ),
                childCount: filteredItems.length),
          ),
        ),
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final Color primaryColor;
  const _HeaderSection({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Find Lost Items",
          style: GoogleFonts.oswald(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Report and discover lost items near you",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SimpleSearchBar extends StatefulWidget {
  final Color primaryColor;
  final TextEditingController searchController;
  final Function(String) onSearch;

  const _SimpleSearchBar({
    required this.primaryColor,
    required this.searchController,
    required this.onSearch,
  });

  @override
  State<_SimpleSearchBar> createState() => _SimpleSearchBarState();
}

class _SimpleSearchBarState extends State<_SimpleSearchBar> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.searchController,
      onChanged: widget.onSearch,
      onTap: () => setState(() => _isFocused = true),
      onSubmitted: (_) => setState(() => _isFocused = false),
      style: const TextStyle(fontSize: 16, color: Color(0xFF2D3748)),
      decoration: InputDecoration(
        hintText: "Search lost items...",
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Icon(
          Icons.search,
          color: _isFocused ? widget.primaryColor : Colors.grey.shade400,
        ),
        suffixIcon: _isFocused
            ? IconButton(
                icon: Icon(Icons.clear, color: widget.primaryColor),
                onPressed: () {
                  widget.searchController.clear();
                  widget.onSearch("");
                  setState(() => _isFocused = false);
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: widget.primaryColor, width: 2),
        ),
      ),
    );
  }
}

class _CategoriesRow extends StatelessWidget {
  final Color primaryColor;
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const _CategoriesRow({
    required this.primaryColor,
    required this.selectedCategory,
    required this.onCategorySelected,
  });
  @override
  Widget build(BuildContext context) {
    final categories = [
      "All",
      "Electronics",
      "Keys",
      "Wallet",
      "Pets",
      "Others"
    ];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilterChip(
            label: Text(
              categories[index],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: index == 0 ? const Color(0xFF2D3748) : primaryColor,
              ),
            ),
            selected: selectedCategory == categories[index],
            onSelected: (_) {
              onCategorySelected(categories[index]);
            },
            backgroundColor: Colors.grey.shade100,
            selectedColor: Colors.white,
            checkmarkColor: primaryColor,
            side: BorderSide(
              color: index == 0 ? primaryColor : Colors.grey.shade200,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: index == 0 ? 2 : 0,
            shadowColor: primaryColor,
          ),
        ),
      ),
    );
  }
}

class _LostItemCard extends StatelessWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final Map item;
  const _LostItemCard({
    required this.primaryColor,
    required this.secondaryColor,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.grey.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ItemDetailsScreen(item: item),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primaryColor.withOpacity(0.2)),
                ),
                child: item['image_url'] != null && item['image_url'] != ''
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item['image_url'],
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.phone_android,
                        color: primaryColor,
                        size: 32,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'] ?? "Unknown Item",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['location'] ?? "Unknown location",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: 0.7,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(secondaryColor),
                      borderRadius: BorderRadius.circular(8),
                      minHeight: 6,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
