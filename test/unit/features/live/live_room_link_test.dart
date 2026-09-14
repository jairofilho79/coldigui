import 'package:coldigui/features/live/domain/live_room_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconhece o path /ao-vivo/<code> e a query ?live=', () {
    expect(
      parseLiveRoomCode(Uri.parse('https://plpcg.com/ao-vivo/k7x2m9q')),
      'k7x2m9q',
    );
    expect(
      parseLiveRoomCode(Uri.parse('https://plpcg.com/?live=k7x2m9q')),
      'k7x2m9q',
    );
    expect(parseLiveRoomCode(Uri.parse('plpcg:///?live=k7x2m9q')), 'k7x2m9q');
    expect(
      parseLiveRoomCode(Uri.parse('https://plpcg.com/?live=k7x2m9q&s=abc')),
      'k7x2m9q',
    );
  });

  test('rejeita formato errado e URLs sem código', () {
    expect(
      parseLiveRoomCode(Uri.parse('https://plpcg.com/ao-vivo/K7X2M9Q')),
      isNull,
    );
    expect(parseLiveRoomCode(Uri.parse('https://plpcg.com/ao-vivo/')), isNull);
    expect(parseLiveRoomCode(Uri.parse('https://plpcg.com/?live=')), isNull);
    expect(parseLiveRoomCode(Uri.parse('https://plpcg.com/?s=abc')), isNull);
  });

  test('rota interna e URL de partilha', () {
    expect(liveRoomRouteFor('k7x2m9q'), '/ao-vivo/k7x2m9q');
    expect(liveRoomShareUrl('k7x2m9q'), 'https://plpcg.com/ao-vivo/k7x2m9q');
  });
}
