class Song {
  final String id;
  final String title;
  final String artist;
  final String? lyrics;
  final String? chords;
  final String? url;
  final String? chordData;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.lyrics,
    this.chords,
    this.url,
    this.chordData,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? '',
      title: json['name'] ?? '',
      artist: json['artist']?['name'] ?? '',
      lyrics: json['text'],
      // Vagalume usually returns chords in a specific format if available
      chords: json['chords'], 
      url: json['url'],
      chordData: json['chordData'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'lyrics': lyrics,
      'chords': chords,
      'url': url,
      'chordData': chordData,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'],
      title: map['title'],
      artist: map['artist'],
      lyrics: map['lyrics'],
      chords: map['chords'],
      url: map['url'],
      chordData: map['chordData'],
    );
  }
}
