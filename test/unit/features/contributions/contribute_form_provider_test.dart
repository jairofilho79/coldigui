import 'dart:typed_data';

import 'package:coldigui/features/auth/domain/entities/auth_user.dart';
import 'package:coldigui/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:coldigui/features/contributions/data/datasources/contributions_remote_datasource.dart';
import 'package:coldigui/features/contributions/data/providers/contributions_providers.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_attachment.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/entities/contribution_summary.dart';
import 'package:coldigui/features/contributions/domain/validators/attachment_rules.dart';
import 'package:coldigui/features/contributions/presentation/providers/contribute_form_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fakes/fake_auth_notifier.dart';

class _FakeDs extends ContributionsRemoteDatasource {
  _FakeDs(this.onSubmit) : super(Dio());
  final Future<({String id, ContributionStatus status})> Function(
    Map<String, dynamic> payload,
  )
  onSubmit;
  Map<String, dynamic>? lastPayload;
  @override
  Future<({String id, ContributionStatus status})> submit({
    required String sessionToken,
    required Map<String, dynamic> payload,
    required List<ContributionAttachment> attachments,
    void Function(int, int)? onProgress,
  }) {
    lastPayload = payload;
    return onSubmit(payload);
  }
}

ProviderContainer _container(_FakeDs ds) {
  final c = ProviderContainer(
    overrides: [
      contributionsRemoteDatasourceProvider.overrideWithValue(ds),
      authStateProvider.overrideWith(
        () => FakeAuthNotifier(
          const AuthUser(googleSub: 'u', sessionToken: 'sess_t'),
        ),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  const args = ContributeFormArgs();

  test('kind muda limpa subkind; bug exige sameDevice para ficar válido', () {
    final c = _container(
      _FakeDs((_) async => (id: 'x', status: ContributionStatus.pendente)),
    );
    final n = c.read(contributeFormProvider(args).notifier);
    n.setKind(ContributionKind.improvement);
    n.setSubkind(ContributionSubkind.feature);
    n.setKind(ContributionKind.bug);
    expect(c.read(contributeFormProvider(args)).draft.subkind, isNull);
    n.setSubkind(ContributionSubkind.bugReader);
    n.setTitle('t');
    n.setBody('b');
    expect(c.read(contributeFormProvider(args)).draft.isValid, isFalse);
    n.setSameDevice(true);
    expect(c.read(contributeFormProvider(args)).draft.isValid, isTrue);
  });

  test('addAttachment aplica as regras e addLink a allowlist', () {
    final c = _container(
      _FakeDs((_) async => (id: 'x', status: ContributionStatus.pendente)),
    );
    final n = c.read(contributeFormProvider(args).notifier);
    n.setKind(ContributionKind.content);
    expect(
      n.addAttachment(
        ContributionAttachment(name: 'a.exe', size: 1, bytes: Uint8List(1)),
      ),
      AttachmentError.typeNotAllowed,
    );
    expect(
      n.addAttachment(
        ContributionAttachment(name: 'a.pdf', size: 1, bytes: Uint8List(1)),
      ),
      isNull,
    );
    expect(c.read(contributeFormProvider(args)).draft.attachments.length, 1);
    expect(n.addLink('http://x'), isFalse);
    expect(n.addLink('https://youtu.be/a'), isTrue);
    expect(c.read(contributeFormProvider(args)).draft.links, [
      'https://youtu.be/a',
    ]);
  });

  test('submit feliz → Sent; payload leva appVersion e device', () async {
    final ds = _FakeDs(
      (_) async => (id: 'c9', status: ContributionStatus.recebida),
    );
    final c = _container(ds);
    final n = c.read(contributeFormProvider(args).notifier);
    n.setKind(ContributionKind.other);
    n.setTitle('t');
    n.setBody('b');
    await n.submit(device: null, appVersion: '1.2.3+4');
    expect(
      c.read(contributeFormProvider(args)).submit,
      isA<ContributeSent>().having((s) => s.id, 'id', 'c9'),
    );
    expect(ds.lastPayload!['appVersion'], '1.2.3+4');
  });

  test('429 → Failed(quota) com resetAt; 413 → Failed(rejected) com file; DioException de rede → offline', () async {
    final reset = DateTime.utc(2026, 9, 18);
    final c1 = _container(
      _FakeDs((_) async => throw ContributionQuotaExceeded(reset)),
    );
    final n1 = c1.read(contributeFormProvider(args).notifier);
    n1.setKind(ContributionKind.other);
    n1.setTitle('t');
    n1.setBody('b');
    await n1.submit(device: null, appVersion: '1');
    final s1 = c1.read(contributeFormProvider(args));
    expect(
      s1.submit,
      isA<ContributeFailed>().having(
        (f) => f.failure,
        'failure',
        ContributeFailure.quota,
      ),
    );
    expect(s1.quotaResetAt, reset);
    expect(s1.draft.title, 't'); // formulário preservado

    final c2 = _container(
      _FakeDs(
        (_) async => throw ContributionRejected(
          status: 413,
          error: 'file_too_large',
          file: 'g.pdf',
        ),
      ),
    );
    final n2 = c2.read(contributeFormProvider(args).notifier);
    n2.setKind(ContributionKind.other);
    n2.setTitle('t');
    n2.setBody('b');
    await n2.submit(device: null, appVersion: '1');
    expect(c2.read(contributeFormProvider(args)).rejectedFile, 'g.pdf');

    final c3 = _container(
      _FakeDs(
        (_) async => throw DioException.connectionError(
          requestOptions: RequestOptions(),
          reason: 'x',
        ),
      ),
    );
    final n3 = c3.read(contributeFormProvider(args).notifier);
    n3.setKind(ContributionKind.other);
    n3.setTitle('t');
    n3.setBody('b');
    await n3.submit(device: null, appVersion: '1');
    expect(
      c3.read(contributeFormProvider(args)).submit,
      isA<ContributeFailed>().having(
        (f) => f.failure,
        'failure',
        ContributeFailure.offline,
      ),
    );
  });
}
