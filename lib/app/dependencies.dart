import '../app/app_config.dart';
import '../data/air/open_meteo_air_client.dart';
import '../data/greenery/overpass_client.dart';
import '../data/photos/mapillary_client.dart';
import '../data/photos/wikimedia_client.dart';
import '../data/routing/ors_route_client.dart';
import '../services/photo_service.dart';
import '../services/route_generator.dart';

const _userAgent = 'FreshLoop/0.1 (course project)';

/// Builds the production RouteGenerator from real clients + configured keys.
RouteGenerator buildRouteGenerator() => RouteGenerator(
      ors: OrsRouteClient(apiKey: AppConfig.orsApiKey),
      air: OpenMeteoAirClient(),
      overpass: OverpassClient(userAgent: _userAgent),
    );

PhotoService buildPhotoService() => PhotoService(
      mapillary: MapillaryPhotoClient(accessToken: AppConfig.mapillaryToken),
      wikimedia: WikimediaPhotoClient(userAgent: _userAgent),
    );
