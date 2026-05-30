import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freshloop/data/photos/scene_photo.dart';
import 'package:freshloop/features/detail/photo_carousel.dart';

/// A 1×1 transparent PNG — a valid image codec input so NetworkImage "succeeds".
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// Records every requested URL and answers each with the PNG above, so image
/// loads succeed under test and we can assert *which* URL the viewer fetched.
class _RecordingHttpOverrides extends HttpOverrides {
  final List<String> log;
  _RecordingHttpOverrides(this.log);
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeClient(log);
}

class _FakeClient implements HttpClient {
  final List<String> log;
  _FakeClient(this.log);
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    log.add(url.toString());
    return _FakeRequest();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null; // unused members
}

class _FakeRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _FakeResponse();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeResponse implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _png.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.fromIterable([_png])
        .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('tapping a 360° photo lazy-loads the ORIGINAL full-res image', (tester) async {
    final log = <String>[];
    HttpOverrides.global = _RecordingHttpOverrides(log);
    addTearDown(() => HttpOverrides.global = null);

    // A panorama as the Mapillary client would build it: small thumb for the
    // carousel, original full-res for the viewer.
    const pano = ScenePhoto(
      url: 'https://img.test/thumb_1024.jpg',
      fullUrl: 'https://img.test/original.jpg',
      source: PhotoSource.mapillary,
      lat: 45,
      lng: 9,
      isPano: true,
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: PhotoCarousel(photos: [pano])),
    ));
    await tester.pump(); // let the carousel thumbnail resolve

    // Before tapping: the carousel shows the light thumb, NOT the heavy original.
    expect(log.any((u) => u.contains('thumb_1024')), isTrue,
        reason: 'carousel should load the 1024px thumb');
    expect(log.any((u) => u.contains('original')), isFalse,
        reason: 'original must stay unloaded until the user taps in (lazy)');

    // Simulate the user tapping the photo to open it full-screen.
    await tester.tap(find.byType(Image).first);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The 360° viewer is open…
    expect(find.text('360° — drag to look around'), findsOneWidget);
    // …and it actually fetched the ORIGINAL full-res panorama. This is the fix:
    // the tap triggers a high-res load, not the blurry 1024px thumb.
    expect(log.any((u) => u.contains('original')), isTrue,
        reason: 'the viewer must request the original full-res image on open');
  });
}
