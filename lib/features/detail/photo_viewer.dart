import 'package:flutter/material.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import '../../data/photos/scene_photo.dart';

/// Full-screen photo view. 360° panoramas open in a real spherical viewer
/// (drag to rotate, no equirectangular distortion); normal photos open in a
/// zoom/pan viewer.
class PhotoViewerScreen extends StatelessWidget {
  final ScenePhoto photo;
  const PhotoViewerScreen({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: photo.isPano
            ? const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.threesixty_rounded, size: 18),
                SizedBox(width: 6),
                Text('360° — drag to look around', style: TextStyle(fontSize: 14)),
              ])
            : null,
      ),
      body: photo.isPano
          // True spherical panorama: drag to rotate the view in any direction.
          ? PanoramaViewer(
              minZoom: 1,
              maxZoom: 5,
              child: Image.network(photo.url),
            )
          : InteractiveViewer(
              minScale: 0.8,
              maxScale: 6,
              child: Center(
                child: Image.network(
                  photo.url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, e, s) => const Icon(
                    Icons.broken_image_outlined, color: Colors.white54, size: 48),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
    );
  }
}

/// Opens [photo] full-screen.
void openPhotoViewer(BuildContext context, ScenePhoto photo) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PhotoViewerScreen(photo: photo), fullscreenDialog: true),
  );
}
