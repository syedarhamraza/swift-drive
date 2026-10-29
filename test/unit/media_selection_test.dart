import 'package:flutter_test/flutter_test.dart';
import 'package:swiftdrive/features/media/data/media_repository.dart';
import 'package:swiftdrive/features/media/domain/source_selection.dart';

MediaSession session(
  String id,
  int state, {
  String? title,
  int position = 0,
  int updateTime = 0,
  int duration = 0,
  int actions = 0,
}) => MediaSession(
  id: id,
  packageName: id,
  appLabel: id,
  state: state,
  position: position,
  updateTime: updateTime,
  speed: 1,
  actions: actions,
  title: title,
  duration: duration,
);

void main() {
  final paused = session('paused', PlaybackStates.paused, title: 'Song');
  final playing = session('playing', PlaybackStates.playing, title: 'Other');
  final idle = session('idle', PlaybackStates.none);

  test(
    'empty list selects nothing',
    () => expect(selectMediaSession(const []), isNull),
  );

  test('playing beats paused-with-metadata beats idle', () {
    expect(selectMediaSession([idle, paused, playing])!.id, 'playing');
    expect(selectMediaSession([idle, paused])!.id, 'paused');
  });

  test('user choice wins while it exists', () {
    expect(
      selectMediaSession([paused, playing], userSelectedId: 'paused')!.id,
      'paused',
    );
    expect(
      selectMediaSession([playing], userSelectedId: 'gone')!.id,
      'playing',
    );
  });

  test('current source is kept unless another starts playing', () {
    expect(selectMediaSession([paused, idle], currentId: 'idle')!.id, 'idle');
    expect(
      selectMediaSession([paused, playing], currentId: 'paused')!.id,
      'playing',
    );
  });

  test('remembered app breaks ties', () {
    final a = session('a', PlaybackStates.paused, title: 'x');
    final b = session('b', PlaybackStates.paused, title: 'y');
    expect(selectMediaSession([a, b], preferredPackage: 'b')!.id, 'b');
  });

  test('position extrapolates only while playing and is clamped', () {
    final p = session(
      'p',
      PlaybackStates.playing,
      position: 1000,
      updateTime: 5000,
      duration: 3000,
    );
    expect(p.positionAt(6000), 2000);
    expect(p.positionAt(99999), 3000);
    final q = session(
      'q',
      PlaybackStates.paused,
      position: 1000,
      updateTime: 5000,
    );
    expect(q.positionAt(9000), 1000);
  });

  test('zero action mask assumes basic commands; seeking needs the bit', () {
    final s = session('s', PlaybackStates.playing, duration: 1000);
    expect(s.supports(PlaybackStates.actionSkipToNext), isTrue);
    expect(s.canSeek, isFalse);
    final t = session(
      't',
      PlaybackStates.playing,
      duration: 1000,
      actions: PlaybackStates.actionSeekTo,
    );
    expect(t.supports(PlaybackStates.actionSkipToNext), isFalse);
    expect(t.canSeek, isTrue);
  });
}
