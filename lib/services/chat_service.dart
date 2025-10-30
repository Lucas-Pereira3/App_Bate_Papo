import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/message_model.dart';
import 'package:uuid/uuid.dart';

class ChatService extends ChangeNotifier {
  final SupabaseClient _client = SupabaseConfig.client;
  final _uuid = Uuid();

  StreamSubscription<List<Message>>? _messagesSub;

  Future<List<Message>> fetchMessages(String conversationId) async {
    try {
      final res = await _client
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
      
      // CORREÇÃO: Verificar o tipo de retorno e converter corretamente
      if (res == null) return [];
      
      final data = res as List<dynamic>;
      return data.map((e) => Message.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Erro ao buscar mensagens: $e');
      return [];
    }
  }

  Stream<List<Message>> subscribeMessages(String conversationId) {
    try {
      return _client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .order('created_at')
          .map((events) {
            // CORREÇÃO: Converter cada evento para Message
            return events.map((event) => Message.fromMap(event)).toList();
          });
    } catch (e) {
      print('Erro ao criar subscription: $e');
      // Retorna um stream vazio em caso de erro
      return Stream.value([]);
    }
  }

  Future<void> sendTextMessage(String conversationId, String senderId, String text) async {
    try {
      final id = _uuid.v4();
      await _client.from('messages').insert({
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': text,
        'type': 'text',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Erro ao enviar mensagem de texto: $e');
      rethrow;
    }
  }

  Future<String> uploadImage(String pathLocal, String filename) async {
    try {
      final bytes = await SupabaseFileHelper.readFileBytes(pathLocal);
      await _client.storage
          .from('message-images')
          .uploadBinary(filename, bytes);
      
      final publicUrl = _client.storage
          .from('message-images')
          .getPublicUrl(filename);
      
      return publicUrl;
    } catch (e) {
      print('Erro ao fazer upload da imagem: $e');
      rethrow;
    }
  }

  Future<void> sendImageMessage(String conversationId, String senderId, String imageUrl) async {
    try {
      final id = _uuid.v4();
      await _client.from('messages').insert({
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': imageUrl,
        'type': 'image',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Erro ao enviar mensagem de imagem: $e');
      rethrow;
    }
  }

  // Método adicional para criar nova conversa
  Future<String> createConversation(String name, List<String> participantIds) async {
    try {
      final conversationId = _uuid.v4();
      
      // Cria a conversa
      await _client.from('conversations').insert({
        'id': conversationId,
        'name': name,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // Adiciona participantes
      for (final userId in participantIds) {
        await _client.from('participants').insert({
          'id': _uuid.v4(),
          'conversation_id': conversationId,
          'user_id': userId,
          'joined_at': DateTime.now().toIso8601String(),
        });
      }
      
      return conversationId;
    } catch (e) {
      print('Erro ao criar conversa: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    super.dispose();
  }
}

// Helper para ler arquivos como bytes
class SupabaseFileHelper {
  static Future<Uint8List> readFileBytes(String path) async {
    // Para web, você precisará usar um file picker adequado
    // Esta é uma implementação de placeholder
    throw UnimplementedError(
      'Implement file reading using a file picker. '
      'Para web, use package:image_picker_web ou similar.'
    );
  }
}