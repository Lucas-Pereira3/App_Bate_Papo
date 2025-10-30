import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool mine;
  final String type;
  final DateTime? timestamp; // PARÂMETRO OPCIONAL

  const MessageBubble({
    super.key,
    required this.text,
    required this.mine,
    required this.type,
    this.timestamp, // OPCIONAL
  });

  String _formatTime(DateTime? date) {
    if (date == null) return '';
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!mine) ...[
            CircleAvatar(
              radius: 16,
              child: Text('U'),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: mine 
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: type == 'image'
                    ? Image.network(
                        text,
                        width: 200,
                        height: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            children: [
                              Icon(Icons.image, size: 40),
                              Text('Imagem', style: TextStyle(color: mine ? Colors.white : Colors.black)),
                            ],
                          );
                        },
                      )
                    : Text(
                        text,
                        style: TextStyle(
                          color: mine ? Colors.white : Colors.black,
                        ),
                      ),
                ),
                // Timestamp (opcional)
                if (timestamp != null)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      _formatTime(timestamp),
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (mine) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              child: Text('Eu'),
            ),
          ],
        ],
      ),
    );
  }
}