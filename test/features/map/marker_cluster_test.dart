import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/domain/marker_cluster.dart';

void main() {
  test('dicht bij elkaar wordt één groep', () {
    final groups = clusterByScreenDistance(const [
      ClusterPoint('a', Offset(100, 100)),
      ClusterPoint('b', Offset(110, 105)),
      ClusterPoint('c', Offset(120, 95)),
    ]);

    expect(groups, hasLength(1));
    expect(groups.single, ['a', 'b', 'c']);
  });

  test('ver uit elkaar blijven aparte groepen', () {
    final groups = clusterByScreenDistance(const [
      ClusterPoint('a', Offset(0, 0)),
      ClusterPoint('b', Offset(500, 0)),
      ClusterPoint('c', Offset(0, 500)),
    ]);

    expect(groups, hasLength(3));
  });

  test('het eerste punt van een groep is het anker; volgorde blijft behouden', () {
    final groups = clusterByScreenDistance(const [
      ClusterPoint('ik', Offset(200, 200)),
      ClusterPoint('ver', Offset(1000, 1000)),
      ClusterPoint('dichtbij', Offset(210, 205)),
    ]);

    expect(groups, hasLength(2));
    expect(groups.first, ['ik', 'dichtbij']);
    expect(groups.last, ['ver']);
  });

  test('de drempel is inclusief', () {
    final groups = clusterByScreenDistance(const [
      ClusterPoint('a', Offset(0, 0)),
      ClusterPoint('b', Offset(40, 0)),
    ], thresholdPx: 40);
    expect(groups, hasLength(1));
  });

  test('op echte afstand: aparte locaties blijven apart, ook dicht bij elkaar', () {
    // ±600 m uit elkaar in Antwerpen: op zoom 12 zou dat vroeger één groep zijn.
    final groups = clusterByMeters(const [
      GeoClusterPoint('franky', 51.2000, 4.4000),
      GeoClusterPoint('liam', 51.2054, 4.4000),
    ]);
    expect(groups, [
      ['franky'],
      ['liam'],
    ]);
  });

  test('op echte afstand: zelfde plek (binnen 60 m) wordt één groep', () {
    final groups = clusterByMeters(const [
      GeoClusterPoint('papa', 51.2000, 4.4000),
      GeoClusterPoint('mama', 51.2002, 4.4002),
    ]);
    expect(groups, [
      ['papa', 'mama'],
    ]);
  });
}
