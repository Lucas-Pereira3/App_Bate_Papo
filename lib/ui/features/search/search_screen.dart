import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/search_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/auth_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoading = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _searchFocusNode.requestFocus();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
      _currentQuery = query;
    });

    try {
      final searchService = Provider.of<SearchService>(context, listen: false);
      
      final users = await searchService.searchUsers(query);
      final groups = await searchService.searchGroups(query);
      
      setState(() {
        _searchResults = [
          ...users.map((user) => {...user, 'type': 'user'}),
          ...groups.map((group) => {...group, 'type': 'group'})
        ];
        _isLoading = false;
      });
    } catch (e) {
      print('Erro na busca: $e');
      setState(() {
        _isLoading = false;
      });
      _showSnackbar('Erro ao realizar busca');
    }
  }

  Future<void> _startConversationWithUser(Map<String, dynamic> user) async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final currentUserId = auth.currentUser!.id;

      final conversationId = await chatService.createConversation(
        'Conversa com ${user['full_name']}',
        false,
        false,
        [currentUserId, user['id']],
      );

      Navigator.pop(context);
      Navigator.pushNamed(
        context, 
        '/chat',
        arguments: {'conversationId': conversationId}
      );

      _showSnackbar('Conversa iniciada!', isError: false);
    } catch (e) {
      print('Erro ao iniciar conversa: $e');
      _showSnackbar('Erro ao iniciar conversa: $e');
    }
  }

  Future<void> _joinGroup(Map<String, dynamic> group) async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final auth = Provider.of<AuthService>(context, listen: false);
      final currentUserId = auth.currentUser!.id;

      await chatService.createConversation(
        group['name'],
        true,
        group['is_public'],
        [currentUserId],
      );

      Navigator.pop(context);
      Navigator.pushNamed(
        context, 
        '/chat',
        arguments: {'conversationId': group['id']}
      );

      _showSnackbar('Você entrou no grupo!', isError: false);
    } catch (e) {
      print('Erro ao entrar no grupo: $e');
      _showSnackbar('Erro ao entrar no grupo: $e');
    }
  }

  void _showSnackbar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _buildUserResult(Map<String, dynamic> user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue,
        child: Text(
          (user['full_name']?[0] ?? 'U').toUpperCase(),
          style: TextStyle(color: Colors.white),
        ),
      ),
      title: Text(user['full_name'] ?? 'Usuário'),
      subtitle: Text('Usuário'),
      trailing: Icon(Icons.chat, color: Colors.blue),
      onTap: () => _startConversationWithUser(user),
    );
  }

  Widget _buildGroupResult(Map<String, dynamic> group) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green,
        child: Icon(Icons.group, color: Colors.white),
      ),
      title: Text(group['name'] ?? 'Grupo'),
      subtitle: Text('Grupo ${group['is_public'] == true ? 'Público' : 'Privado'}'),
      trailing: Icon(Icons.group_add, color: Colors.green),
      onTap: () => _joinGroup(group),
    );
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Buscando...'),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty && _isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nenhum resultado encontrado',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Tente buscar por outros termos',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        final type = item['type'] as String;
        
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: type == 'user' 
              ? _buildUserResult(item)
              : _buildGroupResult(item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Buscar usuários ou grupos...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: TextStyle(color: Colors.white),
          onChanged: (value) {
            if (value.length >= 2) {
              _performSearch(value);
            } else {
              setState(() {
                _searchResults = [];
                _isSearching = false;
              });
            }
          },
        ),
        backgroundColor: Colors.blue,
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchResults = [];
                  _isSearching = false;
                });
              },
            ),
        ],
      ),
      body: _isSearching || _searchResults.isNotEmpty
          ? _buildSearchResults()
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Buscar usuários e grupos',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Digite pelo menos 2 caracteres para buscar',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}