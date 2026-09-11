import 'dart:convert';
import 'dart:typed_data';

/// PNG 1×1 transparente — bytes válidos para `Image.memory` nos testes.
const kGestureTestPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

Uint8List gestureTestPng() => base64Decode(kGestureTestPngBase64);
