import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/photos/scene_photo.dart';
import 'package:freshloop/features/detail/photo_carousel.dart';

void main() {
  testWidgets('shows a hint when there are no photos', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PhotoCarousel(photos: [])),
    ));
    expect(find.text('No photos for this area'), findsOneWidget);
  });

  testWidgets('builds a page per photo', (tester) async {
    const photos = [
      ScenePhoto(url: 'https://img/1.jpg', source: PhotoSource.mapillary, lat: 0, lng: 0),
      ScenePhoto(url: 'https://img/2.jpg', source: PhotoSource.wikimedia, lat: 0, lng: 0, caption: 'Park'),
    ];
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PhotoCarousel(photos: photos)),
    ));
    expect(find.byType(PageView), findsOneWidget);
  });
}
