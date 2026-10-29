import 'package:flutter_test/flutter_test.dart';
import 'package:swiftdrive/features/apps/data/apps_repository.dart';
import 'package:swiftdrive/features/apps/state/apps_providers.dart';

const maps = AppInfo(
  packageName: 'com.maps',
  activityName: 'Main',
  label: 'maps',
);
const music = AppInfo(
  packageName: 'com.music',
  activityName: 'Main',
  label: 'Music',
);
const radio = AppInfo(
  packageName: 'com.radio',
  activityName: 'Main',
  label: 'Radio',
);

void main() {
  test('sort is case-insensitive by label', () {
    expect(sortApps([radio, music, maps]).map((a) => a.label), [
      'maps',
      'Music',
      'Radio',
    ]);
  });

  test(
    'filter matches label or package, hides hidden apps, puts favourites first',
    () {
      final all = [maps, music, radio];
      expect(filterApps(all, query: 'MUS'), [music]);
      expect(filterApps(all, query: 'com.rad'), [radio]);
      expect(filterApps(all, hidden: {music.id}), [maps, radio]);
      expect(filterApps(all, hidden: {music.id}, showHidden: true), all);
      expect(filterApps(all, favorites: {radio.id}), [radio, maps, music]);
    },
  );

  test('findApp falls back to the same package when the activity changed', () {
    expect(findApp([music], 'com.music/Main'), music);
    expect(findApp([music], 'com.music/OldActivity'), music);
    expect(findApp([music], 'com.gone/Main'), isNull);
  });

  test('parseAppId', () {
    expect(parseAppId('a.b/c.D'), ('a.b', 'c.D'));
    expect(parseAppId('a.b'), ('a.b', null));
  });
}
