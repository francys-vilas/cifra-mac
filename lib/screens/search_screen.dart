import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/music_service.dart';
import '../services/supabase_service.dart';
import 'song_viewer_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../widgets/background_wrapper.dart';
import '../main.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final MusicService _musicService = MusicService();
  final SupabaseService _supabaseService = SupabaseService();
  
  // Search
  final TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isSearching = false;
  
  // Saved Songs
  List<Song> _savedSongs = [];
  bool _isLoadingSaved = false;
  final TextEditingController _filterController = TextEditingController();
  
  List<Song> get _filteredSongs {
    if (_filterController.text.isEmpty) {
      return _savedSongs;
    }
    final query = _filterController.text.toLowerCase();
    return _savedSongs.where((song) {
      return song.title.toLowerCase().contains(query) ||
             song.artist.toLowerCase().contains(query);
    }).toList();
  }

  // Create/Edit Song
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _lyricsController = TextEditingController();
  Song? _editingSong; // Track which song is being edited

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSavedSongs();
    
    _tabController.addListener(() {
      if (_tabController.index == 0) { // 0 is now Cifras tab
        _loadSavedSongs();
      }
    });
    

  }

  Future<void> _loadSavedSongs() async {
    setState(() => _isLoadingSaved = true);
    try {
      final songs = await _supabaseService.getSongs();
      setState(() => _savedSongs = songs);
    } catch (e) {
      debugPrint('Error loading saved songs: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSaved = false);
    }
  }

  void _search() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    try {
      final results = await _musicService.searchSongs(_searchController.text);
      if (mounted) {
        setState(() {
          _searchResults = results;
          if (_searchResults.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Nenhum resultado encontrado.')),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }





  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: Scaffold(
        backgroundColor: Colors.transparent, // Make scaffold transparent
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/images/mac.jpg', height: 30, width: 30, fit: BoxFit.cover),
              ),
              const SizedBox(width: 8),
              const Text('Mac Cifras'),
            ],
          ),
          backgroundColor: Colors.transparent, // Make AppBar transparent
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(
                CifrasApp.of(context)?.isDarkMode ?? false
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              onPressed: () {
                CifrasApp.of(context)?.toggleTheme();
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.queue_music), text: 'Cifras'),
              Tab(icon: Icon(Icons.search), text: 'Buscar Novas'),
              Tab(icon: Icon(Icons.edit), text: 'Editor'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Saved Songs Tab (Cifras)
            _buildSavedSongsTab(),
            // Search Tab
            _buildSearchTab(),
            // Editor Tab
            _buildEditorTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedSongsTab() {
    return Column(
      children: [
        // Search/Filter bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _filterController,
            decoration: InputDecoration(
              hintText: 'Filtrar por música ou artista...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _filterController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _filterController.clear();
                        });
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        
        // List
        Expanded(
          child: _isLoadingSaved
              ? const Center(child: CircularProgressIndicator())
              : _savedSongs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.music_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Nenhuma cifra salva ainda.'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: _loadSavedSongs,
                            child: const Text('Atualizar Lista'),
                          ),
                        ],
                      ),
                    )
                  : _filteredSongs.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhuma cifra encontrada com esse filtro',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadSavedSongs,
                          child: ListView.builder(
                            itemCount: _filteredSongs.length,
                            itemBuilder: (context, index) {
                              final song = _filteredSongs[index];
                              return Slidable(
                                key: ValueKey(song.id),
                                endActionPane: ActionPane(
                                  motion: const ScrollMotion(),
                                  children: [
                                    // Edit action
                                    SlidableAction(
                                      onPressed: (context) {
                                        // Load song into editor and switch to Editor tab
                                        _loadSongToEditor(song);
                                        _tabController.animateTo(2); // Switch to Editor tab (index 2)
                                      },
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      icon: Icons.edit,
                                      label: 'Editar',
                                    ),
                                    // Delete action
                                    SlidableAction(
                                      onPressed: (context) async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Excluir?'),
                                            content: const Text('Isso removerá a música para toda a equipe.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: const Text('Excluir'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          await _supabaseService.deleteSong(song.id);
                                          _loadSavedSongs();
                                        }
                                      },
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      icon: Icons.delete,
                                      label: 'Excluir',
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  leading: const Icon(Icons.star, color: Colors.amber),
                                  title: Text(song.title),
                                  subtitle: Text(song.artist),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SongViewerScreen(
                                          artist: song.artist,
                                          title: song.title,
                                          existingSong: song,
                                        ),
                                      ),
                                    );
                                    _loadSavedSongs();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Artista ou música...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
            ],
          ),
        ),
        if (_isSearching) const LinearProgressIndicator(),
        
        Expanded(
          child: _searchResults.isEmpty && !_isSearching
              ? const Center(
                  child: Text(
                    'Digite um artista ou música para buscar',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final song = _searchResults[index];
                    return ListTile(
                      leading: const Icon(Icons.cloud_download_outlined),
                      title: Text(song.title),
                      subtitle: Text(song.artist),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SongViewerScreen(
                              artist: song.artist,
                              title: song.title,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEditorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Editor de Letras',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _clearEditor,
            icon: const Icon(Icons.add),
            label: const Text('Nova Letra'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
            ),
          ),
          const SizedBox(height: 16),
          
          // Song selector
          if (_savedSongs.isNotEmpty)
            DropdownButtonFormField<Song>(
              value: _editingSong,
              decoration: const InputDecoration(
                labelText: 'Editar letra existente',
                border: OutlineInputBorder(),
              ),
              hint: const Text('Selecione uma música'),
              isExpanded: true,
              items: _savedSongs.map((song) {
                return DropdownMenuItem(
                  value: song,
                  child: Text(
                    '${song.title} - ${song.artist}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (song) {
                if (song != null) {
                  _loadSongToEditor(song);
                }
              },
            ),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Título da música',
              border: OutlineInputBorder(),
              hintText: 'Ex: Ruja o Leão',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _artistController,
            decoration: const InputDecoration(
              labelText: 'Artista',
              border: OutlineInputBorder(),
              hintText: 'Ex: Davi Sacer',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _lyricsController,
            decoration: const InputDecoration(
              labelText: 'Letra',
              border: OutlineInputBorder(),
              hintText: 'Digite a letra da música...',
              alignLabelWithHint: true,
            ),
            maxLines: 15,
            minLines: 10,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_titleController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor, insira um título'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    
                    if (_lyricsController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor, insira a letra'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    final song = Song(
                      id: _editingSong?.id ?? const Uuid().v4(),
                      title: _titleController.text,
                      artist: _artistController.text.isEmpty 
                          ? 'Autor Desconhecido' 
                          : _artistController.text,
                      lyrics: _lyricsController.text,
                      chordData: _editingSong?.chordData, // Preserve existing chords
                    );

                    // Save to Supabase
                    try {
                      await _supabaseService.saveSong(song);
                      
                      if (mounted) {
                        final wasEditing = _editingSong != null;
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(wasEditing 
                                ? 'Letra atualizada com sucesso!' 
                                : 'Letra salva com sucesso!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        
                        // Reload saved songs list
                        await _loadSavedSongs();
                        
                        // Navigate to editor
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SongViewerScreen(
                              artist: song.artist,
                              title: song.title,
                              existingSong: song,
                            ),
                          ),
                        );
                        
                        // Clear after navigation
                        _clearEditor();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao salvar: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: Text(_editingSong != null ? 'Atualizar e Editar' : 'Salvar e Editar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  void _loadSongToEditor(Song song) {
    setState(() {
      _editingSong = song;
      _titleController.text = song.title;
      _artistController.text = song.artist;
      _lyricsController.text = song.lyrics ?? '';
    });
  }
  
  void _clearEditor() {
    setState(() {
      _editingSong = null;
      _titleController.clear();
      _artistController.clear();
      _lyricsController.clear();
    });
  }
}
