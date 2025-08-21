import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

// Default theme color name
const String kDefaultScheme = 'gray';

// Global notifier for the current scheme name
final ValueNotifier<String> appScheme = ValueNotifier<String>(kDefaultScheme);

// Supported scheme names based on ShadColorScheme.fromName
// See: shadcn_ui/src/theme/color_scheme/base.dart
const List<String> kSupportedSchemes = <String>[
  'blue',
  'gray',
  'green',
  'neutral',
  'orange',
  'red',
  'rose',
  'slate',
  'stone',
  'violet',
  'yellow',
  'zinc',
];

ShadColorScheme schemeFor(String name, Brightness brightness) {
  // Fallback to gray if name is invalid
  if (!kSupportedSchemes.contains(name)) name = kDefaultScheme;
  return ShadColorScheme.fromName(name, brightness: brightness);
}
