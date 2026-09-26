import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../core/keyboard_controller.dart';

class DocumentContextScreen extends StatefulWidget {
  const DocumentContextScreen({super.key});

  @override
  State<DocumentContextScreen> createState() => _DocumentContextScreenState();
}

class _DocumentContextScreenState extends State<DocumentContextScreen> {
  String? _fileName;
  bool _loading = false;
  String? _error;

  Future<void> _pickDocument() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'txt', 'md', 'markdown'],
      );
      if (result.isEmpty) { setState(() => _loading = false); return; }
      final file = result.single;
      final path = file.path;
      if (path == null || path.isEmpty) throw Exception('Could not read the selected file.');
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) throw Exception('The selected file is empty.');
      final text = await _extract(file.name, bytes);
      if (text.trim().isEmpty) throw Exception('No readable text was found.');
      final clipped = text.trim().length > 24000 ? text.trim().substring(0, 24000) : text.trim();
      if (!mounted) return;
      context.read<KeyboardController>().setVoiceContext(clipped);
      context.read<KeyboardController>().setContextAware(true);
      setState(() { _fileName = file.name; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<String> _extract(String name, Uint8List bytes) async {
    final lower = name.toLowerCase();
    if (!lower.endsWith('.pdf')) return utf8.decode(bytes, allowMalformed: true);
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document).extractText();
    } finally {
      document.dispose();
    }
  }

  void _clear() {
    final kb = context.read<KeyboardController>();
    kb.setVoiceContext('');
    kb.setContextAware(false);
    setState(() => _fileName = null);
  }

  @override
  Widget build(BuildContext context) {
    final kb = context.watch<KeyboardController>();
    final scheme = Theme.of(context).colorScheme;
    final active = kb.voiceContext.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Document context')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [scheme.primary, const Color(0xFF6D28D9)]),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: .24), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30),
              SizedBox(height: 18),
              Text('Give your words more context', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('Add a document and Bhasha will use it as a private writing reference for correction and suggestions.', style: TextStyle(color: Colors.white70, height: 1.4)),
            ]),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(Icons.lock_outline, color: scheme.primary, size: 20), const SizedBox(width: 8), const Text('Private by design', style: TextStyle(fontWeight: FontWeight.w800))]),
                const SizedBox(height: 8),
                Text('Only extracted text is saved locally as your session context. You can replace or remove it any time.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _loading ? null : _pickDocument, icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file_rounded), label: Text(_loading ? 'Reading document…' : 'Upload PDF or text'))),
              ]),
            ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: scheme.error))),
          const SizedBox(height: 12),
          if (active) Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: scheme.primaryContainer, child: Icon(Icons.description_outlined, color: scheme.onPrimaryContainer)),
              title: Text(_fileName ?? 'Context document', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${kb.voiceContext.length} characters • Context-aware writing is on'),
              trailing: IconButton(tooltip: 'Remove context', onPressed: _clear, icon: const Icon(Icons.delete_outline)),
            ),
          ) else const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No document added yet. Upload a PDF, .md, or .txt file to begin.'))),
        ],
      ),
    );
  }
}
