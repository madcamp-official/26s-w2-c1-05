import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 모든 LLM 요청/응답을 로컬 JSONL 파일에 append (향후 QLoRA 데이터 — FSD §6.4).
/// 파일: 앱 문서 디렉터리의 `llm_log.jsonl`.
class LlmLogger {
  File? _file;

  Future<File> _ensureFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    return _file = File('${dir.path}/llm_log.jsonl');
  }

  Future<void> log(Map<String, dynamic> entry) async {
    final file = await _ensureFile();
    await file.writeAsString(
      '${jsonEncode({'ts': DateTime.now().toIso8601String(), ...entry})}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  /// 로그 파일 경로 (스파이크 화면에서 표시용).
  Future<String> get path async => (await _ensureFile()).path;
}
