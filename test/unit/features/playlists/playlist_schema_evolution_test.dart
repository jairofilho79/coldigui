@TestOn('vm')
library;

import 'dart:io';

import 'package:coldigui/core/database/collections/playlist.dart';
import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/playlists/data/datasources/playlist_local_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_plus/isar_plus.dart';

final pdfA = encodePdfId('ColAdultos/001.pdf');
final pdfB = encodePdfId('ColAdultos/002.pdf');
final audioA = encodePdfId('assets/praises/a/001.mp3');

/// Áudio do Worker com container fora de `kAudioMaterialExtensions`.
final audioMisfiled = encodePdfId('assets/praises/a/001.mid');

/// Schema `Playlist` **anterior** à coluna `items` (propriedade 18).
///
/// Espelha `playlist.g.dart` sem a última propriedade: é a base que um build
/// pré-branch deixou gravada no navegador do usuário. A evidência que este
/// teste produz é que reabrir a mesma base com o schema novo não perde a linha.
final _legacyPlaylistSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'Playlist',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'playlistId', type: IsarType.string),
      IsarPropertySchema(name: 'nome', type: IsarType.string),
      IsarPropertySchema(name: 'pdfIds', type: IsarType.stringList),
      IsarPropertySchema(name: 'audioIds', type: IsarType.stringList),
      IsarPropertySchema(name: 'createdAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'salva', type: IsarType.bool),
      IsarPropertySchema(name: 'savedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'favoritedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'favorita', type: IsarType.bool),
      IsarPropertySchema(name: 'updatedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'version', type: IsarType.long),
      IsarPropertySchema(name: 'syncStatusIndex', type: IsarType.long),
      IsarPropertySchema(name: 'deletedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'isPublished', type: IsarType.bool),
      IsarPropertySchema(name: 'publicationReachIndex', type: IsarType.long),
      IsarPropertySchema(name: 'publicationCategoryIndex', type: IsarType.long),
      IsarPropertySchema(name: 'publishedAt', type: IsarType.dateTime),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'playlistId',
        properties: ['playlistId'],
        unique: true,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, Playlist>(
    serialize: _serializeLegacyPlaylist,
    deserialize: _deserializeLegacyPlaylist,
    deserializeProperty: _deserializeLegacyPlaylistProp,
  ),
  getEmbeddedSchemas: () => [],
);

/// Schema `Playlist` da **fatia 1**: já tem `items` (propriedade 18), ainda não
/// tem `itemKinds` (propriedade 19).
final _sliceOnePlaylistSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'Playlist',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'playlistId', type: IsarType.string),
      IsarPropertySchema(name: 'nome', type: IsarType.string),
      IsarPropertySchema(name: 'pdfIds', type: IsarType.stringList),
      IsarPropertySchema(name: 'audioIds', type: IsarType.stringList),
      IsarPropertySchema(name: 'createdAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'salva', type: IsarType.bool),
      IsarPropertySchema(name: 'savedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'favoritedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'favorita', type: IsarType.bool),
      IsarPropertySchema(name: 'updatedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'version', type: IsarType.long),
      IsarPropertySchema(name: 'syncStatusIndex', type: IsarType.long),
      IsarPropertySchema(name: 'deletedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'isPublished', type: IsarType.bool),
      IsarPropertySchema(name: 'publicationReachIndex', type: IsarType.long),
      IsarPropertySchema(name: 'publicationCategoryIndex', type: IsarType.long),
      IsarPropertySchema(name: 'publishedAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'items', type: IsarType.stringList),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'playlistId',
        properties: ['playlistId'],
        unique: true,
        hash: false,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, Playlist>(
    serialize: _serializeSliceOnePlaylist,
    deserialize: _deserializeSliceOnePlaylist,
    deserializeProperty: _deserializeLegacyPlaylistProp,
  ),
  getEmbeddedSchemas: () => [],
);

int _serializeSliceOnePlaylist(IsarWriter writer, Playlist object) {
  _serializeLegacyPlaylist(writer, object);
  _writeStringList(writer, 18, object.items);
  return object.id;
}

Playlist _deserializeSliceOnePlaylist(IsarReader reader) =>
    _deserializeLegacyPlaylist(reader)..items = _readStringList(reader, 18);

const _nullLong = -9223372036854775808;

int _serializeLegacyPlaylist(IsarWriter writer, Playlist object) {
  IsarCore.writeString(writer, 1, object.playlistId);
  IsarCore.writeString(writer, 2, object.nome);
  _writeStringList(writer, 3, object.pdfIds);
  _writeStringList(writer, 4, object.audioIds);
  IsarCore.writeLong(
    writer,
    5,
    object.createdAt.toUtc().microsecondsSinceEpoch,
  );
  IsarCore.writeBool(writer, 6, value: object.salva);
  IsarCore.writeLong(
    writer,
    7,
    object.savedAt?.toUtc().microsecondsSinceEpoch ?? _nullLong,
  );
  IsarCore.writeLong(
    writer,
    8,
    object.favoritedAt?.toUtc().microsecondsSinceEpoch ?? _nullLong,
  );
  IsarCore.writeBool(writer, 9, value: object.favorita);
  IsarCore.writeLong(
    writer,
    10,
    object.updatedAt.toUtc().microsecondsSinceEpoch,
  );
  IsarCore.writeLong(writer, 11, object.version);
  IsarCore.writeLong(writer, 12, object.syncStatusIndex);
  IsarCore.writeLong(
    writer,
    13,
    object.deletedAt?.toUtc().microsecondsSinceEpoch ?? _nullLong,
  );
  IsarCore.writeBool(writer, 14, value: object.isPublished);
  IsarCore.writeLong(writer, 15, object.publicationReachIndex ?? _nullLong);
  IsarCore.writeLong(writer, 16, object.publicationCategoryIndex ?? _nullLong);
  IsarCore.writeLong(
    writer,
    17,
    object.publishedAt?.toUtc().microsecondsSinceEpoch ?? _nullLong,
  );
  return object.id;
}

void _writeStringList(IsarWriter writer, int index, List<String> list) {
  final listWriter = IsarCore.beginList(writer, index, list.length);
  for (var i = 0; i < list.length; i++) {
    IsarCore.writeString(listWriter, i, list[i]);
  }
  IsarCore.endList(writer, listWriter);
}

List<String> _readStringList(IsarReader reader, int index) {
  final length = IsarCore.readList(reader, index, IsarCore.readerPtrPtr);
  final listReader = IsarCore.readerPtr;
  if (listReader.isNull) return const <String>[];
  final list = List<String>.filled(length, '', growable: true);
  for (var i = 0; i < length; i++) {
    list[i] = IsarCore.readString(listReader, i) ?? '';
  }
  IsarCore.freeReader(listReader);
  return list;
}

DateTime? _readOptionalDate(IsarReader reader, int index) {
  final value = IsarCore.readLong(reader, index);
  if (value == _nullLong) return null;
  return DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true).toLocal();
}

Playlist _deserializeLegacyPlaylist(IsarReader reader) {
  return Playlist()
    ..id = IsarCore.readId(reader)
    ..playlistId = IsarCore.readString(reader, 1) ?? ''
    ..nome = IsarCore.readString(reader, 2) ?? ''
    ..pdfIds = _readStringList(reader, 3)
    ..audioIds = _readStringList(reader, 4)
    ..createdAt =
        _readOptionalDate(reader, 5) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal()
    ..salva = IsarCore.readBool(reader, 6)
    ..savedAt = _readOptionalDate(reader, 7)
    ..favoritedAt = _readOptionalDate(reader, 8)
    ..favorita = IsarCore.readBool(reader, 9)
    ..updatedAt =
        _readOptionalDate(reader, 10) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal()
    ..version = IsarCore.readLong(reader, 11)
    ..syncStatusIndex = IsarCore.readLong(reader, 12)
    ..deletedAt = _readOptionalDate(reader, 13)
    ..isPublished = IsarCore.readBool(reader, 14)
    ..publicationReachIndex = _readNullableLong(reader, 15)
    ..publicationCategoryIndex = _readNullableLong(reader, 16)
    ..publishedAt = _readOptionalDate(reader, 17);
}

int? _readNullableLong(IsarReader reader, int index) {
  final value = IsarCore.readLong(reader, index);
  return value == _nullLong ? null : value;
}

dynamic _deserializeLegacyPlaylistProp(IsarReader reader, int property) {
  return switch (property) {
    0 => IsarCore.readId(reader),
    1 => IsarCore.readString(reader, 1) ?? '',
    2 => IsarCore.readString(reader, 2) ?? '',
    _ => throw UnimplementedError(
      'propriedade $property não usada pelo teste de evolução de schema',
    ),
  };
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('playlist_schema_evo_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'base gravada sem a coluna items sobrevive ao schema novo (A9)',
    () async {
      // Build antigo: escreve a linha com o schema sem `items`.
      final legacy = Isar.open(
        schemas: [_legacyPlaylistSchema],
        directory: tempDir.path,
        name: 'evolucao',
        engine: IsarEngine.sqlite,
      );
      legacy.write((isar) {
        isar.playlists.put(
          Playlist()
            ..id = 1
            ..playlistId = 'antiga'
            ..nome = 'Ensaio'
            ..pdfIds = [pdfA, pdfB]
            ..audioIds = [audioA]
            ..createdAt = DateTime.utc(2026, 8, 1)
            ..salva = true
            ..savedAt = DateTime.utc(2026, 8, 1)
            ..updatedAt = DateTime.utc(2026, 8, 1),
        );
      });
      legacy.close();

      // Build novo: mesmo diretório/nome, schema com a coluna `items`.
      final upgraded = Isar.open(
        schemas: [PlaylistSchema],
        directory: tempDir.path,
        name: 'evolucao',
        engine: IsarEngine.sqlite,
      );
      addTearDown(() => upgraded.close());

      // Controle: a coluna nova nasce vazia na base antiga — ou seja, a linha
      // realmente veio de um arquivo gravado sem a propriedade 18.
      final raw = upgraded.playlists
          .where()
          .playlistIdEqualTo('antiga')
          .findFirst();
      expect(raw, isNotNull);
      expect(raw!.items, isEmpty);

      final row = await PlaylistLocalDatasource(
        upgraded,
      ).findByPlaylistId('antiga');

      expect(row, isNotNull, reason: 'a lista do usuário não pode sumir');
      expect(row!.nome, 'Ensaio');
      expect(row.pdfIds, [pdfA, pdfB]);
      expect(row.audioIds, [audioA]);
      expect(
        row.items,
        [pdfA, pdfB, audioA],
        reason: 'a migração lazy preenche a ordem única na primeira leitura',
      );
      expect(row.itemKinds, [
        'pdf',
        'pdf',
        'audio',
      ], reason: 'a mesma leitura já deixa a ordem única tipada');
    },
  );

  test(
    'base da fatia 1 (com items, sem itemKinds) sobrevive ao schema novo (A9)',
    () async {
      // Build da fatia 1: escreve a linha com `items` e sem `itemKinds`.
      final sliceOne = Isar.open(
        schemas: [_sliceOnePlaylistSchema],
        directory: tempDir.path,
        name: 'fatia1',
        engine: IsarEngine.sqlite,
      );
      sliceOne.write((isar) {
        isar.playlists.put(
          Playlist()
            ..id = 1
            ..playlistId = 'fatia1'
            ..nome = 'Ensaio'
            ..pdfIds = [pdfA, pdfB]
            ..audioIds = [audioMisfiled]
            ..items = [pdfA, audioMisfiled, pdfB]
            ..createdAt = DateTime.utc(2026, 8, 1)
            ..salva = true
            ..savedAt = DateTime.utc(2026, 8, 1)
            ..updatedAt = DateTime.utc(2026, 8, 1)
            ..version = 5,
        );
      });
      sliceOne.close();

      // Build novo: mesmo diretório/nome, schema com a coluna `itemKinds`.
      final upgraded = Isar.open(
        schemas: [PlaylistSchema],
        directory: tempDir.path,
        name: 'fatia1',
        engine: IsarEngine.sqlite,
      );
      addTearDown(() => upgraded.close());

      // Controle: a coluna nova nasce vazia na base da fatia 1.
      final raw = upgraded.playlists
          .where()
          .playlistIdEqualTo('fatia1')
          .findFirst();
      expect(raw, isNotNull);
      expect(raw!.itemKinds, isEmpty);

      final row = await PlaylistLocalDatasource(
        upgraded,
      ).findByPlaylistId('fatia1');

      expect(row, isNotNull, reason: 'a lista do usuário não pode sumir');
      expect(row!.items, [pdfA, audioMisfiled, pdfB]);
      expect(row.itemKinds, [
        'pdf',
        'audio',
        'pdf',
      ], reason: 'audioIds é o veredito de quem gravou a linha (A8)');
      expect(row.version, 5, reason: 'a migração não bumpa a versão');
      expect(row.updatedAt.toUtc(), DateTime.utc(2026, 8, 1));
    },
  );
}
