import 'dart:io';
import 'package:path_provider/path_provider.dart';

class NativeHelper {
  /// Returns the best writable directory for saving received files.
  static Future<Directory> getDownloadsDir() async {
    if (Platform.isAndroid) {
      // Use external storage downloads if available
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          final downloads = Directory('${ext.path}/LuchII');
          await downloads.create(recursive: true);
          return downloads;
        }
      } catch (_) {}
    }
    // Fallback: app documents directory
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/LuchII');
    await dir.create(recursive: true);
    return dir;
  }
}
