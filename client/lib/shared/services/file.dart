import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import '../constants/api.dart';
import './api.dart';

class FileService {
  final Dio _dio = apiService.dio;
  final ImagePicker _picker = ImagePicker();

  static const int maxFileSize = 10 * 1024 * 1024; // 10MB in bytes
  static const String defaultMediaBucket = 'event-files';
  static const String avatarBucket = 'avatars';

  String _resolveMediaType(String mimeType) {
    if (mimeType.startsWith('image/')) return 'image';
    if (mimeType.startsWith('video/')) return 'video';
    if (mimeType.startsWith('audio/')) return 'audio';
    return 'document';
  }

  String _resolveFormat(XFile file, String mimeType) {
    final extension = file.name.contains('.')
        ? file.name.split('.').last.trim().toLowerCase()
        : '';

    if (extension.isNotEmpty) {
      return extension;
    }

    final mimeParts = mimeType.split('/');
    return mimeParts.length > 1 ? mimeParts.last.toLowerCase() : 'bin';
  }

  String _resolveMimeType(XFile file, List<int> fileBytes) {
    return lookupMimeType(file.name, headerBytes: fileBytes) ??
        lookupMimeType(file.path, headerBytes: fileBytes) ??
        'application/octet-stream';
  }

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

  /// Picks up to [limit] images and/or videos from the gallery.
  Future<List<XFile>> pickMultipleMedia({int limit = 5}) async {
    try {
      final files = await _picker.pickMultipleMedia(limit: limit);
      final valid = <XFile>[];
      for (final file in files) {
        try {
          if (await validateFileSize(file)) valid.add(file);
        } catch (_) {
          // Skip files that exceed size limit.
        }
      }
      return valid;
    } catch (e) {
      return const [];
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

  Future<String?> uploadFile(
    XFile file, {
    String bucket = defaultMediaBucket,
  }) async {
    try {
      final fileName = file.name;
      final fileSize = await file.length();
      final fileBytes = await file.readAsBytes();
      final mimeType = _resolveMimeType(file, fileBytes);
      final mediaType = _resolveMediaType(mimeType);
      final format = _resolveFormat(file, mimeType);

      // 1. Get signed URL
      final signedUrlResponse = await _dio.post(
        Api.getSignedUrl,
        data: {
          'path': fileName,
          'bucket': bucket,
          'mimeType': mimeType,
          'size': fileSize,
          'name': fileName,
          'type': mediaType,
          'format': format,
        },
      );

      if (signedUrlResponse.statusCode != 200) return null;

      final data = signedUrlResponse.data['data'] as Map<String, dynamic>;
      final signedUrl = (data['signedUrl'] ?? data['url']) as String?;
      final row = data['row'] as Map<String, dynamic>?;

      if (signedUrl == null || row == null) {
        throw Exception('Missing signed upload payload');
      }

      // 2. Upload file to signed URL
      final uploadDio = Dio();
      final uploadResponse = await uploadDio.put(
        signedUrl,
        data: fileBytes,
        options: Options(
          headers: {'Content-Type': mimeType, 'Content-Length': fileSize},
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
      );

      if ((uploadResponse.statusCode ?? 500) >= 200 &&
          (uploadResponse.statusCode ?? 500) < 300) {
        return row['id']; // Return the media ID
      }
      throw Exception('Upload failed with status ${uploadResponse.statusCode}');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final error = data['error'];
        if (error is Map<String, dynamic> && error['message'] is String) {
          throw Exception(error['message'] as String);
        }
        if (error is String) {
          throw Exception(error);
        }
      }
      throw Exception('Failed to upload file');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to upload file');
    }
  }

  // Deprecated: use uploadFile
  Future<String?> uploadImage(XFile file, {String bucket = avatarBucket}) =>
      uploadFile(file, bucket: bucket);

  Future<bool> deleteMedia(String mediaId) async {
    try {
      final response = await _dio.delete(Api.media(mediaId));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateMedia(String mediaId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch(Api.media(mediaId), data: data);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getMediaById(String mediaId) async {
    try {
      final response = await _dio.get(Api.media(mediaId));
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          return payload;
        }
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getPublicUrl(String mediaId) async {
    final media = await getMediaById(mediaId);
    if (media == null) return null;
    return (media['publicUrl'] ?? media['url']) as String?;
  }
}

final fileService = FileService();
