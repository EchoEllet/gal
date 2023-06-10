import 'package:flutter/services.dart';
import 'package:gal/gal_exception.dart';

import 'gal_platform_interface.dart';

/// Plugin App Facing
class Gal {
  /// Save video to native gallery app
  /// [path] is local path.
  /// not supported [Uri] or something.
  static Future<void> putVideo(String path) async =>
      _voidOrThrow(() async => GalPlatform.instance.putVideo(path));

  /// Save image to native gallery app
  /// [path] is local path.
  /// not supported [Uri] or something.
  static Future<void> putImage(String path) async =>
      _voidOrThrow(() async => GalPlatform.instance.putImage(path));

  /// Open "iOS Photos" when iOS, "Google Photos" when Android.
  static Future<void> open() async => GalPlatform.instance.open();

  static Future<void> _voidOrThrow(Future<void> Function() cb) async {
    try {
      return await cb();
    } on PlatformException catch (error, stackTrace) {
      throw GalException.fromCode(
          code: error.code, error: error, stackTrace: stackTrace);
    }
  }
}
