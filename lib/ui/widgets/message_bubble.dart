import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import '../../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final String currentUserId;
  final Function(MessageReaction)? onReactionTap;
  
  // Parâmetros para as fotos
  final String? senderAvatarUrl;
  final String? myAvatarUrl;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.currentUserId,
    this.onReactionTap,
    this.senderAvatarUrl,
    this.myAvatarUrl,
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
          const Icon(Icons.delete, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
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

    // Usa CachedNetworkImage e trata fallback de Base64
    if (message.type == 'image') {
      Widget imageWidget;

      if (message.content.startsWith('data:image')) {
        try {
          final base64String = message.content.split(',').last;
          final imageBytes = base64Decode(base64String);
          imageWidget = Image.memory(imageBytes, fit: BoxFit.cover);
        } catch (e) {
          imageWidget = Container(
            width: 200,
            height: 150,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
          );
        }
      } else {
        imageWidget = CachedNetworkImage(
          imageUrl: message.content,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 200,
            height: 150,
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            width: 200,
            height: 150,
            color: Colors.grey[300],
            child: const Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            height: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageWidget,
            ),
          ),
          if (message.isEdited)
            Padding(
              padding: const EdgeInsets.only(top: 4),
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
            padding: const EdgeInsets.only(top: 2),
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
    if (message.reactions.isEmpty) return const SizedBox();

    final reactionCounts = <String, int>{};
    for (final reaction in message.reactions) {
      reactionCounts[reaction.emoji] = (reactionCounts[reaction.emoji] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        children: reactionCounts.entries.map((entry) {
          final emoji = entry.key;

          MessageReaction? userReaction;
          for (final reaction in message.reactions) {
            if (reaction.userId == currentUserId && reaction.emoji == emoji) {
              userReaction = reaction;
              break;
            }
          }

          return GestureDetector(
            onTap: () {
              if (userReaction != null && onReactionTap != null) {
                onReactionTap!(userReaction);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: userReaction != null ? Colors.blue[100] : (isMine ? Colors.blue[50] : Colors.grey[100]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: userReaction != null ? Colors.blue : (isMine ? Colors.blue[100]! : Colors.grey[300]!),
                  width: userReaction != null ? 1.5 : 1.0,
                ),
              ),
              
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
  
  // Widget helper para a foto de perfil
  Widget _buildAvatar(String? avatarUrl, String fallbackText) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.grey.shade300,
      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
          ? CachedNetworkImageProvider(avatarUrl)
          : null,
      child: (avatarUrl == null || avatarUrl.isEmpty)
          ? Text(
              fallbackText,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: isMine ? 10 : 12,
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Avatar do Remetente
          if (!isMine) ...[
            _buildAvatar(senderAvatarUrl, 'U'), 
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMine
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildMessageContent(),
                ),
                
                _buildReactions(),
                
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatTime(message.createdAt),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Seu Avatar
          if (isMine) ...[
            const SizedBox(width: 8),
            _buildAvatar(myAvatarUrl, 'Eu'), 
          ],
        ],
      ),
    );
  }
}