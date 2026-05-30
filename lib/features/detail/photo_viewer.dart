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
    // The viewer lazy-loads a high-resolution image (so a 360° sphere isn't a
    // blurry 1024px thumbnail wrapped across the whole view); the carousel keeps
    // the small thumb. Highest-res first, then the thumb as a fallback.
    final sources = <String>{if (photo.fullUrl != null) photo.fullUrl!, photo.url}.toList();
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
          // True spherical panorama, loaded at full resolution (PanoramaViewer
          // bypasses Image's own loading/error UI, so we manage both ourselves).
          ? _PanoramaView(sources: sources)
          : InteractiveViewer(
              minScale: 0.8,
              maxScale: 6,
              child: Center(
                child: Image.network(
                  sources.first,
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

/// Spherical panorama with explicit load/error handling. [PanoramaViewer] reads
/// the [Image]'s provider straight into a GL texture and never renders the
/// Image widget, so its `loadingBuilder`/`errorBuilder` are ignored. We probe
/// the same provider (NetworkImage de-dupes the fetch) to show a spinner while
/// the full-res image loads and to fall back to the next, lighter [sources]
/// entry if it fails — otherwise a failed load just leaves a black sphere.
class _PanoramaView extends StatefulWidget {
  final List<String> sources; // highest-res first; later entries are fallbacks
  const _PanoramaView({required this.sources});

  @override
  State<_PanoramaView> createState() => _PanoramaViewState();
}

class _PanoramaViewState extends State<_PanoramaView> {
  int _index = 0;
  bool _loaded = false;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  void _probe() {
    final provider = NetworkImage(widget.sources[_index]);
    _detach();
    _stream = provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener(
      (info, _) {
        if (mounted && !_loaded) setState(() => _loaded = true);
      },
      onError: (e, _) {
        if (!mounted) return;
        if (_index < widget.sources.length - 1) {
          setState(() {
            _index++;
            _loaded = false;
          });
          _probe();
        } else {
          setState(() => _loaded = true); // give up the spinner; show black sphere
        }
      },
    );
    _stream!.addListener(_listener!);
  }

  void _detach() {
    if (_stream != null && _listener != null) _stream!.removeListener(_listener!);
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PanoramaViewer(
          key: ValueKey(widget.sources[_index]),
          minZoom: 1,
          maxZoom: 5,
          child: Image.network(widget.sources[_index]),
        ),
        if (!_loaded) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

/// Opens [photo] full-screen.
void openPhotoViewer(BuildContext context, ScenePhoto photo) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PhotoViewerScreen(photo: photo), fullscreenDialog: true),
  );
}
