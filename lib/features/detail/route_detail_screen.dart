import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../app/responsive.dart';
import '../../data/photos/scene_photo.dart';
import '../../domain/models/scored_route.dart';
import '../../services/photo_service.dart';
import '../../state/favorites_cubit.dart';
import '../common/route_map.dart';
import 'route_detail_content.dart';

/// The chosen route in full: the loop on a map with its score breakdown,
/// elevation profile, scenery photos, and actions. On phone-portrait the detail
/// rides in a draggable sheet over the map; on wide (tablet/landscape) screens
/// the map and a fixed detail panel sit side by side.
class RouteDetailScreen extends StatefulWidget {
  final ScoredRoute route;
  final PhotoService photoService;

  /// Initial height of the detail sheet as a fraction of the screen.
  final double initialSheetSize;

  const RouteDetailScreen({
    super.key,
    required this.route,
    required this.photoService,
    this.initialSheetSize = 0.42,
  });

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  // Fetch photos once — both the DraggableScrollableSheet builder and the wide
  // panel rebuild on every scroll frame, so the future must NOT be created
  // there (avoids repeated network requests and spinner flashes).
  late final Future<List<ScenePhoto>> _photos =
      widget.photoService.photosForRoute(widget.route.geometry);

  // The wide layout's detail panel scrolls independently of the sheet.
  final _panelController = ScrollController();

  @override
  void dispose() {
    _panelController.dispose();
    super.dispose();
  }

  void _startRun() => context.push('/tracking', extra: widget.route);

  /// The M5 favourite toggle — reachable in both layouts.
  Widget _favoriteButton() {
    return Builder(builder: (context) {
      final fav = context.watch<FavoritesCubit>();
      final isFav = fav.isFavorite(widget.route.routeKey);
      return IconButton.filledTonal(
        icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
        tooltip: isFav ? 'Remove favourite' : 'Save to favourites',
        onPressed: () => fav.toggle(widget.route),
      );
    });
  }

  Widget _backButton() => BackButton(onPressed: () => Navigator.of(context).maybePop());

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: isWide(context) ? _buildWide(context) : _buildNarrow(context));
  }

  /// Wide: map on the left, a fixed detail panel on the right. The back button
  /// and favourite toggle overlay the map so both stay reachable.
  Widget _buildWide(BuildContext context) {
    final t = Theme.of(context);
    final route = widget.route;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              Positioned.fill(child: RouteMap(points: route.geometry.points)),
              Positioned(top: 0, left: 0, child: SafeArea(child: _backButton())),
              Positioned(top: 0, right: 0, child: SafeArea(child: _favoriteButton())),
            ],
          ),
        ),
        SizedBox(
          width: 420,
          child: Material(
            color: t.colorScheme.surface,
            elevation: 1,
            child: SafeArea(
              child: RouteDetailContent(
                route: route,
                photos: _photos,
                controller: _panelController,
                onStartRun: _startRun,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Narrow: today's map with a draggable sheet holding the detail content.
  Widget _buildNarrow(BuildContext context) {
    final t = Theme.of(context);
    final route = widget.route;
    return Stack(
      children: [
        Positioned.fill(child: RouteMap(points: route.geometry.points)),
        Positioned(top: 0, left: 0, child: SafeArea(child: _backButton())),
        Positioned(top: 0, right: 0, child: SafeArea(child: _favoriteButton())),
        DraggableScrollableSheet(
          initialChildSize: widget.initialSheetSize,
          minChildSize: 0.2,
          maxChildSize: 0.9,
          builder: (context, controller) => Container(
            decoration: BoxDecoration(
              color: t.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: RouteDetailContent(
              route: route,
              photos: _photos,
              controller: controller,
              onStartRun: _startRun,
              leading: Column(
                children: [
                  Center(child: Container(width: 40, height: 4, color: t.colorScheme.outlineVariant)),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
