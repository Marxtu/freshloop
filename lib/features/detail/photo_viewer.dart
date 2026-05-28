import 'package:flutter/material.dart';
import '../../data/photos/scene_photo.dart';

/// Full-screen, zoomable/pannable view of a scenery photo. For 360° panoramas
/// the equirectangular image is laid out at screen height so you can drag
/// left/right to look all the way around (plus pinch-zoom).
class PhotoViewerScreen extends StatelessWidget {
  final ScenePhoto photo;
  const PhotoViewerScreen({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final img = Image.network(
      photo.url,
      fit: photo.isPano ? BoxFit.fitHeight : BoxFit.contain,
      errorBuilder: (context, e, s) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
      ),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const Center(child: CircularProgressIndicator()),
    );
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
      body: InteractiveViewer(
        // Panoramas: unconstrained + screen-height so the full 360° width can be
        // panned horizontally. Normal photos: constrained, contained, zoomable.
        constrained: !photo.isPano,
        minScale: 0.8,
        maxScale: 6,
        child: photo.isPano
            ? SizedBox(height: h, child: img)
            : Center(child: img),
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
