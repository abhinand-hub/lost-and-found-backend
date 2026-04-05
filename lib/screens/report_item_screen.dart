import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'global_notification.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ReportItemScreen extends StatefulWidget {
  final Map? item;
  final String type; // ⭐ ADD THIS

  const ReportItemScreen({
    super.key,
    this.item,
    required this.type, // ⭐ ADD THIS
  });
  @override
  State<ReportItemScreen> createState() => _ReportItemScreenState();
}

class _ReportItemScreenState extends State<ReportItemScreen> {
  final supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _contactController = TextEditingController();

  String category = "Electronics";
  File? imageFile;
  Uint8List? webImage;
  String? imageName;
  String? imageUrl;
  String? itemId;
  @override
  void initState() {
    super.initState();

    if (widget.item != null) {
      itemId = widget.item!['id'];

      _titleController.text = widget.item!['title'] ?? "";
      _descriptionController.text = widget.item!['description'] ?? "";
      _locationController.text = widget.item!['location'] ?? "";
      _contactController.text = widget.item!['contact'] ?? "";

      category = widget.item!['category'] ?? "Electronics";

      imageUrl = widget.item!['image_url'];
    }
  }

  Future<File> compressImage(File file) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      file.absolute.path + "_compressed.jpg",
      quality: 60,
      minWidth: 800,
      minHeight: 800,
    );

    return File(result!.path);
  }

  final categories = ["Electronics", "Keys", "Wallet", "Pets", "Others"];

  bool _isLoading = false;
  bool _isUploading = false;

  // Input decoration theme for consistency [web:18]
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

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

  Future<void> uploadImage() async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      imageName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

      if (kIsWeb && webImage != null) {
        await supabase.storage
            .from('item_images')
            .uploadBinary(imageName!, webImage!);
      } else if (!kIsWeb && imageFile != null) {
        await supabase.storage
            .from('item_images')
            .upload(imageName!, imageFile!);
      }

      imageUrl = supabase.storage.from('item_images').getPublicUrl(imageName!);
      setState(() {});
    } catch (e) {
      if (mounted) {
        GlobalNotification.show(context, "Upload error: $e");
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      if (imageFile != null || webImage != null) {
        await uploadImage();
      }

      final data = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'category': category,
        'type': widget.type,
        'location': _locationController.text,
        'contact': _contactController.text,
        'date': DateTime.now().toIso8601String(),
        'user_id': user.id,
        'matched': false,
        'status': 'active',
        'image_url': imageUrl,
      };

      if (itemId != null) {
        // ✅ UPDATE existing report
        await supabase.from('items').update(data).eq('id', itemId!);

        if (mounted) {
          GlobalNotification.show(context, "Report Updated Successfully!");
        }
      } else {
        // ✅ INSERT new report
        final response = await supabase.from('items').insert(data).select();

        itemId = response.first['id'];
        // 🔥 CALL BACKEND FOR MATCHING
        // 🔥 HERE
        try {
          final response = await http.post(
            Uri.parse("https://lost-and-found-backend-9iky.onrender.com/match"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"item_id": itemId}),
          );

          print("MATCH RESPONSE: ${response.body}");
        } catch (e) {
          print("MATCH ERROR: $e");
        }
        if (mounted) {
          GlobalNotification.show(context, "Report Submitted Successfully!");
        }
      }

      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        GlobalNotification.show(context, "Error: $e");
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> deleteReport() async {
    try {
      if (imageName != null) {
        await supabase.storage.from('item_images').remove([imageName!]);
      }
      if (itemId != null) {
        await supabase.from('items').delete().eq('id', itemId!);
      }
      if (mounted) {
        GlobalNotification.show(context, "Report Deleted");
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  Future<void> updateImage() async {
    await pickImage();
    if ((kIsWeb && webImage != null) || (!kIsWeb && imageFile != null)) {
      if (imageFile != null || webImage != null) {
        await uploadImage();
      }
      if (itemId != null && imageUrl != null) {
        await supabase
            .from('items')
            .update({'image_url': imageUrl}).eq('id', itemId!);
      }
      if (mounted) {
        GlobalNotification.show(context, "Image Updated");
      }
    }
  }

  Widget _buildImagePreview() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (kIsWeb && webImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(webImage!,
                    width: 80, height: 80, fit: BoxFit.cover),
              )
            else if (!kIsWeb && imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(imageFile!,
                    width: 80, height: 80, fit: BoxFit.cover),
              )
            else if (imageUrl != null) // ⭐ ADD THIS LINE HERE
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl!,
                    width: 80, height: 80, fit: BoxFit.cover),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image, size: 40, color: Colors.grey),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                (webImage != null || imageFile != null || imageUrl != null)
                    ? "Image Ready"
                    : "No Image",
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.type == "lost" ? "Report Lost Item" : "Report Found Item",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card [web:11]
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.report_problem,
                              size: 64, color: Colors.orange[400]),
                          const SizedBox(height: 16),
                          const Text(
                            "Help us help you find it!",
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Fill in the details below to report your lost item.",
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form Fields
                  TextFormField(
                    controller: _titleController,
                    decoration:
                        _buildInputDecoration("Item Title", Icons.title),
                    validator: (value) =>
                        value?.isEmpty ?? true ? "Enter item title" : null,
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration:
                        _buildInputDecoration("Category", Icons.category),
                    items: categories
                        .map((cat) =>
                            DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (value) => setState(() => category = value!),
                    validator: (value) =>
                        value == null ? "Select category" : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration:
                        _buildInputDecoration("Description", Icons.description),
                    validator: (value) =>
                        value?.isEmpty ?? true ? "Enter description" : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _locationController,
                    decoration: _buildInputDecoration(
                        "Location Lost or found", Icons.location_on),
                    validator: (value) =>
                        value?.isEmpty ?? true ? "Enter location" : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _contactController,
                    decoration: _buildInputDecoration(
                        "Contact Number/Email", Icons.contact_phone),
                    validator: (value) =>
                        value?.isEmpty ?? true ? "Enter contact info" : null,
                  ),
                  const SizedBox(height: 24),

                  // Image Section
                  const Text("Upload Photo",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildImagePreview(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : pickImage,
                          icon: const Icon(Icons.photo_library),
                          label: Text(
                              _isUploading ? "Uploading..." : "Pick Image"),
                          style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : updateImage,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Update"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          (_isLoading || _isUploading) ? null : submitReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white)),
                            )
                          : const Text("Submit Report",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Delete Button (only show if editing)
                  if (itemId != null)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: deleteReport,
                        icon: const Icon(Icons.delete, color: Colors.white),
                        label: const Text("Delete Report",
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _contactController.dispose();
    super.dispose();
  }
}
