class WordTranscription {
  final String word;
  final double start;
  final double? end;

  WordTranscription(this.word, this.start, this.end);
}

class ASRResult {
  final bool isFinal;
  final List<WordTranscription> words;

  ASRResult(this.isFinal, this.words);
}
