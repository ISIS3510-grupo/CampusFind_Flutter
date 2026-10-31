import 'package:campusfind_flutter/models/notification_model.dart';
import 'package:campusfind_flutter/services/match_analytics_service.dart';
import 'package:campusfind_flutter/views/match_analytics_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final analyticsService = MatchAnalyticsService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'View BQ Metric',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MatchAnalyticsScreen(),
                ),
              );
            },
          ),
        ],
      ),
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

              final bool isReviewed = notification.viewedAt != null;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isReviewed ? Colors.green.shade300 : const Color(0xFFE2DEDE),
                    width: isReviewed ? 1.5 : 1.0,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    isReviewed
                        ? Icons.check_circle_outline
                        : Icons.notifications_active,
                    color: isReviewed ? Colors.green : Colors.blue,
                  ),
                  title: Text(
                    'Coincidencia encontrada (Match: ${notification.matchId})',
                    style: TextStyle(
                      fontWeight: isReviewed ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    isReviewed
                        ? 'Canal: ${notification.channel} · Revisada'
                        : 'Canal: ${notification.channel} · Toca para revisar',
                  ),
                  trailing: notification.sentAt != null
                      ? Text(
                          '${notification.sentAt!.hour}:${notification.sentAt!.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        )
                      : null,
                  onTap: () {
                    analyticsService.trackMatchReviewed(
                      notification.id,
                      isReviewed,
                    );
                    if (!isReviewed) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Colors.black,
                          content: Text(
                            'Match marcado como revisado. Métrica BQ actualizada.',
                            style: TextStyle(color: Colors.white),
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
