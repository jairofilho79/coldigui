import 'package:coldigui/features/contributions/presentation/utils/rejection_message.dart';
import 'package:coldigui/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations pt;

  setUpAll(() async {
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  test('mapeia os códigos de fio conhecidos para mensagem de gente', () {
    expect(
      rejectionMessage(pt, 'file_too_large', null),
      pt.contributeAttachmentTooLarge,
    );
    expect(
      rejectionMessage(pt, 'file_type_not_allowed', null),
      pt.contributeAttachmentTypeNotAllowed,
    );
    expect(
      rejectionMessage(pt, 'file_type_mismatch', null),
      pt.contributeAttachmentTypeNotAllowed,
    );
    expect(
      rejectionMessage(pt, 'too_many_files', null),
      pt.contributeAttachmentTooMany,
    );
    expect(
      rejectionMessage(pt, 'link_host_not_allowed', null),
      pt.contributeLinkNotAllowed,
    );
    expect(
      rejectionMessage(pt, 'too_many_links', null),
      pt.contributeTooManyLinks,
    );
    expect(
      rejectionMessage(pt, 'request_too_large', null),
      pt.contributeAttachmentTotalTooLarge,
    );
    expect(
      rejectionMessage(pt, 'payload_too_large', null),
      pt.contributeAttachmentTotalTooLarge,
    );
    expect(
      rejectionMessage(pt, 'device_required', null),
      pt.contributeSameDeviceQuestion,
    );
  });

  test('código desconhecido cai no genérico com o próprio código', () {
    expect(
      rejectionMessage(pt, 'algo_novo_do_servidor', null),
      pt.contributeErrorRejected('algo_novo_do_servidor'),
    );
  });

  test('anexa " (arquivo)" quando o servidor manda um `file`', () {
    expect(
      rejectionMessage(pt, 'file_too_large', 'guia.pdf'),
      '${pt.contributeAttachmentTooLarge} (guia.pdf)',
    );
  });
}
