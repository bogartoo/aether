import 'package:flutter/material.dart';

void main() => runApp(const AetherApp());

class AetherApp extends StatelessWidget {
  const AetherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aether',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5A8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AetherHome(),
    );
  }
}

class AetherHome extends StatefulWidget {
  const AetherHome({super.key});

  @override
  State<AetherHome> createState() => _AetherHomeState();
}

class _AetherHomeState extends State<AetherHome> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[
    _ChatMessage(
      role: 'aether',
      text:
          'Aether online. Hybrid agent ready — Grok, Claude, Gemini, or local Ollama.',
    ),
  ];
  String _provider = 'Ollama (local)';

  static const _providers = [
    'Ollama (local)',
    'Grok',
    'Claude',
    'Gemini',
  ];

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(role: 'you', text: text));
      _messages.add(
        _ChatMessage(
          role: 'aether',
          text:
              '[$_provider] Agent acknowledged: "$text"\n\nTools, memory, and voice pipelines are wired for the next release.',
        ),
      );
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1628), Color(0xFF0D2B24), Color(0xFF061018)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00E5A8), Color(0xFF00B4D8)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5A8).withValues(alpha: 0.35),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.black),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AETHER',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 3,
                            ),
                          ),
                          Text(
                            'Local + hybrid AI agent',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8BA3B5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _provider,
                        dropdownColor: const Color(0xFF12202E),
                        style: const TextStyle(color: Color(0xFF00E5A8), fontSize: 13),
                        items: _providers
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) => setState(() => _provider = v!),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final m = _messages[i];
                    final isYou = m.role == 'you';
                    return Align(
                      alignment: isYou ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(14),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.82,
                        ),
                        decoration: BoxDecoration(
                          color: isYou
                              ? const Color(0xFF00E5A8).withValues(alpha: 0.15)
                              : const Color(0xFF142433),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isYou
                                ? const Color(0xFF00E5A8).withValues(alpha: 0.35)
                                : const Color(0xFF1E3A4C),
                          ),
                        ),
                        child: Text(
                          m.text,
                          style: const TextStyle(height: 1.4, fontSize: 15),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Message Aether…',
                          filled: true,
                          fillColor: const Color(0xFF12202E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _send,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5A8),
                        foregroundColor: Colors.black,
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(14),
                      ),
                      child: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String text;
  _ChatMessage({required this.role, required this.text});
}
