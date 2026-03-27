import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../core/providers/motor_provider.dart';
import '../../core/theme/app_theme.dart';
import 'glass_card.dart';

class AriaChatbot extends StatefulWidget {
  const AriaChatbot({super.key});

  @override
  State<AriaChatbot> createState() => _AriaChatbotState();
}

class _AriaChatbotState extends State<AriaChatbot>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  final List<Map<String, String>> _messages = [
    {
      "role": "aria",
      "content":
          "Hello! I'm ARIA. How can I assist you with the motor systems today?"
    }
  ];
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _msgController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "content": text});
      _isTyping = true;
      _msgController.clear();
    });
    _scrollToBottom();

    try {
      final motor = context.read<MotorProvider>();
      final contextPayload = {
        "motor_state": motor.motorState,
        "connected": motor.connected,
        "vfd": motor.latestData.vfd?.toJson() ?? {},
        "pzem": motor.latestData.pzem?.toJson() ?? {},
      };

      final response = await http.post(
        Uri.parse("http://localhost:8000/api/chat"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "message": text,
          "context": contextPayload,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _messages.add({"role": "aria", "content": data['response']});
        });
      } else {
        setState(() {
          _messages.add({
            "role": "aria",
            "content":
                "I'm having trouble connecting to the logic core. Please try again later."
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          "role": "aria",
          "content": "Network error. Logical sub-systems offline."
        });
      });
    } finally {
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_isExpanded) _buildChatPanel(),
        _buildFloatingButton(),
      ],
    );
  }

  Widget _buildFloatingButton() {
    return Positioned(
      right: 20,
      bottom: 20,
      child: GestureDetector(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary
                        .withValues(alpha: 0.3 * _pulseController.value),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: ClipPath(
                clipper: HexagonClipper(),
                child: Container(
                  color: _isExpanded ? AppColors.accentRed : AppColors.primary,
                  child: Center(
                    child: Icon(
                      _isExpanded
                          ? Icons.close_rounded
                          : Icons.auto_awesome_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      right: 20,
      bottom: 90,
      width: 350,
      height: 500,
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderColor: AppColors.primary.withValues(alpha: 0.4),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.accentGreen, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ARIA AI ASSISTANT',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return _chatBubble("aria", "● ● ●", isTyping: true);
                  }
                  return _chatBubble(
                      _messages[index]["role"]!, _messages[index]["content"]!);
                },
              ),
            ),
            // Input
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(
                        hintText: 'Ask ARIA...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isDark ? Colors.white : AppColors.lightTextPrimary,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(Icons.send_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatBubble(String role, String content, {bool isTyping = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAria = role == 'aria';
    return Align(
      alignment: isAria ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 260),
        decoration: BoxDecoration(
          color: isAria
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05))
              : AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.8),
          borderRadius: BorderRadius.circular(12).copyWith(
            topLeft: isAria ? const Radius.circular(0) : null,
            topRight: !isAria ? const Radius.circular(0) : null,
          ),
          border: Border.all(
            color: isAria
                ? (isDark ? Colors.white12 : Colors.black12)
                : AppColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          content,
          style: TextStyle(
            fontSize: 13,
            color: isAria
                ? (isDark ? AppColors.textPrimary : AppColors.lightTextPrimary)
                : Colors.white,
            fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width, size.height * 0.25);
    path.lineTo(size.width, size.height * 0.75);
    path.lineTo(size.width * 0.5, size.height);
    path.lineTo(0, size.height * 0.75);
    path.lineTo(0, size.height * 0.25);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
