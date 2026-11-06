enum MuseScorePerformanceOriginKind {
  score,
  marker,
  jump,
  passage,
  playRepeats,
}

class MuseScorePerformanceOrigin {
  const MuseScorePerformanceOrigin({
    required this.kind,
    required this.elementName,
    this.staffIndex,
    this.measureIndex,
    this.elementId,
  });

  final MuseScorePerformanceOriginKind kind;
  final String elementName;
  final int? staffIndex;
  final int? measureIndex;
  final String? elementId;
}

class MuseScoreMarkerMetadata {
  const MuseScoreMarkerMetadata({
    required this.origin,
    this.label,
    this.markerType,
    this.subtype,
    this.style,
    this.text,
  });

  final MuseScorePerformanceOrigin origin;
  final String? label;
  final String? markerType;
  final String? subtype;
  final String? style;
  final String? text;
}

enum MuseScoreDestinationKind { marker, scoreStart, scoreEnd }

class MuseScorePerformanceDestination {
  const MuseScorePerformanceDestination({
    required this.reference,
    required this.measureIndex,
    required this.kind,
    required this.origin,
  });

  final String reference;
  final int measureIndex;
  final MuseScoreDestinationKind kind;
  final MuseScorePerformanceOrigin origin;
}

class MuseScoreJumpMetadata {
  const MuseScoreJumpMetadata({
    required this.origin,
    this.jumpTo,
    this.playUntil,
    this.continueAt,
    this.playRepeats,
    this.rawPlayRepeats,
    this.playRepeatsDeclaration,
    this.subtype,
    this.style,
    this.text,
    this.jumpToDestination,
    this.playUntilDestination,
    this.continueAtDestination,
  });

  final MuseScorePerformanceOrigin origin;
  final String? jumpTo;
  final String? playUntil;
  final String? continueAt;
  final bool? playRepeats;
  final String? rawPlayRepeats;
  final MuseScorePlayRepeatsMetadata? playRepeatsDeclaration;
  final String? subtype;
  final String? style;
  final String? text;
  final MuseScorePerformanceDestination? jumpToDestination;
  final MuseScorePerformanceDestination? playUntilDestination;
  final MuseScorePerformanceDestination? continueAtDestination;
}

class MuseScorePassageMetadata {
  const MuseScorePassageMetadata({
    required this.origin,
    required this.startMeasureIndex,
    required this.passNumbers,
    required this.declaredMeasureCount,
    required this.endMeasureIndexExclusive,
    this.text,
    this.openEnd = false,
  });

  final MuseScorePerformanceOrigin origin;
  final int startMeasureIndex;
  final List<int> passNumbers;
  final int? declaredMeasureCount;
  final int? endMeasureIndexExclusive;
  final String? text;
  final bool openEnd;
}

class MuseScorePlayRepeatsMetadata {
  const MuseScorePlayRepeatsMetadata({
    required this.origin,
    required this.rawValue,
    required this.value,
  });

  final MuseScorePerformanceOrigin origin;
  final String rawValue;
  final bool? value;
}

enum MuseScorePerformanceDiagnosticCode {
  duplicateMarkerLabel,
  ambiguousDestination,
  unresolvedDestination,
  invalidPlayRepeats,
  conflictingPlayRepeats,
  invalidPassage,
  conflictingPassages,
}

class MuseScorePerformanceDiagnostic {
  const MuseScorePerformanceDiagnostic({
    required this.code,
    required this.origin,
    required this.message,
    this.reference,
    this.relatedOrigins = const [],
  });

  final MuseScorePerformanceDiagnosticCode code;
  final MuseScorePerformanceOrigin origin;
  final String message;
  final String? reference;
  final List<MuseScorePerformanceOrigin> relatedOrigins;
}

class MuseScorePerformanceMetadata {
  const MuseScorePerformanceMetadata({
    this.markers = const [],
    this.jumps = const [],
    this.passages = const [],
    this.playRepeatsDeclarations = const [],
    this.diagnostics = const [],
  });

  final List<MuseScoreMarkerMetadata> markers;
  final List<MuseScoreJumpMetadata> jumps;
  final List<MuseScorePassageMetadata> passages;
  final List<MuseScorePlayRepeatsMetadata> playRepeatsDeclarations;
  final List<MuseScorePerformanceDiagnostic> diagnostics;

  /// The single unambiguous score-wide setting, when the file declares one.
  bool? get playRepeats {
    if (playRepeatsDeclarations.isEmpty ||
        playRepeatsDeclarations.any((setting) => setting.value == null)) {
      return null;
    }
    final values = playRepeatsDeclarations
        .map((setting) => setting.value)
        .toSet();
    return values.length == 1 ? values.single : null;
  }
}

/// Exact position in quarter notes, represented as a reduced rational.
class MusicXmlPosition {
  const MusicXmlPosition({required this.numerator, required this.denominator});

  final String numerator;
  final String denominator;

  double get quarterNotes =>
      BigInt.parse(numerator).toDouble() / BigInt.parse(denominator).toDouble();
}

class MusicXmlPerformanceOrigin {
  const MusicXmlPerformanceOrigin({
    required this.partIndex,
    required this.measureIndex,
    this.partId,
    this.measureNumber,
    this.staffNumber,
    this.staffIndex,
    this.voice,
    this.onset,
  });

  final String? partId;
  final int partIndex;
  final int measureIndex;
  final String? measureNumber;

  /// MusicXML staff number, which is one-based and local to the part.
  final int? staffNumber;

  /// Zero-based index in the rendered document, when a staff is specified.
  final int? staffIndex;
  final String? voice;
  final MusicXmlPosition? onset;
}

