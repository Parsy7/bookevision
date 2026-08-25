import 'answer.dart';
import 'manual_edit.dart';

/// Estado de trabajo de una revisión: respuestas + ediciones manuales.
/// Corresponde a `GET/PUT /revisiones/{id}/estado`.
class ReviewState {
  final List<Answer> answers;
  final Map<String, ManualEdit> manualEdits;

  const ReviewState({required this.answers, required this.manualEdits});

  factory ReviewState.fromJson(Map<String, dynamic> j) {
    final answers = ((j['answers'] as List?) ?? const [])
        .map((e) => Answer.fromJson(e as Map<String, dynamic>))
        .toList();
    final rawEdits = (j['manualEdits'] as Map?) ?? const {};
    final edits = <String, ManualEdit>{};
    rawEdits.forEach((k, v) {
      edits[k as String] = ManualEdit.fromJson(v as Map<String, dynamic>);
    });
    return ReviewState(answers: answers, manualEdits: edits);
  }

  Map<String, dynamic> toJson() => {
        'answers': answers.map((a) => a.toJson()).toList(),
        'manualEdits':
            manualEdits.map((k, v) => MapEntry(k, v.toJson())),
      };
}
