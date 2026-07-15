// 실 LLM e2e 검증용 유틸 — 보스의 실제 시스템 프롬프트를 stdout으로 출력.
// 사용: dart run tool/print_prompt.dart <bossId>
import 'dart:io';

import 'package:mosimosi/core/data/bosses.dart';

void main(List<String> args) {
  final boss = bossById(args.isEmpty ? 'chicken' : args[0]);
  if (boss == null) {
    stderr.writeln('unknown boss id');
    exit(1);
  }
  stdout.write(boss.buildSystemPrompt(const []));
}
