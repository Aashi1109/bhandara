import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import '../constants/api.dart';
import 'api.dart';

class FileService {
  final Dio _dio = apiService.dio;
  final ImagePicker _picker = ImagePicker();

  static const int maxFileSize = 10 * 1024 * 1024; // 10MB in bytes

  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null && !await validateFileSize(image)) return null;
      return image;
    } catch (e) {
      return null;
    }
  }

  Future<XFile?> pickVideo({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5),
      );
      if (video != null && !await validateFileSize(video)) return null;
      return video;
    } catch (e) {
      return null;
    }
  }

  Future<bool> validateFileSize(XFile file) async {
    final length = await file.length();
    if (length > maxFileSize) {
      // We'll throw an exception to be caught and shown by UI
      throw Exception('File too large. Maximum size is 10MB.');
    }
    return true;
  }

  Future<String?> uploadFile(XFile file, {String bucket = 'media'}) async {
    try {
      final fileName = file.name;
      final fileSize = await file.length();
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      // 1. Get signed URL
      final signedUrlResponse = await _dio.post(
        Api.getSignedUrl,
        data: {
          'path': fileName,
          'bucket': bucket,
          'mimeType': mimeType,
          'size': fileSize,
        },
      );

      if (signedUrlResponse.statusCode != 200) return null;

      final String signedUrl = signedUrlResponse.data['data']['signedUrl'];
      final Map<String, dynamic> row = signedUrlResponse.data['data']['row'];

      // 2. Upload file to signed URL
      final fileBytes = await file.readAsBytes();

      final uploadDio = Dio();
      final uploadResponse = await uploadDio.put(
        signedUrl,
        data: Stream.fromIterable([fileBytes]),
        options: Options(
          headers: {'Content-Type': mimeType, 'Content-Length': fileSize},
        ),
      );

      if (uploadResponse.statusCode == 200) {
        return row['id']; // Return the media ID
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Deprecated: use uploadFile
  Future<String?> uploadImage(XFile file, {String bucket = 'avatars'}) =>
      uploadFile(file, bucket: bucket);
}

final fileService = FileService();
