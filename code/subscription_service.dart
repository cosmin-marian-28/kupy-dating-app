import 'package:supabase_flutter/supabase_flutter.dart';

class SubscriptionService {
  static final _supabase = Supabase.instance.client;

  // ── Subscription ──

  /// Returns current tier: null, 'cracked_cupidon', or 'cupidons_blessing'.
  static Future<String?> currentTier() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _supabase
        .from('profiles')
        .select('subscription_tier, subscription_expires')
        .eq('id', uid)
        .single();
    final tier = row['subscription_tier'] as String?;
    if (tier == null) return null;
    final expiresStr = row['subscription_expires'] as String?;
    if (expiresStr != null) {
      final expires = DateTime.tryParse(expiresStr);
      if (expires != null && expires.isBefore(DateTime.now().toUtc())) {
        await _supabase.from('profiles').update({
          'subscription_tier': null,
          'subscription_expires': null,
        }).eq('id', uid);
        return null;
      }
    }
    return tier;
  }

  /// Subscribe to a tier. Sets expiry 30 days from now.
  static Future<void> subscribe(String tier) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    final expires = DateTime.now().toUtc().add(const Duration(days: 30));
    await _supabase.from('profiles').update({
      'subscription_tier': tier,
      'subscription_expires': expires.toIso8601String(),
    }).eq('id', uid);
  }

  /// Grant a specific number of hearts.
  static Future<void> grantHearts(int amount) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    final row = await _supabase
        .from('profiles')
        .select('hearts')
        .eq('id', uid)
        .single();
    final current = row['hearts'] as int? ?? 0;
    await _supabase.from('profiles').update({
      'hearts': current + amount,
    }).eq('id', uid);
  }

  /// Grant a large number of hearts for "unlimited hearts" perk.
  static Future<void> grantUnlimitedHearts() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    final row = await _supabase
        .from('profiles')
        .select('hearts')
        .eq('id', uid)
        .single();
    final current = row['hearts'] as int? ?? 0;
    await _supabase.from('profiles').update({
      'hearts': current + 99999,
    }).eq('id', uid);
  }

  // ── KupyHearts ──

  /// How many bought KupyHearts the current user has.
  static Future<int> boughtBombCount() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return 0;
    final row = await _supabase
        .from('profiles')
        .select('bought_love_bombs')
        .eq('id', uid)
        .single();
    return row['bought_love_bombs'] as int? ?? 0;
  }

  /// How many free love bombs the current user has.
  static Future<int> freeBombCount() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return 0;
    final row = await _supabase
        .from('profiles')
        .select('free_love_bombs')
        .eq('id', uid)
        .single();
    return row['free_love_bombs'] as int? ?? 0;
  }

  /// Buy a love bomb — adds 1 to bought_love_bombs.
  static Future<void> buyBomb() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    final current = await boughtBombCount();
    await _supabase.from('profiles').update({
      'bought_love_bombs': current + 1,
    }).eq('id', uid);
  }

  /// Sender IDs we can use our free bomb on (locked targets) for a given [mode].
  static Future<List<String>> freeBombLockedTargets({String mode = 'normal'}) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final sent = await _supabase
        .from('love_bombs')
        .select('receiver_id')
        .eq('sender_id', uid)
        .eq('mode', mode);
    final sentIds = sent.map((r) => r['receiver_id'] as String).toSet();
    final received = await _supabase
        .from('love_bombs')
        .select('sender_id')
        .eq('receiver_id', uid)
        .eq('mode', mode);
    return received
        .map((r) => r['sender_id'] as String)
        .where((id) => !sentIds.contains(id))
        .toList();
  }

  /// Full profile info for each free bomb locked target.
  static Future<List<Map<String, dynamic>>> freeBombLockedProfiles() async {
    final ids = await freeBombLockedTargets();
    if (ids.isEmpty) return [];
    final rows = await _supabase
        .from('profiles')
        .select('id, username, avatar_url')
        .inFilter('id', ids);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Check if we already sent a love bomb to [receiverId] in a given [mode].
  static Future<bool> alreadySent(String receiverId, {String mode = 'normal'}) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await _supabase
        .from('love_bombs')
        .select('id')
        .eq('sender_id', uid)
        .eq('receiver_id', receiverId)
        .eq('mode', mode)
        .maybeSingle();
    return row != null;
  }

  /// Send a love bomb via RPC.
  /// [mode] determines which progress table to target:
  /// 'normal' (default), 'speed', 'surprise', or 'drink'.
  static Future<Map<String, dynamic>> send(
    String receiverId, {
    bool useFree = false,
    String mode = 'normal',
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return {'error': 'not_logged_in'};

    try {
      if (mode == 'normal') {
        final result = await _supabase.rpc('send_love_bomb', params: {
          'p_sender': uid,
          'p_receiver': receiverId,
          'p_is_free': useFree,
        });
        return Map<String, dynamic>.from(result as Map);
      } else {
        final result = await _supabase.rpc('send_kupy_heart', params: {
          'p_sender': uid,
          'p_receiver': receiverId,
          'p_is_free': useFree,
          'p_mode': mode,
        });
        return Map<String, dynamic>.from(result as Map);
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Load admirers — people who completed their mission for us.
  static Future<List<Map<String, dynamic>>> loadAdmirers() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _supabase
        .from('pair_progress')
        .select()
        .or('user_a.eq.$uid,user_b.eq.$uid');
    final admirerIds = <String>{};
    for (final row in rows) {
      final iAmA = row['user_a'] == uid;
      final theyDone = iAmA
          ? (row['b_done'] as bool? ?? false)
          : (row['a_done'] as bool? ?? false);
      if (theyDone) {
        admirerIds.add(iAmA ? row['user_b'] as String : row['user_a'] as String);
      }
    }
    if (admirerIds.isEmpty) return [];
    final bombs = await _supabase
        .from('love_bombs')
        .select('sender_id')
        .eq('receiver_id', uid)
        .inFilter('sender_id', admirerIds.toList());
    final bombedIds = bombs.map((r) => r['sender_id'] as String).toSet();
    final profiles = await _supabase
        .from('profiles')
        .select('id, username, avatar_url')
        .inFilter('id', admirerIds.toList());
    return profiles.map((p) {
      final id = p['id'] as String;
      return {...p, 'love_bombed': bombedIds.contains(id)};
    }).toList();
  }

  /// Forget/unmatch a user — deletes pair_progress, messages, and love_bombs.
  static Future<void> forgetUser(String otherUserId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    // Get pair_progress IDs first (needed to delete messages)
    final pairs = await _supabase
        .from('pair_progress')
        .select('id')
        .or('and(user_a.eq.$uid,user_b.eq.$otherUserId),and(user_a.eq.$otherUserId,user_b.eq.$uid)');
    final pairIds = pairs.map((r) => r['id'] as String).toList();

    // Delete messages for those pairs
    if (pairIds.isNotEmpty) {
      await _supabase
          .from('messages')
          .delete()
          .inFilter('pair_progress_id', pairIds);
    }

    // Delete pair_progress
    await _supabase
        .from('pair_progress')
        .delete()
        .or('and(user_a.eq.$uid,user_b.eq.$otherUserId),and(user_a.eq.$otherUserId,user_b.eq.$uid)');

    // Delete love_bombs
    await _supabase
        .from('love_bombs')
        .delete()
        .or('and(sender_id.eq.$uid,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$uid)');
  }

  /// Block a user — deletes everything and inserts a block row.
  static Future<void> blockUser(String otherUserId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    await forgetUser(otherUserId);
    await _supabase.from('blocks').upsert({
      'blocker_id': uid,
      'blocked_id': otherUserId,
    });
  }

  /// Unblock a user — removes the block row.
  static Future<void> unblockUser(String otherUserId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    await _supabase
        .from('blocks')
        .delete()
        .eq('blocker_id', uid)
        .eq('blocked_id', otherUserId);
  }

  /// Get IDs of all users blocked by me OR who blocked me (bidirectional).
  static Future<Set<String>> getBlockedUserIds() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return {};
    final ids = <String>{};
    // Users I blocked
    final iBlocked = await _supabase
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', uid);
    for (final row in iBlocked) {
      ids.add(row['blocked_id'] as String);
    }
    // Users who blocked me
    final blockedMe = await _supabase
        .from('blocks')
        .select('blocker_id')
        .eq('blocked_id', uid);
    for (final row in blockedMe) {
      ids.add(row['blocker_id'] as String);
    }
    return ids;
  }

  /// Get profiles of users I have blocked (for the manage blocked list).
  static Future<List<Map<String, dynamic>>> getBlockedProfiles() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _supabase
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', uid);
    final ids = rows.map((r) => r['blocked_id'] as String).toList();
    if (ids.isEmpty) return [];
    final profiles = await _supabase
        .from('profiles')
        .select('id, username, avatar_url')
        .inFilter('id', ids);
    return List<Map<String, dynamic>>.from(profiles);
  }
}
