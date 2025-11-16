import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import '../../../services/chat_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/presence_service.dart';
import '../../../services/profile_service.dart';
import '../../../ui/widgets/message_bubble.dart';
import '../../../models/message_model.dart';
import '../../../core/supabase_config.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  StreamSubscription<List<Message>>? _messagesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _typingSubscription;
  List<Message> _messages = [];
  String _conversationId = '';
  bool _isLoading = true;
  bool _isTyping = false;
  final Map<String, String> _typingUsers = {};

  String _conversationName = 'Chat';
  String _otherUserId = '';
  bool _isGroupChat = false;
  bool _isOtherUserOnline = false;
  StreamSubscription? _userStatusSubscription;
  StreamSubscription? _reactionsSubscription;
  
  // Canal para ouvir mudanças de perfil
  RealtimeChannel? _profilesChannel;

  final Map<String, Map<String, dynamic>> _participantProfiles = {};
  String? _myAvatarUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeChat();
  }

  void _initializeChat() async {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    _conversationId = args?['conversationId'] ?? '';
    _conversationName = args?['conversationName'] ?? 'Chat';

    final profileService = Provider.of<ProfileService>(context, listen: false);
    _myAvatarUrl = profileService.currentProfile?['avatar_url'];

    if (_conversationId.isNotEmpty) {
      await _loadParticipants();
      await _loadInitialMessages();
      _subscribeToMessages();
      _subscribeToTyping();
      _subscribeToReactions();
      _subscribeToProfileChanges();

      if (!_isGroupChat && _otherUserId.isNotEmpty) {
        _subscribeToUserStatus();
      }
    }
  }

  Future<void> _loadParticipants() async {
    final client = SupabaseConfig.client;
    final auth = Provider.of<AuthService>(context, listen: false);
    final myId = auth.currentUser!.id;

    try {
      final response = await client
          .from('participants')
          .select('user_id, profile:profiles(id, full_name, avatar_url)')
          .eq('conversation_id', _conversationId);

      final participantsData = response as List<dynamic>;
      
      if (mounted) {
        setState(() {
          _participantProfiles.clear();
          for (final item in participantsData) {
            final userId = item['user_id'] as String;
            final profile = item['profile'] as Map<String, dynamic>?;
            if (profile != null) {
              _participantProfiles[userId] = profile;
            }
          }
        });
      }

      final participantIds = participantsData.map((e) => e['user_id'] as String).toList();

      if (participantIds.length > 2) {
        if (mounted) setState(() => _isGroupChat = true);
      } else if (participantIds.length == 2) {
        if (mounted) {
          setState(() {
            _isGroupChat = false;
            _otherUserId =
                participantIds.firstWhere((id) => id != myId, orElse: () => '');
          });
        }
      } else {
        if (mounted) setState(() => _isGroupChat = false);
      }
    } catch (e) {
      print('❌ Erro ao buscar participantes: $e');
    }
  }

  void _subscribeToUserStatus() {
    final presenceService = Provider.of<PresenceService>(context, listen: false);
    _userStatusSubscription?.cancel();
    _userStatusSubscription =
        presenceService.subscribeToUserStatus(_otherUserId).listen((status) {
      if (mounted) {
        setState(() {
          _isOtherUserOnline = status['online'] ?? false;
        });
      }
    });
  }

  void _subscribeToReactions() {
    final client = SupabaseConfig.client;
    _reactionsSubscription?.cancel();

    _reactionsSubscription = client
        .from('message_reactions')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', _conversationId) 
        .listen(
      (data) {
        print('🔄 Reação mudou, recarregando mensagens...');
        
        if (!_isLoading && mounted) {
          _loadInitialMessages();
        }
      },
      onError: (error) {
        print('❌ Erro na subscription de reações: $error');
      },
    );
  }

  // Função para ouvir mudanças de perfil
  void _subscribeToProfileChanges() {
    _profilesChannel?.unsubscribe(); 
    _profilesChannel = SupabaseConfig.client
        .channel('public:profiles:chat')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            final updatedProfileId = payload.newRecord['id'];
            
            // Verifica se o perfil atualizado é de alguém nesta conversa
            if (updatedProfileId != null && _participantProfiles.containsKey(updatedProfileId)) {
              print('🔄 Perfil de participante [$updatedProfileId] atualizado!');
              
              // Recarrega os dados dos participantes (para pegar a nova foto)
              _loadParticipants();
              
              // Se for o MEU perfil, atualiza a foto localmente
              if (updatedProfileId == SupabaseConfig.client.auth.currentUser?.id) {
                 if (mounted) {
                   setState(() {
                     _myAvatarUrl = payload.newRecord['avatar_url'];
                   });
                 }
              }
            }
          },
        )
        .subscribe();
  }


  Future<void> _loadInitialMessages() async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final messages = await chatService.fetchMessages(_conversationId);

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }

      _scrollToBottom();
    } catch (e) {
      print('❌ Erro ao carregar mensagens: $e');
      if (mounted) {
        _showErrorSnackbar('Erro ao carregar mensagens');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeToMessages() {
    final chatService = Provider.of<ChatService>(context, listen: false);
    _messagesSubscription?.cancel();

    _messagesSubscription = chatService.subscribeMessages(_conversationId).listen(
      (newMessages) {
        print('🔄 Subscription de mensagens: ${newMessages.length} mensagens');
        
        if (mounted) {
          setState(() {
            _messages = newMessages;
          });
        }
        _scrollToBottom();
      },
      onError: (error) {
        print('❌ Erro na subscription de mensagens: $error');
        _showErrorSnackbar('Erro na conexão em tempo real');
      },
    );
  }

  void _subscribeToTyping() {
    final presenceService = Provider.of<PresenceService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final currentUserId = auth.currentUser?.id ?? '';

    _typingSubscription?.cancel();
    _typingSubscription =
        presenceService.subscribeToTyping(_conversationId).listen(
      (typingEvents) {
        if (mounted) {
          setState(() {
            _typingUsers.clear();
            for (final event in typingEvents) {
              if (event['user_id'] != currentUserId) {
                _typingUsers[event['user_id']] = event['user_name'] ?? 'Usuário';
              }
            }
          });
        }
      },
    );
  }

  void _startTyping() {
    if (!_isTyping) {
      _isTyping = true;
      final presenceService =
          Provider.of<PresenceService>(context, listen: false);
      final profileService = Provider.of<ProfileService>(context, listen: false);
      final myName = profileService.currentProfile?['full_name'] ?? 'Usuário';
      presenceService.startTyping(_conversationId, myName);
    }
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      final presenceService =
          Provider.of<PresenceService>(context, listen: false);
      presenceService.stopTyping(_conversationId);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final chatService = Provider.of<ChatService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final userId = auth.currentUser?.id ?? '';

    if (userId.isEmpty || _conversationId.isEmpty) {
      _showErrorSnackbar('Erro: Usuário ou conversa inválida');
      return;
    }

    try {
      _textController.clear();
      _stopTyping();
      await chatService.sendTextMessage(_conversationId, userId, text);
    } catch (e) {
      print('❌ Erro ao enviar mensagem: $e');
      _showErrorSnackbar('Erro ao enviar mensagem: $e');
      _textController.text = text;
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        if (!mounted) return;
        final chatService = Provider.of<ChatService>(context, listen: false);
        final auth = Provider.of<AuthService>(context, listen: false);
        final userId = auth.currentUser?.id ?? '';

        if (userId.isEmpty || _conversationId.isEmpty) {
          _showErrorSnackbar('Erro: usuário ou conversa não encontrada');
          return;
        }

        await chatService.sendImageMessage(
            _conversationId, userId, bytes, image.name);
        _showSuccessSnackbar('Imagem enviada!');
      }
    } catch (e) {
      print('❌ Erro ao enviar imagem: $e');
      _showErrorSnackbar('Erro ao enviar imagem: $e');
    }
  }

  void _removeMessageLocally(String messageId) {
    setState(() {
      _messages.removeWhere((message) => message.id == messageId);
    });
  }

  Future<void> _forceRefreshMessages() async {
    _messagesSubscription?.cancel();
    await _loadInitialMessages();
    _subscribeToMessages();
  }

  void _showMessageOptions(Message message) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final isMyMessage = message.senderId == auth.currentUser?.id;
    final canEdit = isMyMessage &&
        DateTime.now().difference(message.createdAt).inMinutes <= 4;

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canEdit && message.type == 'text' && !message.isDeleted)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar mensagem'),
              onTap: () {
                Navigator.pop(context);
                _editMessage(message);
              },
            ),
          if (isMyMessage)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  const Text('Excluir mensagem', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
          ListTile(
            leading: const Icon(Icons.emoji_emotions),
            title: const Text('Adicionar reação'),
            onTap: () {
              Navigator.pop(context);
              _showReactionPicker(message);
            },
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancelar'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _editMessage(Message message) {
    final TextEditingController editController =
        TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar mensagem'),
        content: TextField(
          controller: editController,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Digite a nova mensagem...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                try {
                  if (!mounted) return;
                  final chatService =
                      Provider.of<ChatService>(context, listen: false);
                  await chatService.editMessage(message.id, newContent);

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _showSuccessSnackbar('Mensagem editada');
                } catch (e) {
                  _showErrorSnackbar('Erro ao editar mensagem: $e');
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir mensagem'),
        content: const Text(
            'Tem certeza que deseja excluir esta mensagem? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _removeMessageLocally(message.id);

              try {
                if (!mounted) return;
                final chatService =
                    Provider.of<ChatService>(context, listen: false);
                await chatService.deleteMessage(message.id);
              } catch (e) {
                print('❌ Erro ao excluir mensagem: $e');
                _showErrorSnackbar('Erro ao excluir mensagem: $e');
                _loadInitialMessages(); 
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _showReactionPicker(Message message) {
    final emojis = ['👍', '❤️', '😄', '😮', '😢', '🙏'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar reação'),
        content: Wrap(
          spacing: 8,
          children: emojis
              .map((emoji) => GestureDetector(
                    onTap: () async {
                      try {
                        if (!mounted) return;
                        final chatService =
                            Provider.of<ChatService>(context, listen: false);
                        final auth =
                            Provider.of<AuthService>(context, listen: false);
                        final userId = auth.currentUser?.id ?? '';

                        
                        await chatService.addReaction(
                          message.id,
                          userId,
                          emoji,
                          _conversationId, 
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                       
                      } catch (e) {
                        _showErrorSnackbar('Erro ao adicionar reação: $e');
                      }
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _removeReaction(MessageReaction reaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Reação'),
        content:
            Text('Tem certeza que deseja remover sua reação "${reaction.emoji}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                if (!mounted) return;
                final chatService =
                    Provider.of<ChatService>(context, listen: false);

                await chatService.removeReaction(reaction.id);

                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                _showErrorSnackbar('Erro ao remover reação: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _userStatusSubscription?.cancel();
    _reactionsSubscription?.cancel(); 
    _profilesChannel?.unsubscribe();
    _stopTyping();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final userId = auth.currentUser?.id ?? '';

    final otherUserAvatar = _isGroupChat ? null : _participantProfiles[_otherUserId]?['avatar_url'];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: (otherUserAvatar != null && otherUserAvatar.isNotEmpty)
                  ? CachedNetworkImageProvider(otherUserAvatar)
                  : null,
              child: (otherUserAvatar == null || otherUserAvatar.isEmpty)
                  ? Text(_conversationName.isNotEmpty ? _conversationName[0] : 'C')
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_conversationName),
                if (!_isGroupChat && _isOtherUserOnline && _typingUsers.isEmpty)
                  const Text(
                    'Online',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                if (_typingUsers.isNotEmpty)
                  const Text(
                    'digitando...', 
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _forceRefreshMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhuma mensagem ainda',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const Text(
                              'Seja o primeiro a enviar uma mensagem!',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _loadInitialMessages,
                              child: const Text('Recarregar'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        itemCount: _messages.length,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (ctx, i) {
                          final message = _messages[i];
                          final isMine = message.senderId == userId;
                          
                          final senderAvatarUrl = _participantProfiles[message.senderId]?['avatar_url'];

                          return GestureDetector(
                            onLongPress: () => _showMessageOptions(message),
                            child: MessageBubble(
                              message: message,
                              isMine: isMine,
                              currentUserId: userId,
                              senderAvatarUrl: senderAvatarUrl,
                              myAvatarUrl: _myAvatarUrl,
                              onReactionTap: (reaction) {
                                _removeReaction(reaction);
                              },
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _pickAndSendImage,
                      icon: const Icon(Icons.photo_library, color: Colors.blue),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _textController,
                          decoration: const InputDecoration(
                            hintText: 'Digite uma mensagem...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onChanged: (text) {
                            if (text.isNotEmpty) {
                              _startTyping();
                            } else {
                              _stopTyping();
                            }
                          },
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _sendMessage,
                      icon: Icon(Icons.send,
                          color: _textController.text.trim().isEmpty
                              ? Colors.grey
                              : Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}