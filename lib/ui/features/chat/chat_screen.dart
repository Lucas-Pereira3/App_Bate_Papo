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
import '../../../services/app_state_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  
  StreamSubscription<List<Map<String, dynamic>>>? _typingSubscription;
  StreamSubscription<Message>? _newMessageSubscription; 
  StreamSubscription<Message>? _updatedMessageSubscription;
  StreamSubscription? _userStatusSubscription;
  
  RealtimeChannel? _reactionsChannel; 
  

  bool _isLoadingMore = false; 
  int _currentOffset = 0; 

  List<Message> _messages = [];
  String _conversationId = '';
  bool _isLoading = true;
  bool _isTyping = false;
  final Map<String, String> _typingUsers = {};

  String _conversationName = 'Chat';
  String _otherUserId = '';
  bool _isGroupChat = false;
  bool _isOtherUserOnline = false;

  RealtimeChannel? _profilesChannel;

  final Map<String, Map<String, dynamic>> _participantProfiles = {};
  String? _myAvatarUrl;

  bool _isDisposed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollController.addListener(_onScroll);
    _initializeChat();

    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final conversationId = args?['conversationId'] ?? '';

    if (conversationId.isNotEmpty) {
      Provider.of<AppStateService>(context, listen: false)
          .setCurrentChat(conversationId);
      Provider.of<ChatService>(context, listen: false)
          .markConversationAsRead(conversationId);
    }
  }

  /// Listener do Scroll para Paginação (Infinite Scrolling)
  void _onScroll() async {
    if (!_isLoadingMore && _scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      print('🔼 Chegou ao topo! Carregando mais mensagens...');
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoadingMore = true;
          _currentOffset += ChatService.messagePageSize; 
        });
      }

      try {
        final chatService = Provider.of<ChatService>(context, listen: false);
        final moreMessages = await chatService.fetchMessages(_conversationId, offset: _currentOffset);

        if (moreMessages.isNotEmpty) {
          if (!_isDisposed && mounted) {
            setState(() {
              _messages.addAll(moreMessages); 
            });
          }
        } else {
          print('ℹ️ Não há mais mensagens antigas para carregar.');
        }
      } catch (e) {
        print('❌ Erro ao carregar mais mensagens: $e');
      } finally {
        if (!_isDisposed && mounted) {
          setState(() {
            _isLoadingMore = false;
          });
        }
      }
    }
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

      if (!_isDisposed && mounted) {
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

      final participantIds =
          participantsData.map((e) => e['user_id'] as String).toList();

      if (participantIds.length > 2) {
        if (!_isDisposed && mounted) setState(() => _isGroupChat = true);
      } else if (participantIds.length == 2) {
        if (!_isDisposed && mounted) {
          setState(() {
            _isGroupChat = false;
            _otherUserId =
                participantIds.firstWhere((id) => id != myId, orElse: () => '');
          });
        }
      } else {
        if (!_isDisposed && mounted) setState(() => _isGroupChat = false);
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
      if (!_isDisposed && mounted) {
        setState(() {
          _isOtherUserOnline = status['online'] ?? false;
        });
      }
    });
  }

  /// Assinatura de Reações OTIMIZADA
  void _subscribeToReactions() {
    final client = SupabaseConfig.client;
    
    _reactionsChannel?.unsubscribe();
    
    _reactionsChannel = client
   
        .channel('public:message_reactions:conv=$_conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, 
          schema: 'public',
          table: 'message_reactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: _conversationId,
          ),
          callback: (payload) {
            print('🔄 Reação mudou [${payload.eventType}]');

            if (_isLoading || _isDisposed || !mounted) return;

            String? messageId;
            Map<String, dynamic>? record;

            if (payload.eventType == PostgresChangeEvent.delete) {
              record = payload.oldRecord;
              messageId = record?['message_id'];
            } else {
              record = payload.newRecord;
              messageId = record?['message_id'];
            }

            if (messageId == null) {
              print('⚠️ Não foi possível identificar o messageId da reação.');
              return;
            }

            final index = _messages.indexWhere((m) => m.id == messageId);

            if (index != -1) {
              print('🔄 Atualizando reações SÓ da mensagem $messageId');
              List<MessageReaction> currentReactions = List.from(_messages[index].reactions);

              if (payload.eventType == PostgresChangeEvent.insert) {
                currentReactions.add(MessageReaction.fromMap(payload.newRecord));
              } 
              else if (payload.eventType == PostgresChangeEvent.delete) {
                final reactionId = payload.oldRecord?['id'];
                currentReactions.removeWhere((r) => r.id == reactionId);
              }
              else if (payload.eventType == PostgresChangeEvent.update) {
                final reactionId = payload.newRecord['id'];
                final reactionIndex = currentReactions.indexWhere((r) => r.id == reactionId);
                if(reactionIndex != -1) {
                  currentReactions[reactionIndex] = MessageReaction.fromMap(payload.newRecord);
                }
              }

              if (!_isDisposed && mounted) {
                setState(() {
                  _messages[index] = _messages[index].copyWith(
                    reactions: currentReactions,
                  );
                });
              }
            }
          },
        )
        .subscribe();
  }

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

            if (updatedProfileId != null &&
                _participantProfiles.containsKey(updatedProfileId)) {
              print('🔄 Perfil de participante [$updatedProfileId] atualizado!');
              _loadParticipants();
              if (updatedProfileId ==
                  SupabaseConfig.client.auth.currentUser?.id) {
                if (!_isDisposed && mounted) {
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
      _currentOffset = 0; 
      final messages = await chatService.fetchMessages(_conversationId, offset: _currentOffset);

      if (!_isDisposed && mounted) {
        setState(() {
          _messages = messages; 
          _isLoading = false;
        });
      }
      _scrollToBottom();
    } catch (e) {
      print('❌ Erro ao carregar mensagens: $e');
      if (!_isDisposed && mounted) {
        _showErrorSnackbar('Erro ao carregar mensagens');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Assinatura de Mensagens OTIMIZADA
  void _subscribeToMessages() {
    final chatService = Provider.of<ChatService>(context, listen: false);
    
    _newMessageSubscription?.cancel();
    _updatedMessageSubscription?.cancel();

    chatService.listenToMessages(_conversationId); 

    _newMessageSubscription = chatService.newMessageStream.listen((newMessage) {
      print('🔄 Nova mensagem recebida na TELA');
      if (!_isDisposed && mounted) {
        setState(() {
          _messages.insert(0, newMessage); 
        });
        chatService.markConversationAsRead(_conversationId);
      }
      _scrollToBottom();
    });

    _updatedMessageSubscription = chatService.updatedMessageStream.listen((updatedMessage) {
      print('🔄 Mensagem atualizada recebida na TELA');
      if (!_isDisposed && mounted) {
        final index = _messages.indexWhere((m) => m.id == updatedMessage.id);
        if (index != -1) {
          setState(() {
            _messages[index] = updatedMessage;
          });
        }
      }
    });
  }

  void _subscribeToTyping() {
    final presenceService = Provider.of<PresenceService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final currentUserId = auth.currentUser?.id ?? '';

    _typingSubscription?.cancel(); 
    _typingSubscription =
        presenceService.subscribeToTyping(_conversationId).listen(
      (typingEvents) {
        if (!_isDisposed && mounted) {
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
      final profileService =
          Provider.of<ProfileService>(context, listen: false);
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
      if (_scrollController.hasClients && !_isDisposed && _scrollController.position.pixels != _scrollController.position.minScrollExtent) {
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
    if (!_isDisposed && mounted) {
      setState(() {
        _messages.removeWhere((message) => message.id == messageId);
      });
    }
  }

  Future<void> _forceRefreshMessages() async {
    _newMessageSubscription?.cancel();
    _updatedMessageSubscription?.cancel();
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
      backgroundColor: const Color(0xFF0D0D0D),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canEdit && message.type == 'text' && !message.isDeleted)
            ListTile(
              leading: const Icon(Icons.edit, color:  Color(0xFFFFFF00)),
              title: const Text('Editar mensagem', style: TextStyle(color : Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                _editMessage(message);
              },
            ),
          if (isMyMessage)
            ListTile(
              leading: const Icon(Icons.delete, color: Color(0xFFFF073A)),
              title: const Text('Excluir mensagem',
                  style: TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
          ListTile(
            leading: const Icon(Icons.emoji_emotions, color:Color(0xFF00BFFF)),
            title: const Text('Adicionar reação', style: TextStyle(color: Colors.white70)),
            onTap: () {
              Navigator.pop(context);
              _showReactionPicker(message);
            },
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
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
        title: const Text('Editar mensagem', style: TextStyle(color: Colors.white)),
        backgroundColor:  const Color(0xFF0D0D0D),
        constraints: const BoxConstraints(maxWidth: 300),
        content: TextField(
          controller: editController,
          minLines: 1,
          maxLines: 3,
           style: const TextStyle(
            color: Colors.white70, 
          ),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Digite a nova mensagem...',
            hintStyle: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                try {
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6F00)),
            child: const Text('Salvar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('Excluir mensagem', style : TextStyle(color: Colors.white)),
        content: const Text(
            'Tem certeza que deseja excluir esta mensagem? Esta ação não pode ser desfeita.', style : TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style : TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final chatService =
                    Provider.of<ChatService>(context, listen: false);
                await chatService.deleteMessage(message.id);
              } catch (e) {
                print('❌ Erro ao excluir mensagem: $e');
                _showErrorSnackbar('Erro ao excluir mensagem: $e');
                _loadInitialMessages(); 
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color (0xFFFF6F4F)),
            child: const Text('Excluir',style : TextStyle(color: Colors.white)),
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
        title: const Text('Adicionar reação',style: TextStyle(color: Colors.white70)),
        backgroundColor: const Color(0xFF0D0D0D),
        content: Wrap(
          spacing: 8,
          children: emojis
              .map((emoji) => GestureDetector(
                    onTap: () async {
                      try {
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
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _removeReaction(MessageReaction reaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('Remover Reação', style: TextStyle(color: Colors.white70)),
        content: Text(
            'Tem certeza que deseja remover sua reação "${reaction.emoji}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final chatService =
                    Provider.of<ChatService>(context, listen: false);
                await chatService.removeReaction(reaction.id);
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                _showErrorSnackbar('Erro ao remover reação: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6F4F)),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    Provider.of<AppStateService>(context, listen: false).setCurrentChat(null);

    // Limpa todas as inscrições
    _newMessageSubscription?.cancel();
    _updatedMessageSubscription?.cancel();
    _typingSubscription?.cancel(); 
    _userStatusSubscription?.cancel();
    
    _reactionsChannel?.unsubscribe(); 
    _profilesChannel?.unsubscribe();
    
    Provider.of<ChatService>(context, listen: false).stopListeningToMessages();
    
    _stopTyping();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final userId = auth.currentUser?.id ?? '';

    final otherUserAvatar =
        _isGroupChat ? null : _participantProfiles[_otherUserId]?['avatar_url'];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Color(0xFFFF6F4F), 
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: (otherUserAvatar != null &&
                      otherUserAvatar.isNotEmpty)
                  ? CachedNetworkImageProvider(otherUserAvatar)
                  : null,
              child: (otherUserAvatar == null || otherUserAvatar.isEmpty)
                  ? Text(
                      _conversationName.isNotEmpty ? _conversationName[0] : 'C')
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_conversationName,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                if (!_isGroupChat && _isOtherUserOnline && _typingUsers.isEmpty)
                  const Text(
                    'Online',
                    style: TextStyle(fontSize: 12, color: Color(0xFFFF6F4F)),
                  ),
                if (_typingUsers.isNotEmpty)
                  const Text(
                    'digitando...',
                    style: TextStyle(fontSize: 12, color: Color(0xFFFF6F4F)),
                  ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF121212),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _forceRefreshMessages,
            color: const Color(0xFFFF6F4F),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhuma mensagem ainda',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const Text(
                              'Seja o primeiro a enviar uma mensagem!',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
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
                          final senderAvatarUrl =
                              _participantProfiles[message.senderId]
                                  ?['avatar_url'];

                          return GestureDetector(
                            onLongPress: () => _showMessageOptions(message),
                            child: MessageBubble(
                              message: message,
                              isMine: isMine,
                              currentUserId: userId,
                              senderAvatarUrl: senderAvatarUrl,
                              myAvatarUrl: _myAvatarUrl,
                              onReactionTap: (reaction) {
                                // Só permite remover se a reação for sua
                                if(reaction.userId == userId) {
                                  _removeReaction(reaction);
                                }
                              },
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _pickAndSendImage,
                      icon: const Icon(Icons.photo_library,
                          color: Color(0xFFFF6F4F)),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(
                            color: Colors.white, 
                            fontSize: 16, 
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Digite uma mensagem...',
                            hintStyle: TextStyle(color: Colors.white70), // Adicionado
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
                              : const Color(0xFFFF6F4F)),
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