import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'dpvkfc93p'; 

  static const String uploadPreset =
      'medplant_uploads';

  static Future<String?> uploadImage(
    Uint8List bytes,
  ) async {
    try {
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest(
        'POST',
        uri,
      );

      request.fields['upload_preset'] =
          uploadPreset;

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'plant.jpg',
        ),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData =
            await response.stream.bytesToString();

        final decoded =
            jsonDecode(responseData);

        return decoded['secure_url'];
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}