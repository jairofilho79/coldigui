import 'package:coldigui/features/score_reader/domain/entities/score_document.dart';
import 'package:coldigui/features/score_reader/domain/usecases/build_score_midi.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_performance_plan.dart';
import 'package:coldigui/features/score_reader/domain/usecases/score_playback_map.dart';
import 'package:crisp_notation_core/crisp_notation_core.dart' hide Interval;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundfont_kit/soundfont_kit.dart' as sk;

void main() {
  test(
    'shared plan keeps four voices, tuplets, MIDI timing and empty bars',
    () {
      final score = MultiPartScore([
        Score(
          clef: Clef.treble,
          timeSignature: const TimeSignature(4, 4),
          measures: [
            Measure(
              [
                NoteElement.note(
                  Pitch(Step.c),
                  NoteDuration.eighth,
                  id: 'triplet-c',
                ),
                NoteElement.note(
                  Pitch(Step.d),
                  NoteDuration.eighth,
                  id: 'triplet-d',
                ),
                NoteElement.note(
                  Pitch(Step.e),
                  NoteDuration.eighth,
                  id: 'triplet-e',
                ),
                NoteElement.note(
                  Pitch(Step.f),
                  NoteDuration.half,
                  id: 'voice-one-end',
                ),
              ],
              voice2: [
                NoteElement.note(
                  Pitch(Step.g),
                  NoteDuration.whole,
                  id: 'voice-two',
                ),
              ],
              voice3: [
                NoteElement.note(
                  Pitch(Step.a),
                  NoteDuration.whole,
                  id: 'voice-three',
                ),
              ],
              voice4: [
                NoteElement.note(
                  Pitch(Step.b),
                  NoteDuration.whole,
                  id: 'voice-four',
                ),
              ],
              tuplets: const [TupletSpan(0, 2, actual: 3, normal: 2)],
            ),
            const Measure([]),
          ],
        ),
      ]);
      final document = ScoreDocument(
        score: score,
        staves: const [ScoreStaff(index: 0, partName: 'Test')],
        format: ScoreSourceFormat.musicXml,
      );
      final plan = ScorePerformancePlan.of(score, quarterBpm: 120);
      final map = ScorePlaybackMap.fromPlan(plan);
      final eventsById = {
        for (final event in plan.events) event.origin.elementId: event,
      };

      expect(plan.events.map((event) => event.origin.voice).toSet(), {
        0,
        1,
        2,
        3,
      });
      expect(
        [
          eventsById['triplet-c']!.start,
          eventsById['triplet-d']!.start,
          eventsById['triplet-e']!.start,
        ],
        [Fraction.zero, Fraction(1, 12), Fraction(1, 6)],
      );
      expect(eventsById['triplet-d']!.duration, Fraction(1, 12));
      expect(plan.measureOccurrences.map((item) => item.measureIndex), [0, 1]);
      expect(plan.totalWholeNotes, Fraction(2, 1));
      expect(map.duration, const Duration(seconds: 4));
      expect(map.startOfMeasure(1), const Duration(seconds: 2));

      final midi = sk.MidiReader.fromBytes(
        buildScoreMidi(document, performancePlan: plan),
      );
      expect(midi.totalTicks, 3840);
      final d4 = midi.tracks.single.events
          .whereType<sk.NoteOnEvent>()
          .firstWhere((event) => event.note == 62 && !event.isNoteOff);
      expect(d4.absoluteTick, 160);
    },
  );
}
