import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';

class MusicService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://lrclib.net',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'CifrasApp/1.0 (https://github.com/yourusername/cifras)',
    },
  ));



  Future<List<Song>> searchSongs(String query) async {
    try {
      final baseUrl = 'https://lrclib.net/api/search';
      final queryParams = 'q=${Uri.encodeComponent(query)}';
      final fullUrl = '$baseUrl?$queryParams';
      
      final effectiveUrl = fullUrl;

      final response = await _dio.get(effectiveUrl);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List ? response.data : [];
        
        return data.map((item) {
          return Song(
            id: item['id'].toString(),
            title: item['name'] ?? item['trackName'] ?? '',
            artist: item['artistName'] ?? '',
            // LRCLIB returns plainLyrics in search results sometimes, or we can use it if available
            lyrics: item['plainLyrics'],
            url: null, // LRCLIB doesn't provide a public URL usually
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error searching LRCLIB: $e');
      return [];
    }
  }

  Future<Song?> getSongDetails(String artist, String songTitle) async {
    try {
      // LRCLIB /api/get requires specific parameters for best match
      // But /api/search is more flexible if we just have strings.
      // Let's first try to get by query which is usually accurate enough.
      
      final songs = await searchSongs('$artist $songTitle');
      
      if (songs.isNotEmpty) {
        // Return the first match
        // Note: The search result might already contain lyrics.
        // If not, we might need to fetch details, but /api/search in LRCLIB usually returns lyrics.
        return songs.first;
      }
      
      // Fallback: Try specific get endpoint if we can construct parameters
      // But without album or duration, /api/get is hard to use accurately.
      
      return null;
    } catch (e) {
      debugPrint('Error getting song details from LRCLIB: $e');
      return null;
    }
  }
}
