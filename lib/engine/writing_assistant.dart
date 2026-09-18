/// Lightweight writing assistant used by the keyboard's Text Editing panel.
/// The interface is provider-ready: these safe offline transforms work without
/// network access, while a Gemini provider can be added behind the same API.
library;

class WritingAssistant {
  const WritingAssistant();

  String fixGrammar(String input) {
    var text = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return text;
    text = text.replaceAll(RegExp(r'\s+([,.!?])'), r'\1');
    text = text.replaceAll(RegExp(r'([.!?])([A-Za-z])'), r'\1 \2');
    text = text[0].toUpperCase() + text.substring(1);
    if (!RegExp(r'[.!?]$').hasMatch(text)) text = '$text.';
    return text;
  }

  String rewrite(String input, {WritingTone tone = WritingTone.clear}) {
    final cleaned = fixGrammar(input);
    if (cleaned.isEmpty) return cleaned;
    switch (tone) {
      case WritingTone.clear:
        return cleaned;
      case WritingTone.formal:
        return cleaned
            .replaceAll(
              RegExp(r'\b(can’t|cant)\b', caseSensitive: false),
              'cannot',
            )
            .replaceAll(
              RegExp(r'\bthanks\b', caseSensitive: false),
              'thank you',
            )
            .replaceAll(RegExp(r'\bhey\b', caseSensitive: false), 'Hello');
      case WritingTone.friendly:
        return cleaned.replaceFirst(RegExp(r'\.$'), ' 😊.');
      case WritingTone.concise:
        final parts = cleaned.split(RegExp(r'[,;]'));
        return parts.first.trim().replaceFirst(RegExp(r'\.$'), '.');
    }
  }

  String suggestReply(String input) {
    final text = input.toLowerCase();
    if (text.contains('thank')) return 'You’re welcome!';
    if (text.contains('meeting') || text.contains('call')) {
      return 'Sure, that works for me. What time should we meet?';
    }
    if (text.contains('?')) {
      return 'Thanks for asking. I’ll get back to you shortly.';
    }
    return 'Thanks for your message. I’ll reply soon.';
  }
}

enum WritingTone { clear, formal, friendly, concise }
