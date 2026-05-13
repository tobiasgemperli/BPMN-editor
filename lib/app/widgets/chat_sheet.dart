import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../diagram/edit/editor_controller.dart';
import '../../diagram/model/diagram_model.dart';

const _mistralApiKey = 'YlJe3gf4rtnSuhKvA8gzIBfpr8Uoomvo';
const _mistralModel = 'mistral-small-latest';

const _systemPrompt = '''
You are a BPMN diagram assistant. The user describes a process and you generate a JSON diagram.

Respond ONLY with a JSON object, no markdown, no explanation. The JSON schema:

{
  "nodes": [
    {"id": "n1", "type": "startEvent", "name": "Start", "x": 200, "y": 80},
    {"id": "n2", "type": "task", "name": "Do something", "x": 200, "y": 210},
    {"id": "n3", "type": "exclusiveGateway", "name": "Decision?", "x": 200, "y": 340},
    {"id": "n4", "type": "endEvent", "name": "End", "x": 200, "y": 470}
  ],
  "edges": [
    {"id": "e1", "source": "n1", "target": "n2"},
    {"id": "e2", "source": "n2", "target": "n3"},
    {"id": "e3", "source": "n3", "target": "n4", "name": "Yes"}
  ]
}

Node types: startEvent, endEvent, task, exclusiveGateway.
Layout rules:
- Use a vertical top-down layout with x=200 for the main column.
- Vertical spacing: 130px between rows, starting y=80.
- For branches from gateways, offset x by ±170.
- Every diagram must have exactly 1 startEvent and at least 1 endEvent.
- Edge "name" is optional, use it for gateway branch labels (e.g. "Yes", "No").
''';

/// Shows the AI chat sheet for generating diagrams.
void showChatSheet(BuildContext context, EditorController controller) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: _ChatSheet(controller: controller),
    ),
  );
}

class _ChatSheet extends StatefulWidget {
  final EditorController controller;
  const _ChatSheet({required this.controller});

  @override
  State<_ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<_ChatSheet> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;
  bool _showHint = true;

  @override
  void initState() {
    super.initState();
    // Auto-focus the text field after the sheet animates in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _loading) return;

    _textController.clear();
    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _loading = true;
      _showHint = false;
    });
    _scrollToBottom();

    try {
      final response = await _callMistral(text);
      final diagram = _parseDiagram(response);
      if (diagram != null) {
        widget.controller.loadDiagram(diagram);
        widget.controller.autoLayout();
        setState(() {
          _messages.add(_ChatMessage(
            role: 'assistant',
            text: 'Diagram created with ${diagram.nodes.length} nodes.',
          ));
        });
        if (mounted) Navigator.pop(context);
      } else {
        setState(() {
          _messages.add(_ChatMessage(role: 'assistant', text: response));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', text: 'Error: $e'));
      });
    } finally {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  Future<String> _callMistral(String userMessage) async {
    final apiMessages = [
      {'role': 'system', 'content': _systemPrompt},
      for (final m in _messages)
        {'role': m.role, 'content': m.text},
    ];

    final resp = await http.post(
      Uri.parse('https://api.mistral.ai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_mistralApiKey',
      },
      body: jsonEncode({
        'model': _mistralModel,
        'messages': apiMessages,
        'temperature': 0.3,
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('Mistral API error ${resp.statusCode}: ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = json['choices'] as List;
    return (choices.first['message']['content'] as String).trim();
  }

  DiagramModel? _parseDiagram(String response) {
    try {
      var jsonStr = response;
      final codeBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
      final match = codeBlock.firstMatch(jsonStr);
      if (match != null) jsonStr = match.group(1)!.trim();

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final nodesList = json['nodes'] as List;
      final edgesList = json['edges'] as List;

      final nodes = <String, NodeModel>{};
      for (final n in nodesList) {
        final id = n['id'] as String;
        final typeStr = n['type'] as String;
        final name = (n['name'] as String?) ?? '';
        final x = (n['x'] as num).toDouble();
        final y = (n['y'] as num).toDouble();
        final type = switch (typeStr) {
          'startEvent' => NodeType.startEvent,
          'endEvent' => NodeType.endEvent,
          'exclusiveGateway' => NodeType.exclusiveGateway,
          _ => NodeType.task,
        };
        nodes[id] = NodeModel(
          id: id,
          type: type,
          name: name,
          rect: NodeModel.defaultRect(type, Offset(x, y)),
        );
      }

      final edges = <String, EdgeModel>{};
      for (final e in edgesList) {
        final id = e['id'] as String;
        edges[id] = EdgeModel(
          id: id,
          sourceId: e['source'] as String,
          targetId: e['target'] as String,
          name: (e['name'] as String?) ?? '',
        );
      }

      if (nodes.isEmpty) return null;
      return DiagramModel(nodes: nodes, edges: edges);
    } catch (_) {
      return null;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar.
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Messages (only shown after first send).
          if (_messages.isNotEmpty) ...[
            const Divider(height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ListView.builder(
                controller: _scrollController,
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (_, i) => _MessageBubble(message: _messages[i]),
              ),
            ),
          ],
          // Loading indicator.
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          // Input field.
          Padding(
            padding: EdgeInsets.fromLTRB(
                12, 8, 8, bottomPad > 0 ? bottomPad : 8),
            child: Stack(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        style:
                            const TextStyle(color: Color(0xFF1C1C1E)),
                        decoration: InputDecoration(
                          hintText: 'Describe your process...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide:
                                BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide:
                                BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                                color: Color(0xFF007AFF)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF007AFF),
                        ),
                        child: const Icon(Icons.arrow_upward,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                // First-time info overlay — appears above the input.
                if (_showHint && _messages.isEmpty)
                  Positioned(
                    bottom: 52,
                    left: 0,
                    right: 48,
                    child: GestureDetector(
                      onTap: () => setState(() => _showHint = false),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.auto_awesome,
                                    size: 16,
                                    color: Color(0xFF007AFF)),
                                SizedBox(width: 6),
                                Text(
                                  'AI Diagram Builder',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1C1C1E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Describe a process and I\'ll create a BPMN diagram.\n'
                              'e.g. "Customer order flow with payment check"',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String text;
  const _ChatMessage({required this.role, required this.text});
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF007AFF) : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
