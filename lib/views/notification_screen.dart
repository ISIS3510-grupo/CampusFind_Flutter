import 'package:campusfind_flutter/models/notification_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: StreamBuilder<QuerySnapshot>(
        // Escuchamos en tiempo real la colección 'notifications' creada por el backend
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientUid', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No tienes notificaciones por ahora.'),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final notification = NotificationModel.fromFirestore(
                data,
                docs[index].id,
              );

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(
                    Icons.notifications_active,
                    color: Colors.blue,
                  ),
                  title: Text(
                    'Coincidencia encontrada (Match: ${notification.matchId})',
                  ),
                  subtitle: Text('Canal: ${notification.channel}'),
                  trailing: notification.sentAt != null
                      ? Text(
                          '${notification.sentAt!.hour}:${notification.sentAt!.minute}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
