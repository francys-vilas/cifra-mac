import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/song.dart';
import 'package:uuid/uuid.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Table name
  static const String _table = 'songs';

  /// Saves a song to Supabase (Upsert).
  /// Uses the song ID as the primary key.
  Future<void> saveSong(Song song) async {
    try {
      final data = song.toMap();
      
      // Check if ID is a valid UUID (length 36 and contains hyphens)
      // LRCLIB returns numeric string IDs which will fail in Supabase UUID column
      final id = data['id'] as String;
      
      // Only generate new UUID if current ID is invalid
      // This preserves manually created song IDs and only replaces API-generated ones
      if (id.isEmpty || (id.length < 32 || !id.contains('-'))) {
        // Generate a new UUID for the song
        final newId = const Uuid().v4();
        debugPrint('Replacing invalid ID "$id" with UUID: $newId');
        data['id'] = newId;
      }
      
      // Upsert: inserts if new, updates if exists (based on primary key 'id')
      await _client.from(_table).upsert(data);
    } catch (e) {
      debugPrint('Error saving song to Supabase: $e');
      rethrow;
    }
  }

  /// Retrieves all songs ordered by title.
  Future<List<Song>> getSongs() async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .order('title', ascending: true);
          
      final data = response as List<dynamic>;
      return data.map((json) => Song.fromMap(json)).toList();
    } catch (e) {
      debugPrint('Error fetching songs from Supabase: $e');
      return [];
    }
  }

  /// Deletes a song by its ID.
  Future<void> deleteSong(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting song from Supabase: $e');
      rethrow;
    }
  }
  
  /// Real-time subscription to song updates?
  /// Optional, but useful for team sharing.
  Stream<List<Song>> get songsStream {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('title')
        .map((data) => data.map((json) => Song.fromMap(json)).toList());
  }
}
