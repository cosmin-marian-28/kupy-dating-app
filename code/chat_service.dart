import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  static final _supabase = Supabase.instance.client;

  /// Load messages for a pair_progress row, oldest first.
  static Future<List<Map<String, dynamic>>> loadMessages(
      String pairProgressId) async {
    final data = await _supabase
        .from('messages')
        .select()
        .eq('pair_progress_id', pairProgressId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Send a message. Returns the inserted row.
  static Future<Map<String, dynamic>> sendMessage(
      String pairProgressId, String body) async {
    final uid = _supabase.auth.currentUser!.id;
    final row = await _supabase
        .from('messages')
        .insert({
          'pair_progress_id': pairProgressId,
          'sender_id': uid,
          'body': body.trim(),
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  /// Subscribe to new messages via Supabase Realtime.
  static RealtimeChannel subscribeToMessages(
    String pairProgressId,
    void Function(Map<String, dynamic> message) onMessage,
  ) {
    final channel = _supabase.channel('messages:$pairProgressId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'pair_progress_id',
            value: pairProgressId,
          ),
          callback: (payload) {
            onMessage(Map<String, dynamic>.from(payload.newRecord));
          },
        )
        .subscribe();
    return channel;
  }
}
