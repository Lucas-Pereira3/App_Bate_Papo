import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class StorageService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<String> uploadMessageImage(Uint8List bytes, String filename) async {
    try {
      print('📤 Iniciando upload de imagem...');
      
      final String finalFilename = '${DateTime.now().millisecondsSinceEpoch}_${_sanitizeFilename(filename)}';
      
      print('📁 Upload para: message-images/$finalFilename');
      
      await _client.storage
          .from('message-images')
          .uploadBinary(finalFilename, bytes);
      
      final publicUrl = _client.storage
          .from('message-images')
          .getPublicUrl(finalFilename);
      
      print('✅ Upload concluído: $publicUrl');
      return publicUrl;
      
    } catch (e) {
      print('❌ Erro no upload: $e');
      
      print('🔄 Usando fallback Base64...');
      return _getBase64Fallback(bytes);
    }
  }

  String _sanitizeFilename(String filename) {
    return filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  String _getBase64Fallback(Uint8List bytes) {
    final base64String = base64Encode(bytes);
    return 'data:image/jpeg;base64,$base64String';
  }

  Future<bool> checkBucketExists() async {
    try {
      await _client.storage.from('message-images').list();
      return true;
    } catch (e) {
      return false;
    }
  }
}