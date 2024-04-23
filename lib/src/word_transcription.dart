class WordTranscription {
  final String word;
  final double start;
  final double? end;

  WordTranscription(this.word, this.start, this.end);
}

class ASRResult {
  final bool isFinal;
  final List<WordTranscription> words;

  late final String _joined;
  String join({String sep = "#"}) {
    return words.map((w) => w.word).join(sep);
  }

  ASRResult(this.isFinal, this.words);

  @override
  String toString() {
    return "ASRResult(final=$isFinal,words='${join(sep: '')}')";
  }
}
