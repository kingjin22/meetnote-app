import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentThemeMode;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.currentThemeMode,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeMode _selectedThemeMode;

  @override
  void initState() {
    super.initState();
    _selectedThemeMode = widget.currentThemeMode;
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    setState(() {
      _selectedThemeMode = mode;
    });
    widget.onThemeChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          _buildSection(
            '테마',
            [
              ListTile(
                title: const Text('라이트 모드'),
                leading: const Icon(Icons.light_mode),
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: _selectedThemeMode,
                  onChanged: (value) {
                    if (value != null) _saveThemeMode(value);
                  },
                ),
                onTap: () => _saveThemeMode(ThemeMode.light),
              ),
              ListTile(
                title: const Text('다크 모드'),
                leading: const Icon(Icons.dark_mode),
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: _selectedThemeMode,
                  onChanged: (value) {
                    if (value != null) _saveThemeMode(value);
                  },
                ),
                onTap: () => _saveThemeMode(ThemeMode.dark),
              ),
              ListTile(
                title: const Text('시스템 설정 따르기'),
                leading: const Icon(Icons.settings_system_daydream),
                trailing: Radio<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: _selectedThemeMode,
                  onChanged: (value) {
                    if (value != null) _saveThemeMode(value);
                  },
                ),
                onTap: () => _saveThemeMode(ThemeMode.system),
              ),
            ],
          ),
          const Divider(),
          _buildSection(
            '정보',
            [
              const ListTile(
                title: Text('버전'),
                subtitle: Text('1.0.0'),
                leading: Icon(Icons.info_outline),
              ),
              ListTile(
                title: const Text('개발자 정보'),
                subtitle: const Text('MeetNote Team'),
                leading: const Icon(Icons.code),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'MeetNote',
                    applicationVersion: '1.0.0',
                    applicationLegalese: '© 2024 MeetNote Team',
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        'AI 기반 회의록 자동 생성 앱\n'
                        '음성을 텍스트로 변환하고 회의록을 자동으로 생성합니다.',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ...children,
      ],
    );
  }
}
