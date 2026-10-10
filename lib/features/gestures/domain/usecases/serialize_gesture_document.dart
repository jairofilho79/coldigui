import 'dart:convert';

import '../entities/gesture_document.dart';

/// Serializa um [GestureItem] para o formato JSON esperado pelo parser (`coldigom.gestures/1`).
Map<String, dynamic> gestureItemToJson(GestureItem item) {
  return switch (item) {
    GestureCard(:final gestureId, :final lyrics) => {
      'type': 'gesture',
      'gestureId': gestureId,
      'lyrics': [
        for (final line in lyrics)
          {'trigger': line.trigger, 'text': line.text},
      ],
    },
    RepeatBlock(:final count, :final children) => {
      'type': 'repeat',
      'count': count,
      'children': [for (final c in children) gestureItemToJson(c)],
    },
    ChorusBlock(:final children) => {
      'type': 'coro',
      'children': [for (final c in children) gestureItemToJson(c)],
    },
    LinkBlock(:final children) => {
      'type': 'link',
      'children': [for (final c in children) gestureItemToJson(c)],
    },
    FinalBlock(:final children) => {
      'type': 'final',
      'children': [for (final c in children) gestureItemToJson(c)],
    },
    InstructionCard(:final kind) => {
      'type': 'instruction',
      'kind': switch (kind) {
        InstructionKind.instruments => 'instruments',
        InstructionKind.repeatPraise => 'repeat_praise',
        InstructionKind.backToChorus => 'back_to_chorus',
        InstructionKind.backToChorusAndFinish => 'back_to_chorus_and_finish',
      },
    },
    TextLine(:final text) => {
      'type': 'text',
      'text': text,
    },
    SectionLabel() => {
      'type': 'text',
      'text': '',
    },
  };
}

/// Converte [GestureDocument] para `Map<String, dynamic>`.
Map<String, dynamic> gestureDocumentToMap(GestureDocument doc) {
  return {
    'schema': 'coldigom.gestures/${doc.schemaMajor}',
    'title': doc.title,
    'dictionaryVersion': doc.dictionaryVersion,
    'items': [for (final item in doc.items) gestureItemToJson(item)],
  };
}

/// Serializa um [GestureDocument] para string JSON formatada (indentada).
String serializeGestureDocument(GestureDocument doc) {
  return const JsonEncoder.withIndent('  ').convert(gestureDocumentToMap(doc));
}
