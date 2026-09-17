import 'package:coldigui/features/contributions/domain/entities/contribution_kind.dart';
import 'package:coldigui/features/contributions/domain/validators/attachment_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extensões permitidas e jpeg', () {
    expect(
      validateAttachment(
        name: 'a.PDF',
        size: 10,
        kind: ContributionKind.content,
        currentCount: 0,
      ),
      isNull,
    );
    expect(
      validateAttachment(
        name: 'f.jpeg',
        size: 10,
        kind: ContributionKind.bug,
        currentCount: 0,
      ),
      isNull,
    );
    expect(
      validateAttachment(
        name: 'x.exe',
        size: 10,
        kind: ContributionKind.content,
        currentCount: 0,
      ),
      AttachmentError.typeNotAllowed,
    );
  });
  test('bug só aceita imagem', () {
    expect(
      validateAttachment(
        name: 'a.pdf',
        size: 10,
        kind: ContributionKind.bug,
        currentCount: 0,
      ),
      AttachmentError.typeNotAllowed,
    );
  });
  test('32 MiB é o teto; 5 é o máximo', () {
    expect(
      validateAttachment(
        name: 'a.pdf',
        size: kMaxAttachmentBytes,
        kind: ContributionKind.content,
        currentCount: 0,
      ),
      isNull,
    );
    expect(
      validateAttachment(
        name: 'a.pdf',
        size: kMaxAttachmentBytes + 1,
        kind: ContributionKind.content,
        currentCount: 0,
      ),
      AttachmentError.tooLarge,
    );
    expect(
      validateAttachment(
        name: 'a.pdf',
        size: 1,
        kind: ContributionKind.content,
        currentCount: 5,
      ),
      AttachmentError.tooMany,
    );
  });
  test('links: https e host da lista', () {
    expect(isAllowedLink('https://youtu.be/a'), isTrue);
    expect(isAllowedLink('https://www.youtube.com/watch?v=a'), isTrue);
    expect(isAllowedLink('https://drive.google.com/file/d/1/view'), isTrue);
    expect(isAllowedLink('http://youtu.be/a'), isFalse);
    expect(isAllowedLink('https://youtube.com.evil.example/a'), isFalse);
    expect(isAllowedLink('não é url'), isFalse);
  });
}
