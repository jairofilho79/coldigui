import 'package:coldigui/core/utils/pdf_id_codec.dart';
import 'package:coldigui/features/offline/domain/entities/offline_audio_entry.dart';
import 'package:coldigui/features/offline/domain/entities/offline_pdf_entry.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_audio_repository.dart';
import 'package:coldigui/features/offline/domain/repositories/offline_pdf_repository.dart';
import 'package:coldigui/features/offline/domain/usecases/remove_coldigom_downloads.dart';
import 'package:flutter_test/flutter_test.dart';

class _PdfRepo implements OfflinePdfRepository {
  _PdfRepo(this.entries);
  final List<OfflinePdfEntry> entries;
  final removed = <String>[];

  @override
  Future<List<OfflinePdfEntry>> listAll() async => entries;

  @override
  Future<void> remove(String pdfId) async => removed.add(pdfId);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

class _AudioRepo implements OfflineAudioRepository {
  var removeAllCalls = 0;
  @override
  Future<void> removeAll() async => removeAllCalls++;
  @override
  Future<List<OfflineAudioEntry>> listAll() async => const [];
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

OfflinePdfEntry _entry(String path, {required bool persistent}) =>
    OfflinePdfEntry(
      pdfId: encodePdfId(path),
      absolutePath: '/x/$path',
      category: 'x',
      fileSize: 1,
      downloadedAt: DateTime(2026),
      isPersistent: persistent,
    );

void main() {
  test(
    'remove áudios (tudo) e só PDFs Coldigom persistentes; PLPCG e LRU ficam',
    () async {
      final pdfRepo = _PdfRepo([
        _entry('assets/praises/p1/a.pdf', persistent: true),
        _entry('assets/praises/p1/b.pdf', persistent: false),
        _entry('ColAdultos/001.pdf', persistent: true),
      ]);
      final audioRepo = _AudioRepo();

      final result = await RemoveColdigomDownloads(
        pdfRepository: pdfRepo,
        audioRepository: audioRepo,
      ).call();

      expect(pdfRepo.removed, [encodePdfId('assets/praises/p1/a.pdf')]);
      expect(audioRepo.removeAllCalls, 1);
      expect(result.removedPdfs, 1);
    },
  );
}
