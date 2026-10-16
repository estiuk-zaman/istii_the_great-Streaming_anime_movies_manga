import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZangetsuLiteApp());
}

class ZangetsuLiteApp extends StatelessWidget {
  const ZangetsuLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zangetsu Personal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0B0F),
        primaryColor: const Color(0xFFFF3B5C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF3B5C),
          secondary: Color(0xFFFF3B5C),
          surface: Color(0xFF16161E),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class SourceProvider {
  final String id;
  final String name;
  final String version;
  final String type; // 'anime', 'movie', 'manga', 'novel'
  final String lang;
  final String file;
  final String? logo;
  final String repoName;
  final String baseUrl;

  SourceProvider({
    required this.id,
    required this.name,
    required this.version,
    required this.type,
    required this.lang,
    required this.file,
    this.logo,
    required this.repoName,
    required this.baseUrl,
  });

  factory SourceProvider.fromJson(
    Map<String, dynamic> json,
    String repoName,
    String baseUrl,
  ) {
    return SourceProvider(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      version: json['version'] ?? '1.0.0',
      type: json['type'] ?? 'anime',
      lang: json['lang'] ?? 'en',
      file: json['file'] ?? '',
      logo: json['logo'],
      repoName: repoName,
      baseUrl: baseUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'type': type,
        'lang': lang,
        'file': file,
        'logo': logo,
        'repoName': repoName,
        'baseUrl': baseUrl,
      };
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 2; // Starts on Sources tab by default if empty
  List<SourceProvider> _installedSources = [];
  List<Map<String, String>> _myList = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final sourcesRaw = prefs.getStringList('installed_sources') ?? [];
    final listRaw = prefs.getStringList('my_local_watchlist') ?? [];

    setState(() {
      _installedSources = sourcesRaw
          .map((item) {
            final map = jsonDecode(item) as Map<String, dynamic>;
            return SourceProvider.fromJson(
              map,
              map['repoName'] ?? 'zangetsu-providers',
              map['baseUrl'] ?? '',
            );
          })
          .toList();

      _myList = listRaw
          .map((item) => Map<String, String>.from(jsonDecode(item)))
          .toList();
    });
  }

  Future<void> _addManifestRepo(String manifestUrl) async {
    try {
      final uri = Uri.parse(manifestUrl.trim());
      if (!uri.isScheme('HTTPS')) {
        _showMessage('Shudhu HTTPS secure manifest link bebohar koro.');
        return;
      }

      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        _showMessage('Manifest load kora jayni (HTTP ${response.statusCode})');
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final repoName = (data['name'] ?? 'zangetsu-providers')
          .toString()
          .toLowerCase()
          .replaceAll(' ', '-');
      final List<dynamic> sourcesJson = data['sources'] ?? [];

      final baseUrl = manifestUrl.substring(0, manifestUrl.lastIndexOf('/') + 1);

      final fetchedSources = sourcesJson
          .where((s) => s['nsfw'] != true) // Safe filter by default
          .map((s) => SourceProvider.fromJson(s, repoName, baseUrl))
          .toList();

      final prefs = await SharedPreferences.getInstance();
      final encoded = fetchedSources.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList('installed_sources', encoded);

      setState(() {
        _installedSources = fetchedSources;
      });
      _showMessage('${fetchedSources.length} ti source safely add hoyeche!');
    } catch (e) {
      _showMessage('Invalid manifest link othoba network somossa: $e');
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _showAddRepoModal() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16161E),
        title: const Text('Add Source Manifest (index.json)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'https://raw.githubusercontent.com/.../index.json',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B5C),
            ),
            onPressed: () {
              final url = controller.text.trim();
              Navigator.pop(ctx);
              if (url.isNotEmpty) {
                _addManifestRepo(url);
              }
            },
            child: const Text('Add Safely'),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return Center(
      child: _installedSources.isEmpty
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.movie_filter_outlined, size: 64, color: Colors.white54),
                const SizedBox(height: 16),
                const Text(
                  'Kono Source ekhono add kora hoyni',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _selectedIndex = 2),
                  icon: const Icon(Icons.extension),
                  label: const Text('Sources Tab-e Jao'),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _installedSources.length,
              itemBuilder: (context, idx) {
                final src = _installedSources[idx];
                return Card(
                  color: const Color(0xFF16161E),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFF3B5C),
                      child: Icon(Icons.play_arrow, color: Colors.white),
                    ),
                    title: Text(src.name),
                    subtitle: Text('Active Provider • ${src.type.toUpperCase()}'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMyListTab() {
    if (_myList.isEmpty) {
      return const Center(
        child: Text(
          'Tomar Local Watchlist khali.
(100% Offline Saved — No Cloud Tracking)',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60),
        ),
      );
    }
    return ListView.builder(
      itemCount: _myList.length,
      itemBuilder: (context, index) {
        final item = _myList[index];
        return ListTile(
          title: Text(item['title'] ?? ''),
          subtitle: Text(item['source'] ?? ''),
        );
      },
    );
  }

  Widget _buildSourcesTab() {
    final filtered = _installedSources
        .where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Color(0xFFFF3B5C),
            labelColor: Color(0xFFFF3B5C),
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Streaming'),
              Tab(text: 'Manga'),
              Tab(text: 'Novel'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search sources',
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1A1B24),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildSourceList(filtered.where((s) => s.type == 'anime' || s.type == 'movie').toList()),
                _buildSourceList(filtered.where((s) => s.type == 'manga').toList()),
                _buildSourceList(filtered.where((s) => s.type == 'novel').toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceList(List<SourceProvider> list) {
    if (list.isEmpty) {
      return Center(
        child: TextButton.icon(
          onPressed: _showAddRepoModal,
          icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFF3B5C)),
          label: const Text(
            'Tap here to add index.json manifest',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final s = list[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF252634),
            child: Text(
              s.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          title: Text(
            s.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          subtitle: Text(
            s.repoName,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildHomeTab(),
      _buildMyListTab(),
      _buildSourcesTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _selectedIndex == 0
              ? 'Home'
              : _selectedIndex == 1
                  ? 'My List'
                  : 'Sources',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_selectedIndex == 2)
            IconButton(
              icon: const Icon(Icons.add_link),
              tooltip: 'Add index.json Repo',
              onPressed: _showAddRepoModal,
            ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: const Color(0xFF16161E),
          borderRadius: BorderRadius.circular(28),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFFFF3B5C),
          unselectedItemColor: Colors.white60,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bookmark_border),
              label: 'My List',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.extension_outlined),
              label: 'Sources',
            ),
          ],
        ),
      ),
    );
  }
}
