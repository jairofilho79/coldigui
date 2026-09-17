import 'contribution_kind.dart';

/// Estados do fluxo de moderação (spec §4) — `fromWire` cai em `pendente`
/// para qualquer valor novo do servidor que o app ainda não conheça.
enum ContributionStatus {
  recebida,
  bloqueada,
  pendente,
  emAnalise,
  aceita,
  recusada,
  aplicada;

  static ContributionStatus fromWire(String s) => switch (s) {
    'recebida' => recebida,
    'bloqueada' => bloqueada,
    'pendente' => pendente,
    'em_analise' => emAnalise,
    'aceita' => aceita,
    'recusada' => recusada,
    'aplicada' => aplicada,
    _ => pendente,
  };
}

class ContributionFileSummary {
  const ContributionFileSummary({
    required this.id,
    required this.originalName,
    required this.size,
    required this.scanStatus,
  });

  final String id;
  final String originalName;
  final int size;
  final String scanStatus;
}

/// O que o próprio usuário vê de um envio (spec §4.2, `toUserJson`).
class ContributionSummary {
  const ContributionSummary({
    required this.id,
    required this.kind,
    required this.subkind,
    required this.title,
    required this.body,
    required this.status,
    required this.decisionNote,
    required this.createdAt,
    required this.updatedAt,
    required this.links,
    required this.files,
    required this.fields,
  });

  final String id;
  final ContributionKind kind;
  final String? subkind;
  final String title;
  final String body;
  final ContributionStatus status;
  final String? decisionNote;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> links;
  final List<ContributionFileSummary> files;
  final Map<String, dynamic> fields;

  /// D1 grava `datetime('now')` como `YYYY-MM-DD HH:MM:SS` em UTC, sem `Z`.
  static DateTime _utc(String s) => DateTime.parse(
    '${s.replaceFirst(' ', 'T')}${s.endsWith('Z') ? '' : 'Z'}',
  );

  factory ContributionSummary.fromJson(Map<String, dynamic> json) =>
      ContributionSummary(
        id: json['id'] as String,
        kind: ContributionKind.values.firstWhere(
          (k) => k.wireName == json['kind'],
          orElse: () => ContributionKind.other,
        ),
        subkind: json['subkind'] as String?,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        status: ContributionStatus.fromWire(
          json['status'] as String? ?? 'pendente',
        ),
        decisionNote: json['decision_note'] as String?,
        createdAt: _utc(json['created_at'] as String),
        updatedAt: _utc(json['updated_at'] as String),
        links: [
          for (final l in (json['links'] as List? ?? const [])) l as String,
        ],
        files: [
          for (final f in (json['files'] as List? ?? const []))
            ContributionFileSummary(
              id: f['id'] as String,
              originalName: f['original_name'] as String,
              size: (f['size'] as num).toInt(),
              scanStatus: f['scan_status'] as String,
            ),
        ],
        fields: (json['fields'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

class ContributionsPage {
  const ContributionsPage({required this.items, required this.nextCursor});
  final List<ContributionSummary> items;
  final String? nextCursor;
}
