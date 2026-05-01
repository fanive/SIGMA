/// Stateful stream filter: removes <think>…</think> and <thinking>…</thinking>
/// blocks from a chunk-by-chunk AI stream.
///
/// Because the opening/closing tags may be split across separate chunks, a
/// simple regex on each individual chunk is insufficient. This transformer
/// buffers just enough to detect tag boundaries.
Stream<String> stripThinkBlocks(Stream<String> source) async* {
  bool inThink = false;
  String buffer = '';

  await for (final chunk in source) {
    buffer += chunk;

    // Process as much of the buffer as possible.
    bool keepGoing = true;
    while (keepGoing && buffer.isNotEmpty) {
      if (inThink) {
        // Look for the end of the think block.
        for (final closeTag in const ['</think>', '</thinking>']) {
          final end = buffer.indexOf(closeTag);
          if (end != -1) {
            inThink = false;
            buffer = buffer.substring(end + closeTag.length);
            break;
          }
        }
        if (inThink) {
          // Still inside — keep only the last few chars in case the closing
          // tag is split across the boundary. Max tag length is '</thinking>'
          // = 11 chars, so guard with 12.
          const kGuard = 12;
          if (buffer.length > kGuard) {
            buffer = buffer.substring(buffer.length - kGuard);
          }
          keepGoing = false;
        }
      } else {
        // Look for an opening think tag.
        int openStart = -1;
        String foundTag = '';
        for (final openTag in const ['<think>', '<thinking>']) {
          final idx = buffer.indexOf(openTag);
          if (idx != -1 && (openStart == -1 || idx < openStart)) {
            openStart = idx;
            foundTag = openTag;
          }
        }

        if (openStart == -1) {
          // No opening tag found — but guard the end in case a partial tag is
          // split across chunks (e.g. buffer ends with '<thi').
          final partial = _partialOpenTagLength(buffer);
          if (partial > 0) {
            // Yield everything that can't be part of an opening tag.
            final safe = buffer.length - partial;
            if (safe > 0) yield buffer.substring(0, safe);
            buffer = buffer.substring(safe);
          } else {
            yield buffer;
            buffer = '';
          }
          keepGoing = false;
        } else {
          // Yield content before the opening tag, then enter think mode.
          if (openStart > 0) yield buffer.substring(0, openStart);
          inThink = true;
          buffer = buffer.substring(openStart + foundTag.length);
        }
      }
    }
  }

  // Flush: if the stream ended outside a think block, emit remaining buffer.
  if (!inThink && buffer.isNotEmpty) {
    yield buffer;
  }
}

/// Returns how many trailing characters of [s] could be the start of an
/// opening think tag ('<think>' or '<thinking>').
int _partialOpenTagLength(String s) {
  const tags = ['<think>', '<thinking>'];
  int maxPartial = 0;
  for (final tag in tags) {
    for (int i = 1; i < tag.length; i++) {
      if (s.endsWith(tag.substring(0, i))) {
        if (i > maxPartial) maxPartial = i;
      }
    }
  }
  return maxPartial;
}
