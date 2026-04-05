import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'login_page.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isUploading = false;
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _isEditing = false;

  String? _avatarUrl;
  XFile? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ================= LOAD PROFILE =================
  Future<void> _loadProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        setState(() {
          _nameController.text = data['full_name'] ?? '';
          _usernameController.text = data['username'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _avatarUrl = data['avatar_url'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ================= PICK IMAGE =================
  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // 🔥 first level compression
    );

    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() {
          webImage = bytes;
        });
      } else {
        File file = File(picked.path);

        // 🔥 compress here
        File compressed = await compressImage(file);

        setState(() {
          imageFile = compressed;
        });
      }
    }
  }

  // ================= UPLOAD IMAGE =================
  Future<void> _uploadImage() async {
    try {
      setState(() => _isUploading = true);

      final user = supabase.auth.currentUser;
      final fileName =
          '${user!.id}_${DateTime.now().millisecondsSinceEpoch}.png';

      final bytes = await _imageFile!.readAsBytes();

      await supabase.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      await supabase.from('profiles').update({
        'avatar_url': imageUrl,
      }).eq('id', user.id);

      setState(() {
        _avatarUrl = imageUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile picture updated")),
      );
    } catch (e) {
      setState(() => _isUploading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: $e")),
      );
    }
  }

  // ================= UPDATE PROFILE =================
  Future<void> _updateProfile() async {
    try {
      final user = supabase.auth.currentUser;

      await supabase.from('profiles').update({
        'full_name': _nameController.text,
        'username': _usernameController.text,
        'phone': _phoneController.text.isEmpty ? null : _phoneController.text,
      }).eq('id', user!.id);
      await _loadProfile(); // 🔥 reload profile data

      setState(() => _isEditing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile Updated Successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    }
  }

  // ================= LOGOUT =================
  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // ================= DELETE DIALOG =================
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
            "This action is permanent. Are you sure you want to delete your account?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Add delete logic here later
            },
            child: const Text(
              "Delete",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF4F8FBF);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(_isEditing ? "Edit Profile" : "Profile"),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 1,
        actions: _isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _isEditing = false),
                )
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => setState(() => _isEditing = true),
                )
              ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ================= PROFILE HEADER =================
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _isEditing ? _pickImage : null,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: primaryColor,
                          backgroundImage: _avatarUrl != null
                              ? NetworkImage(_avatarUrl!)
                              : null,
                          child: _avatarUrl == null
                              ? const Icon(Icons.person,
                                  size: 50, color: Colors.white)
                              : null,
                        ),
                        if (_isUploading)
                          const CircularProgressIndicator(color: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _nameController.text.isNotEmpty
                        ? _nameController.text
                        : "User",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _usernameController.text.isNotEmpty
                        ? "@${_usernameController.text}"
                        : "@username",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    supabase.auth.currentUser?.email ?? "No email",
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ================= EDIT FIELDS (only show when editing) =================
            if (_isEditing) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Full Name",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: "Username",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Save Changes"),
              ),
              const SizedBox(height: 30),
            ],

            // ================= SETTINGS SECTION =================
            _sectionTitle("Settings"),

            SwitchListTile(
              title: const Text("Enable Notifications"),
              value: _notificationsEnabled,
              onChanged: _isEditing
                  ? null
                  : (value) {
                      setState(() => _notificationsEnabled = value);
                    },
            ),

            SwitchListTile(
              title: const Text("Dark Mode"),
              value: _darkModeEnabled,
              onChanged: _isEditing
                  ? null
                  : (value) {
                      setState(() => _darkModeEnabled = value);
                    },
            ),

            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text("Security & Privacy"),
              onTap: _isEditing ? null : () {},
            ),

            ListTile(
              leading: const Icon(Icons.password),
              title: const Text("Change Password"),
              onTap: _isEditing ? null : () {},
            ),

            const SizedBox(height: 20),

            // ================= SUPPORT SECTION =================
            _sectionTitle("Support"),

            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text("Help & Support"),
              onTap: _isEditing ? null : () {},
            ),

            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text("Terms & Conditions"),
              onTap: _isEditing ? null : () {},
            ),

            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text("About ILOST"),
              subtitle: const Text("Version 1.0.0"),
              onTap: _isEditing ? null : () {},
            ),

            const SizedBox(height: 30),

            // ================= LOGOUT & DELETE =================
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text("Log Out"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: _showDeleteDialog,
              child: const Text(
                "Delete Account",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
