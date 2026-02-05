import 'package:flutter/material.dart';

/// Utility class for responsive design calculations
class ResponsiveUtils {
  static late double _screenWidth;
  static late double _screenHeight;
  static late double _safeAreaHorizontal;
  static late double _safeAreaVertical;
  static late double _safeWidth;
  static late double _safeHeight;
  static late TextScaler _textScaler;

  /// Initialize responsive utilities with the current context
  /// Call this in the build method of each screen
  static void init(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    _screenWidth = mediaQuery.size.width;
    _screenHeight = mediaQuery.size.height;
    _safeAreaHorizontal = mediaQuery.padding.left + mediaQuery.padding.right;
    _safeAreaVertical = mediaQuery.padding.top + mediaQuery.padding.bottom;
    _safeWidth = _screenWidth - _safeAreaHorizontal;
    _safeHeight = _screenHeight - _safeAreaVertical;
    _textScaler = mediaQuery.textScaler;
  }

  /// Screen width
  static double get screenWidth => _screenWidth;

  /// Screen height
  static double get screenHeight => _screenHeight;

  /// Safe area width (screen width minus horizontal padding)
  static double get safeWidth => _safeWidth;

  /// Safe area height (screen height minus vertical padding)
  static double get safeHeight => _safeHeight;

  /// Text scaler
  static TextScaler get textScaler => _textScaler;

  /// Check if device is in landscape orientation
  static bool get isLandscape => _screenWidth > _screenHeight;

  /// Check if device is in portrait orientation
  static bool get isPortrait => _screenWidth <= _screenHeight;

  /// Check if screen is small (phone portrait)
  static bool get isSmallScreen => _screenWidth < 360;

  /// Check if screen is medium (phone landscape or small tablet)
  static bool get isMediumScreen => _screenWidth >= 360 && _screenWidth < 600;

  /// Check if screen is large (tablet or desktop)
  static bool get isLargeScreen => _screenWidth >= 600;

  /// Get the smaller dimension of the screen (useful for circular elements)
  static double get smallerDimension => _screenWidth < _screenHeight ? _screenWidth : _screenHeight;

  /// Responsive font size based on screen width
  /// baseSize is the font size for a 360px wide screen
  static double fontSize(double baseSize) {
    return baseSize * (_safeWidth / 360) * _textScaler.scale(1);
  }

  /// Responsive width based on screen width
  static double width(double percentage) {
    return _safeWidth * percentage;
  }

  /// Responsive height based on screen height
  static double height(double percentage) {
    return _safeHeight * percentage;
  }

  /// Responsive icon size
  static double iconSize(double baseSize) {
    return baseSize * (_safeWidth / 360);
  }

  /// Responsive padding based on screen width
  static double padding(double percentage) {
    return _safeWidth * percentage;
  }

  /// Get responsive dimension for circular elements
  static double circularSize(double baseSize) {
    return baseSize * (_safeWidth / 360);
  }

  /// Get responsive border radius
  static double borderRadius(double baseSize) {
    return baseSize * (_safeWidth / 360);
  }

  /// Get button height based on screen size
  static double buttonHeight(double baseSize) {
    return baseSize * (_safeWidth / 360);
  }

  /// Get spacing based on screen size
  static double spacing(double baseSize) {
    return baseSize * (_safeWidth / 360);
  }
}

/// Extension methods for common responsive calculations
extension Responsive on BuildContext {
  /// Get MediaQuery data
  MediaQueryData get mq => MediaQuery.of(this);

  /// Screen width
  double get screenWidth => mq.size.width;

  /// Screen height
  double get screenHeight => mq.size.height;

  /// Safe area width
  double get safeWidth => mq.size.width - mq.padding.horizontal;

  /// Safe area height
  double get safeHeight => mq.size.height - mq.padding.vertical;

  /// Check if device is in landscape
  bool get isLandscape => mq.orientation == Orientation.landscape;

  /// Check if device is in portrait
  bool get isPortrait => mq.orientation == Orientation.portrait;

  /// Check if screen is small
  bool get isSmallScreen => screenWidth < 360;

  /// Check if screen is medium
  bool get isMediumScreen => screenWidth >= 360 && screenWidth < 600;

  /// Check if screen is large (tablet)
  bool get isLargeScreen => screenWidth >= 600;

  /// Responsive font size
  double fontSize(double baseSize) => baseSize * (safeWidth / 360) * mq.textScaler.scale(1);

  /// Responsive width percentage
  double width(double percentage) => safeWidth * percentage;

  /// Responsive height percentage
  double height(double percentage) => safeHeight * percentage;

  /// Responsive icon size
  double iconSize(double baseSize) => baseSize * (safeWidth / 360);

  /// Responsive padding
  double padding(double percentage) => safeWidth * percentage;

  /// Responsive circular size
  double circularSize(double baseSize) => baseSize * (safeWidth / 360);

  /// Responsive border radius
  double borderRadius(double baseSize) => baseSize * (safeWidth / 360);

  /// Responsive button height
  double buttonHeight(double baseSize) => baseSize * (safeWidth / 360);

  /// Responsive spacing
  double spacing(double baseSize) => baseSize * (safeWidth / 360);
}
