import 'package:flutter/material.dart';
import '../../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final Function(MessageReaction)? onReactionTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onReactionTap,
  });

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Agora';
    }
  }

  Widget _buildMessageContent() {
    if (message.isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete, size: 16, color: Colors.grey),
          SizedBox(width: 4),
          Text(
            'Mensagem excluída',
            style: TextStyle(
              color: isMine ? Colors.white70 : Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    if (message.type == 'image') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            message.content,
            width: 200,
            height: 150,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Imagem não carregada',
                      style: TextStyle(
                        color: isMine ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (message.isEdited)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'editado',
                style: TextStyle(
                  fontSize: 10,
                  color: isMine ? Colors.white70 : Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.content,
          style: TextStyle(
            color: isMine ? Colors.white : Colors.black,
          ),
        ),
        if (message.isEdited)
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'editado',
              style: TextStyle(
                fontSize: 10,
                color: isMine ? Colors.white70 : Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReactions() {
    if (message.reactions.isEmpty) return SizedBox();

    // Agrupar reações por emoji
    final reactionCounts = <String, int>{};
    for (final reaction in message.reactions) {
      reactionCounts[reaction.emoji] = (reactionCounts[reaction.emoji] ?? 0) + 1;
    }

    return Padding(
      padding: EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        children: reactionCounts.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value;
          
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMine ? Colors.blue[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMine ? Colors.blue[100]! : Colors.grey[300]!,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: TextStyle(fontSize: 14),
                ),
                if (count > 1) ...[
                  SizedBox(width: 4),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: Text(
                'U',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine 
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildMessageContent(),
                ),
                
                // REAÇÕES - AGORA DEVE APARECER
                _buildReactions(),
                
                // TIMESTAMP
                Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMine) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green,
              child: Text(
                'Eu',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}