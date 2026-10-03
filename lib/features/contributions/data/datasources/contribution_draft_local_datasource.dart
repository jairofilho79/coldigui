import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_prefs_provider.dart';
import '../../domain/entities/contribution_draft.dart';
import '../../presentation/providers/contribute_form_provider.dart';

abstract class ContributionDraftLocalDatasource {
  const ContributionDraftLocalDatasource();

  ContributionDraft? read(ContributeFormArgs args);
  Future<void> write(ContributeFormArgs args, ContributionDraft draft);
  Future<void> clear(ContributeFormArgs args);
}

class SharedPreferencesContributionDraftLocalDatasource
    implements ContributionDraftLocalDatasource {
  SharedPreferencesContributionDraftLocalDatasource(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyPrefix = 'contribution_draft.';

  static String keyFor(ContributeFormArgs args) {
    final src = args.target?.source.wireName ?? 'general';
    final praise = args.target?.praiseId ?? 'none';
    final mat = args.target?.materialId ?? 'none';
    return '$_keyPrefix$src.$praise.$mat';
  }

  @override
  ContributionDraft? read(ContributeFormArgs args) {
    try {
      final raw = _prefs.getString(keyFor(args));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return ContributionDraft.fromStorageJson(
        Map<String, dynamic>.from(decoded),
      );
    } catch (e) {
      debugPrint('[contributions] falha ao ler rascunho salvo: $e');
      return null;
    }
  }

  @override
  Future<void> write(ContributeFormArgs args, ContributionDraft draft) async {
    final key = keyFor(args);
    try {
      final jsonStr = jsonEncode(draft.toStorageJson());
      await _prefs.setString(key, jsonStr);
    } catch (e) {
      debugPrint('[contributions] falha ao gravar rascunho com anexos: $e');
      // Se estourar cota do localStorage devido a anexos, tenta salvar sem eles para não perder o texto
      try {
        final textOnly = draft.copyWith(attachments: const []);
        await _prefs.setString(key, jsonEncode(textOnly.toStorageJson()));
      } catch (e2) {
        debugPrint('[contributions] falha ao gravar rascunho texto: $e2');
      }
    }
  }

  @override
  Future<void> clear(ContributeFormArgs args) async {
    try {
      await _prefs.remove(keyFor(args));
    } catch (e) {
      debugPrint('[contributions] falha ao limpar rascunho: $e');
    }
  }
}

class InMemoryContributionDraftLocalDatasource
    implements ContributionDraftLocalDatasource {
  InMemoryContributionDraftLocalDatasource([
    Map<String, ContributionDraft>? initial,
  ]) : _store = initial != null ? Map.of(initial) : {};

  final Map<String, ContributionDraft> _store;

  static String keyFor(ContributeFormArgs args) {
    final src = args.target?.source.wireName ?? 'general';
    final praise = args.target?.praiseId ?? 'none';
    final mat = args.target?.materialId ?? 'none';
    return 'contribution_draft.$src.$praise.$mat';
  }

  @override
  ContributionDraft? read(ContributeFormArgs args) => _store[keyFor(args)];

  @override
  Future<void> write(ContributeFormArgs args, ContributionDraft draft) async {
    _store[keyFor(args)] = draft;
  }

  @override
  Future<void> clear(ContributeFormArgs args) async {
    _store.remove(keyFor(args));
  }
}

final contributionDraftLocalDatasourceProvider =
    Provider<ContributionDraftLocalDatasource>((ref) {
      try {
        final prefs = ref.watch(sharedPreferencesProvider);
        return SharedPreferencesContributionDraftLocalDatasource(prefs);
      } catch (_) {
        return InMemoryContributionDraftLocalDatasource();
      }
    });
