import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'app_config.dart';

class CloudinaryUploadResult {
  final String? url;
  final String? error;
  CloudinaryUploadResult({this.url, this.error});
}

class CloudinaryService {
  static final ImagePicker _picker = ImagePicker();

  static Future<CloudinaryUploadResult?> pickAndUpload(
    BuildContext context, {
    String folder = '2s_member',
  }) async {
    if (AppConfig.cloudinaryCloudName.contains('ISI_CLOUD_NAME') ||
        AppConfig.cloudinaryUploadPreset.contains('ISI_UPLOAD_PRESET')) {
      return CloudinaryUploadResult(
        error: 'Isi cloudinaryCloudName & cloudinaryUploadPreset di lib/app_config.dart dulu.',
      );
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Ambil Foto dari Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pilih Foto dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return null;

    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 78,
    );
    if (file == null) return null;

    try {
      final bytes = await file.readAsBytes();
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload',
      );
      final req = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
        ..fields['folder'] = folder
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name));

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      final data = jsonDecode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode >= 200 && resp.statusCode < 300 && data['secure_url'] != null) {
        return CloudinaryUploadResult(url: data['secure_url'].toString());
      }
      final errMsg = data['error']?['message'] ?? 'Upload gagal (${resp.statusCode})';
      return CloudinaryUploadResult(error: errMsg.toString());
    } catch (e) {
      return CloudinaryUploadResult(error: 'Error upload Cloudinary: $e');
    }
  }
}
