import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/offline/local_db.dart';
import '../../equipment/domain/entities/image_analysis.dart';

class LocalImageAnalysisDao {
  Future<Database> _db() => LocalDb.instance();

  Future<String> _persistImageBytes(List<int> bytes, String suggestedName) async {
    final dir = await getApplicationDocumentsDirectory();
    final bucket = Directory(p.join(dir.path, 'offline_images'));
    if (!(await bucket.exists())) {
      await bucket.create(recursive: true);
    }
    final safeName = suggestedName.isNotEmpty
        ? suggestedName
        : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = p.join(bucket.path, safeName);
    final f = File(filePath);
    await f.writeAsBytes(bytes, flush: true);
    return filePath;
  }

  Future<int> insertPending({
    required ImageAnalysis analysis,
    List<int>? imageBytes,
  }) async {
    final db = await _db();
    String? localImagePath;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      localImagePath = await _persistImageBytes(
        imageBytes,
        analysis.imageName ?? 'image.jpg',
      );
    }
    final row = {
      'user_id': analysis.userId,
      'image_name': analysis.imageName,
      'mime_type': analysis.mimeType,
      'local_image_path': localImagePath,
      'image_url': analysis.imageUrl,
      'model': analysis.model,
      'notes': analysis.notes,
      'raw_text': analysis.rawText,
      'created_at': (analysis.createdAt ?? DateTime.now()).millisecondsSinceEpoch,
    };
    return db.insert('pending_image_analyses', row);
  }

  Future<List<Map<String, dynamic>>> getPending() async {
    final db = await _db();
    return db.query(
      'pending_image_analyses',
      orderBy: 'created_at ASC',
    );
  }

  Future<int> deleteById(int id) async {
    final db = await _db();
    return db.delete('pending_image_analyses', where: 'id = ?', whereArgs: [id]);
  }
}