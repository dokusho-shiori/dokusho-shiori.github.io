import 'package:flutter/material.dart';

const double kMobileBreakpoint = 600;

bool isMobileLayout(BuildContext context) =>
    MediaQuery.of(context).size.width < kMobileBreakpoint;
