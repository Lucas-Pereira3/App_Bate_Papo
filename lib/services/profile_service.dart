import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import 'storage_service.dart';

class ProfileService extends ChangeNotifier {
  final SupabaseClient _client = SupabaseConfig.client;
  final StorageService _storageService = StorageService();
  Map<String, dynamic>? _currentProfile;

  Map<String, dynamic>? get currentProfile => _currentProfile;

  Future<void> initializeProfile() async {
    try {
      final userId = _client.auth.currentUser!.id;
      final email = _client.auth.currentUser!.email!;
      
      print('🔍 Verificando perfil para: $email');
      
      _currentProfile = await getCurrentProfile();
      
      if (_currentProfile == null) {
        print('🆕 Criando perfil automaticamente...');
        await _client.from('profiles').insert({
          'id': userId,
          'full_name': _getNameFromEmail(email),
          'online': true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        
        _currentProfile = await getCurrentProfile();
        print('✅ Perfil criado com sucesso');
      } else {
        print('✅ Perfil encontrado: ${_currentProfile!['full_name']}');
      }
      
      // Armazena o email no perfil local para consistência
      _currentProfile?['email'] = email;
      
      notifyListeners();
      
    } catch (e) {
      print('❌ Erro ao inicializar perfil: $e');
    }
  }

  String _getNameFromEmail(String email) {
    final namePart = email.split('@').first;
    return namePart[0].toUpperCase() + namePart.substring(1);
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    try {
      final userId = _client.auth.currentUser!.id;
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      // Adiciona o email ao perfil buscado
      if (response != null) {
        response['email'] = _client.auth.currentUser!.email;
      }
      return response;
    } catch (e) {
      print('❌ Erro ao buscar perfil: $e');
      return null;
    }
  }

  Future<String> uploadAvatar(Uint8List imageBytes, String filename) async {
    return await _storageService.uploadMessageImage(imageBytes, filename);
  }

  // Adiciona 'removeImage' flag
  Future<void> updateProfile(
    String fullName, 
    Uint8List? imageBytes, {
    bool removeImage = false, 
  }) async {
    try {
      final userId = _client.auth.currentUser!.id;
      
      // Mapa com dados que SEMPRE serão atualizados
      final Map<String, dynamic> dataToUpdate = {
        'id': userId,
        'full_name': fullName,
        'online': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      if (imageBytes != null) {
        // Caso 1: Usuário enviou uma NOVA foto
        print('🔄 Enviando nova foto de perfil...');
        final avatarUrl = await _storageService.uploadMessageImage(
          imageBytes, 
          'avatar_$userId.jpg'
        );
        dataToUpdate['avatar_url'] = avatarUrl;
        
      } else if (removeImage) {
        // Caso 2: Usuário clicou em "Remover Foto"
        print('🗑️ Removendo foto de perfil...');
        dataToUpdate['avatar_url'] = null; 
      
      }
      
      await _client
          .from('profiles')
          .update(dataToUpdate)
          .eq('id', userId);

      _currentProfile = await getCurrentProfile();
      notifyListeners();
      
      print('✅ Perfil atualizado com sucesso');
    } catch (e) {
      print('❌ Erro ao atualizar perfil: $e');
      rethrow;
    }
  }

  Future<void> setUserOnline(bool online) async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('profiles').upsert({
        'id': userId,
        'online': online,
        'last_seen': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Erro ao atualizar status online: $e');
    }
  }
}