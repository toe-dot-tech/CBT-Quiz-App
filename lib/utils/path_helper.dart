import 'dart:io';

class PathHelper {
  // Get current working directory
  static String get currentDirectory => Directory.current.path;
  
  // Get downloads directory path
  static Future<String?> getDownloadsDirectory() async {
    try {
      // Windows: %USERPROFILE%\Downloads
      final home = Platform.environment['USERPROFILE'];
      if (home != null) {
        final downloadsPath = '$home\\Downloads';
        final dir = Directory(downloadsPath);
        if (await dir.exists()) {
          return downloadsPath;
        }
      }
      
      // Fallback: current directory
      return Directory.current.path;
    } catch (e) {
      print('Error getting downloads directory: $e');
      return null;
    }
  }
  
  // Get application documents directory
  static Future<String> getApplicationDocumentsDirectory() async {
    // For Windows, use a folder in AppData
    try {
      final appData = Platform.environment['APPDATA'];
      if (appData != null) {
        final appDir = Directory('$appData\\cbtapp');
        if (!await appDir.exists()) {
          await appDir.create(recursive: true);
        }
        return appDir.path;
      }
    } catch (e) {
      print('Error getting app data directory: $e');
    }
    
    // Fallback to current directory
    return Directory.current.path;
  }
  
  // Get temporary directory
  static String get temporaryDirectory {
    final temp = Platform.environment['TEMP'];
    if (temp != null && Directory(temp).existsSync()) {
      return temp;
    }
    return Directory.current.path;
  }
  
  // Join paths (Windows style)
  static String join(String part1, String part2) {
    if (part1.isEmpty) return part2;
    if (part2.isEmpty) return part1;
    
    if (part1.endsWith('\\') || part1.endsWith('/')) {
      return '$part1$part2';
    }
    return '$part1\\$part2';
  }
  
  // Join multiple paths
  static String joinAll(List<String> parts) {
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    
    String result = parts.first;
    for (int i = 1; i < parts.length; i++) {
      result = join(result, parts[i]);
    }
    return result;
  }
  
  // Get file name from path
  static String basename(String path) {
    return path.split('\\').last.split('/').last;
  }
  
  // Get directory name from path
  static String dirname(String path) {
    final parts = path.split('\\').expand((p) => p.split('/')).toList();
    if (parts.length <= 1) return '.';
    parts.removeLast();
    return parts.join('\\');
  }
  
  // Get extension from path
  static String extension(String path) {
    final fileName = basename(path);
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1) return '';
    return fileName.substring(lastDot);
  }
  
  // Check if file exists
  static Future<bool> fileExists(String path) async {
    return File(path).exists();
  }
  
  // Check if directory exists
  static Future<bool> directoryExists(String path) async {
    return Directory(path).exists();
  }
  
  // Create directory if it doesn't exist
  static Future<void> ensureDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
  
  // Read file as string
  static Future<String?> readFileAsString(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      print('Error reading file: $e');
    }
    return null;
  }
  
  // Write string to file
  static Future<bool> writeFileAsString(String path, String content) async {
    try {
      final file = File(path);
      await file.writeAsString(content);
      return true;
    } catch (e) {
      print('Error writing file: $e');
      return false;
    }
  }
  
  // List files in directory with extension filter
  static List<File> listFiles(String directory, {String? extension}) {
    try {
      final dir = Directory(directory);
      if (!dir.existsSync()) return [];
      
      return dir.listSync().whereType<File>()
          .where((f) => extension == null || f.path.toLowerCase().endsWith(extension.toLowerCase()))
          .toList();
    } catch (e) {
      print('Error listing files: $e');
      return [];
    }
  }
  
  // Get file size
  static Future<int> fileSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      print('Error getting file size: $e');
    }
    return 0;
  }
  
  // Delete file
  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e) {
      print('Error deleting file: $e');
    }
    return false;
  }
}