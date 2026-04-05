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
  final String type;

  const ReportItemScreen({
    super.key,
    this.item,
    required this.type,
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

  bool _isLoading = false;
  bool _isUploading = false;

  final categories = ["Electronics", "Keys", "Wallet", "Pets", "Others"];

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

  // 🔥 COMPRESS IMAGE
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

  // 🔥 PICK + COMPRESS (BEST PRACTICE)
  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // extra compression
    );

    if (picked != null) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() => webImage = bytes);
      } else {
        File file = File(picked.path);
        File compressed = await compressImage(file);

        setState(() => imageFile = compressed);
      }
    }
  }

  // 🔥 UPLOAD IMAGE
  Future<void> uploadImage() async {
    if (_isUploading) return;

    setState(() => _isUploading = true);

    try {
      imageName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

      if (kIsWeb && webImage != null) {
        await supabase.storage
            .from('item_images')
            .uploadBinary(imageName!, webImage!);
      } else if (imageFile != null) {
        await supabase.storage
            .from('item_images')
            .upload(imageName!, imageFile!);
      }

      imageUrl = supabase.storage.from('item_images').getPublicUrl(imageName!);
    } catch (e) {
      if (mounted) {
        GlobalNotification.show(context, "Upload error: $e");
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // 🔥 SUBMIT REPORT (OPTIMIZED)
  Future<void> submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Upload image first
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
        'image_url': imageUrl,
      };

      if (itemId != null) {
        await supabase.from('items').update(data).eq('id', itemId!);

        if (mounted) {
          GlobalNotification.show(context, "Report Updated Successfully!");
        }
      } else {
        final response = await supabase.from('items').insert(data).select();

        itemId = response.first['id'];

        // 🔥 NON-BLOCKING BACKEND CALL
        http.post(
          Uri.parse("https://lost-and-found-backend-9iky.onrender.com/match"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"item_id": itemId}),
        );

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

  // UI decoration
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    );
  }

  Widget _buildImagePreview() {
    return Card(
      child: SizedBox(
        height: 100,
        child: Row(
          children: [
            if (kIsWeb && webImage != null)
              Image.memory(webImage!, width: 80, height: 80)
            else if (imageFile != null)
              Image.file(imageFile!, width: 80, height: 80)
            else if (imageUrl != null)
              Image.network(imageUrl!, width: 80, height: 80)
            else
              const Icon(Icons.image, size: 60),
            const SizedBox(width: 10),
            const Text("Image Ready")
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.type == "lost" ? "Report Lost Item" : "Report Found Item"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: _buildInputDecoration("Title", Icons.title),
                validator: (v) => v!.isEmpty ? "Enter title" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                decoration:
                    _buildInputDecoration("Description", Icons.description),
                validator: (v) => v!.isEmpty ? "Enter description" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _locationController,
                decoration:
                    _buildInputDecoration("Location", Icons.location_on),
                validator: (v) => v!.isEmpty ? "Enter location" : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contactController,
                decoration: _buildInputDecoration("Contact", Icons.phone),
                validator: (v) => v!.isEmpty ? "Enter contact" : null,
              ),
              const SizedBox(height: 20),
              _buildImagePreview(),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: pickImage,
                child: const Text("Pick Image"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : submitReport,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text("Submit"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
