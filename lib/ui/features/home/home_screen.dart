import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/supabase_config.dart';
import '../../../core/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../services/presence_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/app_state_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final SupabaseClient _client = SupabaseConfig.client;
  late Future<List<dynamic>> _conversationsFuture;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _profilesChannel;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
  }

  void _initializeData() {
    _loadConversations();
    _setUserOnline();
    _subscribeToMessages();
    _subscribeToProfileChanges();

    // Resetar chat atual ao iniciar Home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        Provider.of<ChatService>(context, listen: false)
            .addListener(_loadConversations);

        final appState = Provider.of<AppStateService>(context, listen: false);
        appState.setCurrentChat(null);
        print('🏠 HomeScreen iniciada: currentChatId resetado para null');
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Gerenciar presença quando o app volta ao foreground
    if (state == AppLifecycleState.resumed) {
      _setUserOnline();

      if (!_isDisposed && mounted) {
        final appState = Provider.of<AppStateService>(context, listen: false);
        appState.setCurrentChat(null);
        print('🔄 App retomado: currentChatId resetado');
      }
    }
  }

  // Só mostra notificação se NÃO estiver em nenhum chat
  void _subscribeToMessages() {
    _messagesChannel = _client
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            print('🔄 Nova mensagem detectada!');

            if (_isDisposed) return;


            Future.delayed(Duration.zero, () {
              if (_isDisposed) return;

              final scaffoldContext = _scaffoldKey.currentContext;
              if (scaffoldContext == null) {
                print('⚠️ Contexto do scaffold não disponível');
                return;
              }

              try {
                ScaffoldMessenger.of(scaffoldContext);
              } catch (e) {
                print('⚠️ Scaffold não disponível: $e');
                return;
              }

              AppStateService? appState;
              try {
                appState =
                    Provider.of<AppStateService>(scaffoldContext, listen: false);
              } catch (e) {
                print('⚠️ Erro ao obter AppState: $e');
                return;
              }

              final newMsg = payload.newRecord;
              final conversationId = newMsg['conversation_id'];
              final content = newMsg['content'] ?? 'Nova mensagem';
              final senderId = newMsg['sender_id'];

              // Não mostrar se a mensagem é do próprio usuário
              final currentUserId = _client.auth.currentUser?.id;
              if (senderId == currentUserId) {
                print('📱 Mensagem do próprio usuário, ignorando pop-up');
                return;
              }

              // Só mostrar notificação se NÃO estiver em NENHUM chat (currentChatId é null)
              print('💬 Verificando se deve mostrar notificação:');
              print('   - Conversation ID: $conversationId');
              print('   - Current Chat ID: ${appState.currentChatId}');
              print('   - Usuário em algum chat? ${appState.currentChatId != null}');

              if (appState.currentChatId == null) {
                print('💬 Usuário na Home - Mostrando notificação para: $conversationId');
                
                _loadConversations();

                _showMessageSnackbar(scaffoldContext, content, conversationId);
              } else {
                print(
                    '🔇 Usuário já está em um chat (${appState.currentChatId}), ignorando notificação');
              }
            });
          },
        )
        .subscribe();
  }

  void _showMessageSnackbar(
      BuildContext context, String content, String conversationId) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Nova mensagem: $content'),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () {
              Navigator.pushNamed(
                context,
                RoutesEnum.chat,
                arguments: {
                  'conversationId': conversationId,
                  'conversationName': 'Chat'
                },
              );
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  void _subscribeToProfileChanges() {
    _profilesChannel = _client
        .channel('public:profiles')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            print('🔄 Perfil atualizado detectado! Recarregando conversas...');
            if (!_isDisposed) _loadConversations();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);

    try {
      _messagesChannel?.unsubscribe();
      _profilesChannel?.unsubscribe();
    } catch (e) {
      print('⚠️ Erro ao desinscrever canais: $e');
    }

    try {
      Provider.of<ChatService>(context, listen: false)
          .removeListener(_loadConversations);
    } catch (e) {
      print('⚠️ Erro ao remover listener: $e');
    }

    super.dispose();
  }

  void _setUserOnline() {
    try {
      final presenceService =
          Provider.of<PresenceService>(context, listen: false);
      presenceService.setUserOnline();
    } catch (e) {
      print('⚠️ Erro ao definir usuário online: $e');
    }
  }

  Future<void> _loadConversations() async {
    if (!_isDisposed && mounted) {
      setState(() {
        _conversationsFuture = _fetchConversations();
      });
    }
  }

  Future<List<dynamic>> _fetchConversations() async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return [];

      final response = await _client
          .from('participants')
          .select('''
            unread_count, 
            conversation:conversations(
              id,
              name,
              created_at,
              created_by,
              is_group,
              is_public,
              
              participants!inner(
                user_id,
                profile:profiles(full_name, avatar_url) 
              ),
              
              messages(id, content, created_at, type, is_deleted)
            )
          ''')
          .eq('user_id', currentUserId)
          .order('created_at', referencedTable: 'conversations', ascending: false);

      var conversations = (response as List<dynamic>);

      for (var convData in conversations) {
        final conv = convData['conversation'];
        final isGroup = conv['is_group'] == true;

        if (!isGroup) {
          final participants = conv['participants'] as List<dynamic>? ?? [];
          final otherParticipant = participants.firstWhere(
            (p) => p['user_id'] != currentUserId,
            orElse: () => null,
          );

          if (otherParticipant != null) {
            final profile = otherParticipant['profile'] as Map<String, dynamic>?;
            if (profile != null) {
              conv['name'] = profile['full_name'] ?? 'Chat';
              conv['avatar_url'] = profile['avatar_url'];
            }
          }
        }
      }

      conversations.sort((a, b) {
        final messagesA = a['conversation']['messages'] as List<dynamic>? ?? [];
        final messagesB = b['conversation']['messages'] as List<dynamic>? ?? [];

        if (messagesA.isEmpty && messagesB.isEmpty) return 0;
        if (messagesA.isEmpty) return 1;
        if (messagesB.isEmpty) return -1;

        final lastMessageA = DateTime.parse(messagesA.last['created_at']);
        final lastMessageB = DateTime.parse(messagesB.last['created_at']);
        return lastMessageB.compareTo(lastMessageA);
      });

      return conversations;
    } catch (e) {
      print('Erro ao carregar conversas: $e');
      return [];
    }
  }

  void _confirmDelete(String conversationId, String name, bool isGroup) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(isGroup ? 'Excluir Grupo' : 'Excluir Conversa',style: const TextStyle(color: Color(0xFFFF6F4F)),),
        content: Text(
            'Tem certeza que deseja apagar "$name"?\n'
            'Essa ação não pode ser desfeita.',style: const TextStyle(color: Colors.white70),),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final chatService =
                    Provider.of<ChatService>(context, listen: false);
                await chatService.deleteConversation(conversationId);

                if (!_isDisposed && mounted) {
                  _showSnackbar(context, 'Apagado com sucesso!', isError: false);
                  _loadConversations();
                }
              } catch (e) {
                if (!_isDisposed && mounted) {
                  _showSnackbar(context, 'Erro ao apagar: $e');
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
  }

  void _createNewConversation(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    bool isGroup = true;
    bool isPublic = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text('Novo Grupo', style: TextStyle(color: Colors.white70),),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(
                  color: Colors.white70, 
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Nome do grupo',
                    hintText: 'Ex: Provas',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: isPublic,
                      activeColor: const Color(0xFFFF6F4F),   
                      checkColor: Colors.black, 
                      onChanged: (value) {
                        setDialogState(() {
                          isPublic = value!;
                        });
                      },
                    ),
                    const Text('Grupo público',style: TextStyle(color: Colors.white70),),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar',style: TextStyle(color: Colors.white70)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();

                  if (name.isEmpty) {
                    _showSnackbar(context, 'Digite um nome para o grupo');
                    return;
                  }

                  setDialogState(() {});

                  try {
                    final chatService =
                        Provider.of<ChatService>(context, listen: false);
                    final currentUserId = _client.auth.currentUser!.id;

                    await chatService.createConversation(
                        name, isGroup, isPublic, [currentUserId]);
                    if (!context.mounted) return;

                    Navigator.pop(context);
                    _loadConversations();
                    _showSnackbar(context, 'Grupo criado com sucesso!',
                        isError: false);
                  } catch (e) {
                    _showSnackbar(context, 'Erro: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6F4F),
                ),
                child: const Text('Criar',style: TextStyle(color: Colors.white70)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnackbar(BuildContext context, String message,
      {bool isError = true}) {
    if (!_isDisposed && _scaffoldKey.currentContext != null) {
      ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
        ),
      );
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dateUtc = DateTime.parse(isoString);
      final dateLocal = dateUtc.toLocal();
      final now = DateTime.now();

      final difference = now.difference(dateLocal);

      if (now.day != dateLocal.day || difference.inDays > 0) {
        return '${dateLocal.day}/${dateLocal.month}/${dateLocal.year}';
      } else {
        return '${dateLocal.hour.toString().padLeft(2, '0')}:${dateLocal.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return '';
    }
  }

  String _getLastMessageText(List<dynamic> messages) {
    if (messages.isEmpty) return 'Nenhuma mensagem';

    final lastMessage = messages.last;
    final isDeleted = lastMessage['is_deleted'] == true;

    if (isDeleted) return 'Mensagem excluída';

    final type = lastMessage['type'] as String?;
    if (type == 'image') return '📷 Imagem';

    return lastMessage['content'] ?? 'Mensagem';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: const Text(
          'Ratozap',
          style: TextStyle(color: Color(0xFFFF6F4F)),
        ),
        backgroundColor: const Color(0xFF0D0D0D),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFFFF6F4F)),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Color(0xFFFF6F4F)),
            onPressed: () => Navigator.pushNamed(context, '/edit-profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFFF6F4F)),
            onPressed: () {
              _isDisposed = true;
              _messagesChannel?.unsubscribe();
              _profilesChannel?.unsubscribe();

              final presenceService =
                  Provider.of<PresenceService>(context, listen: false);
              presenceService.setUserOffline();
              Provider.of<AuthService>(context, listen: false).signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _conversationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Erro ao carregar conversas'),
                  ElevatedButton(
                    onPressed: _loadConversations,
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            );
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma conversa',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _createNewConversation(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Criar Grupo'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadConversations,
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 0.5,
                indent: 80,
                endIndent: 16,
              ),
              itemBuilder: (ctx, i) {
                final convData = conversations[i];
                final conv = convData['conversation'] as Map<String, dynamic>;
                final unreadCount = convData['unread_count'] as int;

                final name = conv['name'] ?? 'Chat';
                final id = conv['id'];
                final isGroup = conv['is_group'] == true;

                final avatarUrl = conv['avatar_url'] as String?;

                final messages = conv['messages'] as List<dynamic>? ?? [];
                final lastMessageText = _getLastMessageText(messages);

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        isGroup ? const Color(0xFF2E7D32) : Colors.blue,
                    backgroundImage:
                        (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'C',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20),
                          )
                        : null,
                  ),
                  title: Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: Colors.white),
                      ),
                      if (isGroup) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.group, size: 16, color: Colors.grey),
                      ]
                    ],
                  ),
                  subtitle: Text(
                    lastMessageText,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                  trailing: messages.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _formatTime(messages.last['created_at']),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(height: 4),
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.green,
                                child: Text(
                                  unreadCount.toString(),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                              ),
                            ]
                          ],
                        )
                      : null,
                  onTap: () async {
                    final appState =
                        Provider.of<AppStateService>(context, listen: false);
                    appState.setCurrentChat(id);
                    print('▶️ Entrando no chat: $id');

                    await Navigator.pushNamed(context, RoutesEnum.chat,
                        arguments: {
                          'conversationId': id,
                          'conversationName': name
                        });

                    if (!_isDisposed && mounted) {
                      appState.setCurrentChat(null);
                      print(
                          '↩️ Usuário voltou para Home: currentChatId resetado para null');

                      _loadConversations();
                    }
                  },
                  onLongPress: () {
                    _confirmDelete(id, name, isGroup);
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Icons.message, color: Colors.white),
        onPressed: () => _createNewConversation(context),
      ),
    );
  }
}