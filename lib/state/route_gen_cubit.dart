import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/models/run_params.dart';
import '../services/route_generator.dart';
import 'route_gen_state.dart';

/// Drives the route-generation flow: triggers generation and exposes
/// loading/loaded/error states for the UI (design doc §7).
class RouteGenCubit extends Cubit<RouteGenState> {
  final RouteGenerator generator;

  RouteGenCubit(this.generator) : super(const RouteGenInitial());

  Future<void> generate(RunParams params, {int candidates = 3}) async {
    emit(const RouteGenLoading());
    try {
      final routes = await generator.generate(params, candidates: candidates);
      emit(RouteGenLoaded(routes));
    } catch (e) {
      emit(RouteGenError(e.toString()));
    }
  }
}
