import 'package:supabase_flutter/supabase_flutter.dart';

class MissionService {
  static final _supabase = Supabase.instance.client;

  static const missions = [
    [
      {'totalLikes': 30, 'days': 0, 'consecutive': false},
      {'totalLikes': 50, 'days': 0, 'consecutive': false},
      {'totalLikes': 80, 'days': 0, 'consecutive': false},
      {'totalLikes': 100, 'days': 0, 'consecutive': false},
    ],
    [
      {'totalLikes': 90, 'dailyLikes': 30, 'days': 3, 'consecutive': false},
      {'totalLikes': 250, 'dailyLikes': 50, 'days': 5, 'consecutive': false},
      {'totalLikes': 560, 'dailyLikes': 80, 'days': 7, 'consecutive': false},
      {'totalLikes': 1000, 'dailyLikes': 100, 'days': 10, 'consecutive': false},
    ],
    [
      {'totalLikes': 350, 'dailyLikes': 50, 'days': 7, 'consecutive': true},
      {'totalLikes': 1000, 'dailyLikes': 100, 'days': 10, 'consecutive': true},
      {'totalLikes': 2800, 'dailyLikes': 200, 'days': 14, 'consecutive': true},
    ],
  ];

  // ── Hearts ──

  static Future<int> loadHearts() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 0;
    final data = await _supabase
        .from('profiles').select('hearts').eq('id', user.id).single();
    return data['hearts'] as int? ?? 0;
  }

  /// Atomic: deducts heart, increments likes, checks completion
  static Future<void> spendHeart(String targetId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase.rpc('record_like', params: {
      'p_from': user.id,
      'p_to': targetId,
    });
  }

  /// Speed date: fixed 300 hearts threshold, no missions
  static Future<Map<String, dynamic>> spendSpeedDateHeart(String targetId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};
    final result = await _supabase.rpc('record_speed_date_like', params: {
      'p_from': user.id,
      'p_to': targetId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  /// Surprise date: fixed 30 hearts threshold, no missions
  static Future<Map<String, dynamic>> spendSurpriseDateHeart(String targetId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};
    final result = await _supabase.rpc('record_surprise_date_like', params: {
      'p_from': user.id,
      'p_to': targetId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  /// Drink buddy: fixed 10 hearts threshold, party mode
  static Future<Map<String, dynamic>> spendDrinkBuddyHeart(String targetId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};
    final result = await _supabase.rpc('record_drink_buddy_like', params: {
      'p_from': user.id,
      'p_to': targetId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  /// Load speed date completion status
  static Future<Map<String, dynamic>> loadSpeedDateStatus() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'completed': <String>{}, 'mutual': <String>{}, 'pairMap': <String, String>{}, 'admirers': <String>{}};
    }
    final rows = await _supabase
        .from('speed_date_progress')
        .select()
        .or('user_a.eq.${user.id},user_b.eq.${user.id}');
    final completed = <String>{};
    final mutual = <String>{};
    final pairMap = <String, String>{};
    final admirers = <String>{};
    for (final row in rows) {
      final iAmA = row['user_a'] == user.id;
      final otherId = iAmA ? row['user_b'] as String : row['user_a'] as String;
      final iDone = iAmA ? (row['a_done'] as bool? ?? false) : (row['b_done'] as bool? ?? false);
      final theyDone = iAmA ? (row['b_done'] as bool? ?? false) : (row['a_done'] as bool? ?? false);
      pairMap[otherId] = row['id'] as String;
      if (iDone) completed.add(otherId);
      if (theyDone) admirers.add(otherId);
      if (iDone && theyDone) mutual.add(otherId);
    }
    return {'completed': completed, 'mutual': mutual, 'pairMap': pairMap, 'admirers': admirers};
  }

  static Future<bool> dailyCheckin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    try {
      final result = await _supabase.rpc('daily_checkin');
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasCheckedInToday() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    try {
      // Ask the server if a check-in would succeed (dry-run via reading)
      final data = await _supabase
          .from('profiles').select('last_checkin').eq('id', user.id).single();
      // We compare against server date by calling the RPC — but for a read
      // we just check if last_checkin matches. The RPC is the real guard.
      // This is just UI hint, so approximate is fine.
      final lastCheckin = data['last_checkin'] as String?;
      if (lastCheckin == null) return false;
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      return lastCheckin == today;
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveLanguage(String lang) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase.from('profiles').update({'language': lang}).eq('id', user.id);
  }

  // ── Conversations (from pair_progress) ──

  /// Load all pairs where at least one side completed.
  /// Returns: other user info + i_completed, they_completed, chat_unlocked
  static Future<List<Map<String, dynamic>>> loadConversations() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final rows = await _supabase
        .from('pair_progress')
        .select()
        .or('user_a.eq.${user.id},user_b.eq.${user.id}')
        .order('created_at', ascending: false);

    final convos = <Map<String, dynamic>>[];
    for (final row in rows) {
      final iAmA = row['user_a'] == user.id;
      final otherId = iAmA ? row['user_b'] as String : row['user_a'] as String;
      final iDone = iAmA
          ? (row['a_done'] as bool? ?? false)
          : (row['b_done'] as bool? ?? false);
      final theyDone = iAmA
          ? (row['b_done'] as bool? ?? false)
          : (row['a_done'] as bool? ?? false);

      if (!iDone && !theyDone) continue; // no progress worth showing

      final profile = await _supabase
          .from('profiles').select('username, avatar_url')
          .eq('id', otherId).maybeSingle();

      convos.add({
        'id': row['id'],
        'other_id': otherId,
        'username': profile?['username'] ?? 'Unknown',
        'avatar_url': profile?['avatar_url'],
        'i_completed': iDone,
        'they_completed': theyDone,
        'unlocked': row['chat_unlocked'] as bool? ?? false,
        'created_at': row['created_at'],
      });
    }
    return convos;
  }

  /// Load progress percentage for each user the current user has interacted with
  static Future<Map<String, double>> loadProgressMap() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};
    final rows = await _supabase
        .from('pair_progress')
        .select()
        .or('user_a.eq.${user.id},user_b.eq.${user.id}');
    final map = <String, double>{};
    final today = DateTime.now().toUtc();
    for (final row in rows) {
      final iAmA = row['user_a'] == user.id;
      final otherId = iAmA ? row['user_b'] as String : row['user_a'] as String;
      final done = iAmA ? (row['a_done'] as bool? ?? false) : (row['b_done'] as bool? ?? false);
      if (done) { map[otherId] = 1.0; continue; }

      final likes = iAmA ? (row['a_likes'] as int? ?? 0) : (row['b_likes'] as int? ?? 0);
      final daysReq = iAmA ? (row['b_mission_days_required'] as int? ?? 0) : (row['a_mission_days_required'] as int? ?? 0);
      final totalReq = iAmA ? (row['b_mission_total_required'] as int? ?? 0) : (row['a_mission_total_required'] as int? ?? 0);
      final consec = iAmA ? (row['b_mission_consecutive'] as bool? ?? false) : (row['a_mission_consecutive'] as bool? ?? false);
      final daysDone = iAmA ? (row['a_days_done'] as int? ?? 0) : (row['b_days_done'] as int? ?? 0);
      final lastDayStr = iAmA ? row['a_last_day'] : row['b_last_day'];

      if (likes == 0) continue;

      double pct;
      if (daysReq > 0) {
        // Daily mission — progress is days completed / days required
        int effectiveDays = daysDone;
        // If consecutive and missed a day, reset
        if (consec && lastDayStr != null) {
          final lastDay = DateTime.tryParse(lastDayStr.toString());
          if (lastDay != null) {
            final diff = today.difference(lastDay).inDays;
            if (diff > 1) effectiveDays = 0;
          }
        }
        pct = daysReq > 0 ? (effectiveDays / daysReq).clamp(0.0, 1.0) : 0.0;
      } else if (totalReq > 0) {
        // Simple total likes mission
        pct = (likes / totalReq).clamp(0.0, 1.0);
      } else {
        continue;
      }
      if (pct > 0) map[otherId] = pct;
    }
    return map;
  }

  /// Load speed date progress percentages (fixed 100 threshold)
  static Future<Map<String, double>> loadSpeedDateProgressMap() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};
    final rows = await _supabase
        .from('speed_date_progress')
        .select()
        .or('user_a.eq.${user.id},user_b.eq.${user.id}');
    final map = <String, double>{};
    for (final row in rows) {
      final iAmA = row['user_a'] == user.id;
      final otherId = iAmA ? row['user_b'] as String : row['user_a'] as String;
      final likes = iAmA ? (row['a_likes'] as int? ?? 0) : (row['b_likes'] as int? ?? 0);
      if (likes > 0) map[otherId] = (likes / 100).clamp(0.0, 1.0);
    }
    return map;
  }

  /// Load surprise date completion status
  static Future<Map<String, dynamic>> loadSurpriseDateStatus() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'completed': <String>{}, 'mutual': <String>{}, 'pairMap': <String, String>{}, 'admirers': <String>{}};
    }
    final rows = await _supabase
        .from('surprise_date_progress')
        .select()
        .or('user_a.eq.${user.id},user_b.eq.${user.id}');
    final completed = <String>{};
    final mutual = <String>{};
    final pairMap = <String, String>{};
    final admirers = <String>{};
    for (final row in rows) {
      final iAmA = row['user_a'] == user.id;
      final otherId = iAmA ? row['user_b'] as String : row['user_a'] as String;
      final iDone = iAmA ? (row['a_done'] as bool? ?? false) : (row['b_done'] as bool? ?? false);
      final theyDone = iAmA ? (row['b_done'] as bool? ?? false) : (row['a_done'] as bool? ?? false);
      pairMap[otherId] = row['id'] as String;
      if (iDone) completed.add(otherId);
      if (theyDone) admirers.add(otherId);
      if (iDone && theyDone) mutual.add(otherId);
    }
    return {'completed': completed, 'mutual': mutual, 'pairMap': pairMap, 'admirers': admirers};
  }

  /// Load surprise date progress percentages (fixed 30 threshold)
  static Future<Map<String, double>> loadSurpriseDateProgressMap() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};
    final rows = await _supabase
        .from('surprise_date_progress')
        .select()
        .or('user_a.eq.${user.id},user_b.eq.${user.id}');
    final map = <String, double>{};
    for (final row in rows) {
      final iAmA = row['user_a'] == user.id;
      final otherId = iAmA ? row['user_b'] as String : row['user_a'] as String;
      final likes = iAmA ? (row['a_likes'] as int? ?? 0) : (row['b_likes'] as int? ?? 0);
      if (likes > 0) map[otherId] = (likes / 30).clamp(0.0, 1.0);
    }
    return map;
  }

  /// Load drink buddy completion status
  static Future<Map<String, dynamic>> loadDrinkBuddyStatus() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'completed': <String>{}, 'mutual': <String>{}, 'pairMap': <String, String>{}, 'admirers': <String>{}};
    }
    final rows = await _supabase
        .from('drink_buddy_progress')
        .select()
        .or('user_a.eq.${user.id},user_b.eq.${user.id}');
    final completed = <String>{};
    final mutual = <String>{};
    final pairMap = <String, String>{};
    final admirers = <String>{};
    for (final row in rows) {
      final iAmA = row['user_a'] == user.id;
      final otherId = iAmA ? row['user_b'] as String : row['user_a'] as String;
      final iDone = iAmA ? (row['a_done'] as bool? ?? false) : (row['b_done'] as bool? ?? false);
      final theyDone = iAmA ? (row['b_done'] as bool? ?? false) : (row['a_done'] as bool? ?? false);
      pairMap[otherId] = row['id'] as String;
      if (iDone) completed.add(otherId);
      if (theyDone) admirers.add(otherId);
      if (iDone && theyDone) mutual.add(otherId);
    }
    return {'completed': completed, 'mutual': mutual, 'pairMap': pairMap, 'admirers': admirers};
  }

  /// Load drink buddy progress percentages (fixed 10 threshold)
  static Future<Map<String, double>> loadDrinkBuddyProgressMap() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};
    final rows = await _supabase
        .from('drink_buddy_progress')
        .select()
        .or('user_a.eq.${user.id},user_b.eq.${user.id}');
    final map = <String, double>{};
    for (final row in rows) {
      final iAmA = row['user_a'] == user.id;
      final otherId = iAmA ? row['user_b'] as String : row['user_a'] as String;
      final likes = iAmA ? (row['a_likes'] as int? ?? 0) : (row['b_likes'] as int? ?? 0);
      if (likes > 0) map[otherId] = (likes / 50).clamp(0.0, 1.0);
    }
    return map;
  }

  /// Returns completion status: 'completed' (I did for them), 'mutual' (both done),
  /// and 'pairMap' mapping other user ID → pair_progress row ID.
  static Future<Map<String, dynamic>> loadCompletionStatus() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return {'completed': <String>{}, 'mutual': <String>{}, 'pairMap': <String, String>{}, 'admirers': <String>{}};
    }

    final rows = await _supabase
        .from('pair_progress')
        .select()
        .or('user_a.eq.${user.id},user_b.eq.${user.id}');

    final completed = <String>{};
    final mutual = <String>{};
    final pairMap = <String, String>{};
    final admirers = <String>{};

    for (final row in rows) {
      final iAmA = row['user_a'] == user.id;
      final otherId = iAmA ? row['user_b'] as String : row['user_a'] as String;
      final iDone = iAmA ? (row['a_done'] as bool? ?? false) : (row['b_done'] as bool? ?? false);
      final theyDone = iAmA ? (row['b_done'] as bool? ?? false) : (row['a_done'] as bool? ?? false);

      pairMap[otherId] = row['id'] as String;
      if (iDone) completed.add(otherId);
      if (theyDone) admirers.add(otherId);
      if (iDone && theyDone) mutual.add(otherId);
    }

    return {'completed': completed, 'mutual': mutual, 'pairMap': pairMap, 'admirers': admirers};
  }

  /// Users the current user completed missions for
  static Future<List<Map<String, dynamic>>> loadCompletedFor() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final rows = await _supabase
        .from('pair_progress')
        .select()
        .or('user_a.eq.${user.id},user_b.eq.${user.id}');

    final targetIds = <String>{};
    for (final row in rows) {
      final iAmA = row['user_a'] == user.id;
      final done = iAmA
          ? (row['a_done'] as bool? ?? false)
          : (row['b_done'] as bool? ?? false);
      if (done) {
        targetIds.add(iAmA ? row['user_b'] as String : row['user_a'] as String);
      }
    }
    if (targetIds.isEmpty) return [];

    final profiles = await _supabase
        .from('profiles').select('id, username, avatar_url')
        .inFilter('id', targetIds.toList());
    return List<Map<String, dynamic>>.from(profiles);
  }

  // ── Mission selection (via RPC) ──

  /// Change mission via atomic DB function.
  /// Handles cooldown, same-category updates, different-category resets/locks.
  static Future<String?> setActiveMission(int category, int index) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'Not logged in';

    final result = await _supabase.rpc('change_mission', params: {
      'p_user': user.id,
      'p_new_cat': category,
      'p_new_idx': index,
    });

    final res = result as Map<String, dynamic>;
    if (res['error'] == 'cooldown') {
      final hours = (res['remaining_hours'] as num).round();
      final days = hours ~/ 24;
      final h = hours % 24;
      return days > 0 ? 'Wait ${days}d ${h}h' : 'Wait ${h}h';
    }
    return null; // success
  }
}