class MusicXmlDirectionMetadata {
  const MusicXmlDirectionMetadata({
    required this.origin,
    this.rawOffsetDivisions,
    this.offset,
    this.rawOffsetSound,
    this.offsetAffectsSound,
    this.dynamicMarks = const [],
    this.displayText,
  });

  final MusicXmlPerformanceOrigin origin;

  /// Literal `<direction><offset>` value, in the active MusicXML divisions.
  final String? rawOffsetDivisions;

  /// Offset converted to quarter notes.
  final MusicXmlPosition? offset;
  final String? rawOffsetSound;

  /// Whether the direction offset applies to associated playback.
  final bool? offsetAffectsSound;

  /// Dynamic element names such as `p`, `ff`, or raw `other-dynamics` text.
  final List<String> dynamicMarks;

  /// Display-only text. Playback semantics are read from MusicXML attributes.
  final String? displayText;
}

class MusicXmlSoundMetadata {
  const MusicXmlSoundMetadata({
    required this.origin,
    this.rawTempo,
    this.tempo,
    this.rawDynamics,
    this.dynamics,
    this.rawDaCapo,
    this.daCapo,
    this.segno,
    this.dalSegno,
    this.coda,
    this.toCoda,
    this.fine,
    this.rawForwardRepeat,
    this.forwardRepeat,
    this.rawTimeOnly,
    this.timeOnlyPasses = const [],
    this.rawDivisions,
    this.divisions,
    this.rawOffsetDivisions,
    this.offset,
  });

  final MusicXmlPerformanceOrigin origin;
  final String? rawTempo;

  /// Quarter notes per minute from the `<sound tempo>` attribute.
  final double? tempo;
  final String? rawDynamics;

  /// Percentage of the default forte value from `<sound dynamics>`.
  final double? dynamics;
  final String? rawDaCapo;
  final bool? daCapo;
  final String? segno;
  final String? dalSegno;
  final String? coda;
  final String? toCoda;
  final String? fine;
  final String? rawForwardRepeat;
  final bool? forwardRepeat;
  final String? rawTimeOnly;
  final List<int> timeOnlyPasses;
  final String? rawDivisions;

  /// Divisions per quarter note declared by `<sound divisions>`.
  final double? divisions;
  final String? rawOffsetDivisions;

  /// Explicit `<sound><offset>` converted to quarter notes.
  final MusicXmlPosition? offset;
}

class MusicXmlRepeatMetadata {
  const MusicXmlRepeatMetadata({
    required this.origin,
    required this.direction,
    this.location,
    this.rawTimes,
    this.times,
    this.rawAfterJump,
    this.afterJump,
  });

  final MusicXmlPerformanceOrigin origin;
  final String direction;
  final String? location;
  final String? rawTimes;

  /// Declared repeat count, left null when the attribute is absent or invalid.
  final int? times;
  final String? rawAfterJump;
  final bool? afterJump;
}

class MusicXmlGraceMetadata {
  const MusicXmlGraceMetadata({
    required this.origin,
    this.rawSlash,
    this.slash,
    this.rawMakeTime,
    this.makeTime,
    this.makeTimeQuarterNotes,
    this.rawStealTimePrevious,
    this.stealTimePrevious,
    this.rawStealTimeFollowing,
    this.stealTimeFollowing,
    this.rawPitchAlter,
    this.pitchAlter,
  });

  final MusicXmlPerformanceOrigin origin;
  final String? rawSlash;
  final bool? slash;

  /// Grace-note timing values, retained in their MusicXML-defined units.
  final String? rawMakeTime;
  final double? makeTime;

  /// The declared make-time converted from divisions to quarter notes.
  final MusicXmlPosition? makeTimeQuarterNotes;

  final String? rawStealTimePrevious;
  final double? stealTimePrevious;
  final String? rawStealTimeFollowing;
  final double? stealTimeFollowing;
  final String? rawPitchAlter;

  /// The explicit `<pitch><alter>` value of this grace note, if present.
  final int? pitchAlter;
}

class MusicXmlOrnamentMetadata {
  const MusicXmlOrnamentMetadata({
    required this.origin,
    this.ornamentNames = const [],
    this.rawAccidentalMark,
    this.accidentalAlter,
  });

  final MusicXmlPerformanceOrigin origin;
  final List<String> ornamentNames;
  final String? rawAccidentalMark;

  /// An explicit accidental on a supported ornament's auxiliary pitch.
  final int? accidentalAlter;
}

class MusicXmlTremoloMetadata {
  const MusicXmlTremoloMetadata({
    required this.origin,
    this.rawType,
    this.rawStrokes,
    this.strokes,
  });

  final MusicXmlPerformanceOrigin origin;
  final String? rawType;
  final String? rawStrokes;
  final int? strokes;
}

class MusicXmlFermataMetadata {
  const MusicXmlFermataMetadata({required this.origin, required this.isRest});

  final MusicXmlPerformanceOrigin origin;
  final bool isRest;
}

class MusicXmlPerformanceMetadata {
  const MusicXmlPerformanceMetadata({
    this.directions = const [],
    this.sounds = const [],
    this.repeats = const [],
    this.graceNotes = const [],
    this.ornaments = const [],
    this.tremolos = const [],
    this.fermatas = const [],
  });

  final List<MusicXmlDirectionMetadata> directions;
  final List<MusicXmlSoundMetadata> sounds;
  final List<MusicXmlRepeatMetadata> repeats;
  final List<MusicXmlGraceMetadata> graceNotes;
  final List<MusicXmlOrnamentMetadata> ornaments;
  final List<MusicXmlTremoloMetadata> tremolos;
  final List<MusicXmlFermataMetadata> fermatas;
}
