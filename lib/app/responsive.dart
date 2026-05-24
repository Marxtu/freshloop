import 'package:flutter/widgets.dart';

/// Layout breakpoint: at/above this logical width we use the "wide" (tablet/
/// desktop/landscape) layout instead of the phone-portrait one.
const double kWideBreakpoint = 720;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideBreakpoint;
