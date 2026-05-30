import 'package:flutter/material.dart';
import '../../data/photos/scene_photo.dart';

/// A swipeable strip of along-route scenery photos with a caption scrim.
/// Network image failures fall back to a neutral placeholder (graceful — §11).
class PhotoCarousel extends StatelessWidget {
  final List<ScenePhoto> photos;
  final double height;
  const PhotoCarousel({super.key, required this.photos, this.height = 180});

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No photos for this area', style: Theme.of(context).textTheme.bodySmall),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: PageView.builder(
        itemCount: photos.length,
        controller: PageController(viewportFraction: 0.9),
        itemBuilder: (context, i) {
          final p = photos[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    p.url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, err, trace) =>
                        Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                  ),
                  if (p.caption != null)
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter, end: Alignment.topCenter,
                            colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent],
                          ),
                        ),
                        child: Text(p.caption!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
