import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as flutter_map;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import '../services/geofence_service.dart';
import '../services/geofence_config.dart';
import '../utils/responsive_utils.dart';

/// Pantalla de verificación de geolocalización en tiempo real
/// Muestra el mapa con la ubicación del usuario, el campus y el radio de 600m
class GeofenceVerificationScreen extends StatefulWidget {
  final Function(bool isVerified) onVerificationComplete;

  const GeofenceVerificationScreen({super.key, required this.onVerificationComplete});

  @override
  GeofenceVerificationScreenState createState() => GeofenceVerificationScreenState();
}

class GeofenceVerificationScreenState extends State<GeofenceVerificationScreen> {
  final GeofenceService _geofenceService = GeofenceService();
  final flutter_map.MapController _mapController = flutter_map.MapController();

  // Estado de verificación
  bool _isVerifying = true;
  bool _isWithinGeofence = false;
  GeofenceException? _error;
  double? _distanceFromCampus;
  Position? _currentPosition;

  // Coordenadas del campus
  final latlong.LatLng _campusLocation = latlong.LatLng(
    GeofenceConfig.kCampusLatitude,
    GeofenceConfig.kCampusLongitude,
  );

  // Radio del geofence en metros
  final double _geofenceRadius = GeofenceConfig.kDefaultRadiusMeters;

  // Stream para monitoreo continuo
  Stream<GeofenceResult>? _monitoringStream;

  @override
  void initState() {
    super.initState();
    _startVerification();
  }

  @override
  void dispose() {
    _geofenceService.dispose();
    super.dispose();
  }

  Future<void> _startVerification() async {
    if (mounted) {
      setState(() {
        _isVerifying = true;
        _error = null;
      });
    }

    try {
      // Verificar permisos primero
      final hasPermission = await _geofenceService.hasLocationPermission();
      if (!hasPermission) {
        final permission = await _geofenceService.requestLocationPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          _showPermissionDeniedError();
          return;
        }
      }

      // Verificar si el GPS está activado
      final isEnabled = await _geofenceService.isLocationServiceEnabled();
      if (!isEnabled) {
        _showLocationDisabledError();
        return;
      }

      // Iniciar monitoreo continuo
      _monitoringStream = _geofenceService.startContinuousMonitoring();

      // Escuchar el primer resultado
      _monitoringStream!.listen((result) {
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _isWithinGeofence = result.isWithinGeofence;
            _error = result.error;
            _distanceFromCampus = result.distanceInMeters;
            _currentPosition = result.currentPosition;
          });

          // Si está dentro del geofence, mover el mapa a la posición del usuario
          if (result.currentPosition != null) {
            _mapController.move(
              latlong.LatLng(
                result.currentPosition!.latitude,
                result.currentPosition!.longitude,
              ),
              16,
            );
          }

          // Si está dentro del geofence, navegar automáticamente a la siguiente pantalla
          if (result.isWithinGeofence && mounted) {
            widget.onVerificationComplete(true);
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _error = GeofenceException(
            'Error al iniciar la verificación: ${e.toString()}',
            GeofenceErrorType.unknown,
          );
        });
      }
    }
  }

  void _showPermissionDeniedError() {
    if (mounted) {
      setState(() {
        _isVerifying = false;
        _error = GeofenceException(
          'Se requiere permiso de ubicación para verificar su posición dentro del campus universitario.',
          GeofenceErrorType.permissionDenied,
        );
      });
    }
  }

  void _showLocationDisabledError() {
    if (mounted) {
      setState(() {
        _isVerifying = false;
        _error = GeofenceException(
          'Los servicios de ubicación están desactivados. Por favor, active el GPS.',
          GeofenceErrorType.locationDisabled,
        );
      });
    }
  }

  Future<void> _retryVerification() async {
    _geofenceService.stopContinuousMonitoring();
    await _startVerification();
  }

  Future<void> _openAppSettings() async {
    try {
      await GeofenceService.openAppSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Por favor, otorgue los permisos de ubicación en la configuración de su dispositivo.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openLocationSettings() async {
    try {
      await GeofenceService.openLocationSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Por favor, active el GPS en la configuración de su dispositivo.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Verificación de Ubicación',
          style: TextStyle(
            color: Color(0xFF003366),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF003366)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isVerifying ? null : _retryVerification,
            tooltip: 'Verificar nuevamente',
          ),
        ],
      ),
      body: Column(
        children: [
          // Mapa
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                _buildMap(),
                // Indicador de estado en tiempo real
                _buildStatusIndicator(),
              ],
            ),
          ),

          // Panel de información
          Expanded(
            flex: 2,
            child: _buildInfoPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return flutter_map.FlutterMap(
      mapController: _mapController,
      options: flutter_map.MapOptions(
        initialCenter: _campusLocation,
        initialZoom: 16,
        minZoom: 14,
        maxZoom: 19,
        interactionOptions: const flutter_map.InteractionOptions(
          flags: flutter_map.InteractiveFlag.all,
        ),
      ),
      children: [
        flutter_map.TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c'],
          userAgentPackageName: 'com.universidadcontinental.votacion',
        ),
        // Capa del geofence (círculo)
        flutter_map.CircleLayer(
          circles: [
            flutter_map.CircleMarker(
              point: _campusLocation,
              radius: _geofenceRadius,
              useRadiusInMeter: true,
              color: const Color(0xFF003366).withValues(alpha: 0.15),
              borderColor: const Color(0xFF003366).withValues(alpha: 0.5),
              borderStrokeWidth: 2,
            ),
          ],
        ),
        // Marcador del campus
        flutter_map.MarkerLayer(
          markers: [
            flutter_map.Marker(
              point: _campusLocation,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003366),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Campus UC',
                    style: TextStyle(
                      fontSize: context.fontSize(11),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF003366),
                    ),
                  ),
                ],
              ),
            ),
            // Marcador del usuario si está disponible
            if (_currentPosition != null)
              flutter_map.Marker(
                point: latlong.LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: _isWithinGeofence ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Icon(
                    _isWithinGeofence ? Icons.check : Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing(16),
          vertical: context.spacing(12),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(context.borderRadius(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_isVerifying)
              SizedBox(
                width: context.iconSize(20),
                height: context.iconSize(20),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF003366),
                ),
              )
            else
              Icon(
                _isWithinGeofence ? Icons.check_circle : Icons.error,
                color: _isWithinGeofence ? Colors.green : Colors.red,
                size: context.iconSize(24),
              ),
            SizedBox(width: context.spacing(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isVerifying
                        ? 'Verificando ubicación...'
                        : _isWithinGeofence
                            ? 'Ubicación verificada'
                            : 'Fuera del área de votación',
                    style: TextStyle(
                      fontSize: context.fontSize(14),
                      fontWeight: FontWeight.bold,
                      color: _isWithinGeofence
                          ? const Color(0xFF003366)
                          : Colors.red.shade700,
                    ),
                  ),
                  if (_distanceFromCampus != null)
                    Text(
                      _isWithinGeofence
                          ? 'Distancia al campus: ${_distanceFromCampus!.round()}m'
                          : 'Distancia: ${_distanceFromCampus!.round()}m (límite: ${_geofenceRadius.round()}m)',
                      style: TextStyle(
                        fontSize: context.fontSize(12),
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(context.spacing(16)),
      padding: EdgeInsets.all(context.spacing(20)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(context.borderRadius(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: const Color(0xFF003366),
                  size: context.iconSize(24),
                ),
                SizedBox(width: context.spacing(8)),
                Expanded(
                  child: Text(
                    'Universidad Continental - Campus Principal',
                    style: TextStyle(
                      fontSize: context.fontSize(16),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF003366),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacing(12)),
            // Coordenadas
            Text(
              'Coordenadas: ${GeofenceConfig.kCampusLatitude.abs()}°S, ${GeofenceConfig.kCampusLongitude.abs()}°O',
              style: TextStyle(
                fontSize: context.fontSize(12),
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              'Radio de verificación: ${_geofenceRadius.round()} metros',
              style: TextStyle(
                fontSize: context.fontSize(12),
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: context.spacing(16)),
            // Estado
            _buildStatusMessage(),
            SizedBox(height: context.spacing(16)),
            // Botones de acción
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    if (_isVerifying) {
      return Container(
        padding: EdgeInsets.all(context.spacing(12)),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(context.borderRadius(8)),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            SizedBox(
              width: context.iconSize(20),
              height: context.iconSize(20),
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF003366),
              ),
            ),
            SizedBox(width: context.spacing(12)),
            Expanded(
              child: Text(
                'Obteniendo su ubicación...',
                style: TextStyle(
                  fontSize: context.fontSize(13),
                  color: const Color(0xFF003366),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      final errorType = _error!.type;
      final isOutsideGeofence = errorType == GeofenceErrorType.outsideGeofence;

      // Si está fuera del geofence, mostrar un mensaje informativo pero no bloqueador
      if (isOutsideGeofence) {
        return Container(
          padding: EdgeInsets.all(context.spacing(12)),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(context.borderRadius(8)),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.amber.shade700,
                    size: context.iconSize(20),
                  ),
                  SizedBox(width: context.spacing(8)),
                  Expanded(
                    child: Text(
                      'Ubicación detectada fuera del campus',
                      style: TextStyle(
                        fontSize: context.fontSize(13),
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.spacing(8)),
              Text(
                'Se ha detectado que usted se encuentra fuera de las instalaciones de la universidad. ${_distanceFromCampus != null ? "Su distancia al campus es de ${_distanceFromCampus!.round()} metros." : ""} Sin embargo, puede continuar con el proceso de votación.',
                style: TextStyle(
                  fontSize: context.fontSize(12),
                  color: Colors.amber.shade600,
                ),
              ),
            ],
          ),
        );
      }

      // Otros errores (permisos, GPS, etc.)
      return Container(
        padding: EdgeInsets.all(context.spacing(12)),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(context.borderRadius(8)),
          border: Border.all(
            color: Colors.orange.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning,
                  color: Colors.orange.shade700,
                  size: context.iconSize(20),
                ),
                SizedBox(width: context.spacing(8)),
                Expanded(
                  child: Text(
                    _getErrorTitle(errorType),
                    style: TextStyle(
                      fontSize: context.fontSize(13),
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacing(8)),
            Text(
              GeofenceService.getErrorMessage(_error!),
              style: TextStyle(
                fontSize: context.fontSize(12),
                color: Colors.orange.shade600,
              ),
            ),
          ],
        ),
      );
    }

    if (_isWithinGeofence) {
      return Container(
        padding: EdgeInsets.all(context.spacing(12)),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(context.borderRadius(8)),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green.shade700,
              size: context.iconSize(24),
            ),
            SizedBox(width: context.spacing(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Verificación exitosa!',
                    style: TextStyle(
                      fontSize: context.fontSize(14),
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  Text(
                    'Puede proceder a votar',
                    style: TextStyle(
                      fontSize: context.fontSize(12),
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _getErrorTitle(GeofenceErrorType errorType) {
    switch (errorType) {
      case GeofenceErrorType.permissionDenied:
      case GeofenceErrorType.permissionPermanentlyDenied:
        return 'Permiso de ubicación denegado';
      case GeofenceErrorType.locationDisabled:
        return 'GPS desactivado';
      case GeofenceErrorType.locationUnavailable:
        return 'Ubicación no disponible';
      case GeofenceErrorType.timeout:
        return 'Tiempo de espera agotado';
      case GeofenceErrorType.mockLocationDetected:
        return 'Ubicación simulada detectada';
      case GeofenceErrorType.accuracyTooLow:
        return 'Precisión de GPS insuficiente';
      case GeofenceErrorType.locationCacheExpired:
        return 'Cache de ubicación expirado';
      default:
        return 'Error desconocido';
    }
  }

  Widget _buildActionButtons() {
    // Si está dentro del geofence, no mostrar botones - la navegación es automática
    if (_isWithinGeofence) {
      return const SizedBox.shrink();
    }

    if (_isVerifying) return const SizedBox.shrink();

    final errorType = _error?.type;
    final isPermissionDenied =
        errorType == GeofenceErrorType.permissionDenied || errorType == GeofenceErrorType.permissionPermanentlyDenied;
    final isLocationDisabled = errorType == GeofenceErrorType.locationDisabled;

    return Row(
      children: [
        if (isPermissionDenied)
          Expanded(
            child: SizedBox(
              height: context.buttonHeight(45),
              child: ElevatedButton.icon(
                onPressed: _openAppSettings,
                icon: Icon(Icons.settings, size: context.iconSize(18)),
                label: Text(
                  'IR A CONFIGURACIÓN',
                  style: TextStyle(fontSize: context.fontSize(13)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.borderRadius(10)),
                  ),
                ),
              ),
            ),
          )
        else if (isLocationDisabled)
          Expanded(
            child: SizedBox(
              height: context.buttonHeight(45),
              child: ElevatedButton.icon(
                onPressed: _openLocationSettings,
                icon: Icon(Icons.gps_fixed, size: context.iconSize(18)),
                label: Text(
                  'ACTIVAR GPS',
                  style: TextStyle(fontSize: context.fontSize(13)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.borderRadius(10)),
                  ),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: SizedBox(
              height: context.buttonHeight(45),
              child: ElevatedButton.icon(
                onPressed: _retryVerification,
                icon: Icon(Icons.refresh, size: context.iconSize(18)),
                label: Text(
                  'VERIFICAR NUEVAMENTE',
                  style: TextStyle(fontSize: context.fontSize(13)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.borderRadius(10)),
                  ),
                ),
              ),
            ),
          ),
        SizedBox(width: context.spacing(12)),
        // Botón para ver instrucciones
        Tooltip(
          message: 'Ver instrucciones',
          child: IconButton(
            onPressed: _showInstructions,
            icon: Icon(
              Icons.help_outline,
              color: const Color(0xFF003366),
              size: context.iconSize(24),
            ),
          ),
        ),
      ],
    );
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Instrucciones de Verificación'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Para poder votar, debe encontrarse dentro del campus de la Universidad Continental.',
              ),
              SizedBox(height: context.spacing(12)),
              _buildInstructionItem(
                '1.',
                'Asegúrese de tener el GPS activado en su dispositivo.',
              ),
              _buildInstructionItem(
                '2.',
                'Otorgue los permisos de ubicación cuando se le soliciten.',
              ),
              _buildInstructionItem(
                '3.',
                'Espere a que el sistema verifique su ubicación.',
              ),
              _buildInstructionItem(
                '4.',
                'Si está dentro del campus (radio de 750m), podrá proceder a votar.',
              ),
              SizedBox(height: context.spacing(12)),
              const Text(
                'Nota: El uso de aplicaciones de suplantación de GPS está prohibido y será detectado.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing(4)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF003366),
            ),
          ),
          SizedBox(width: context.spacing(8)),
          Expanded(
            child: Text(text),
          ),
        ],
      ),
    );
  }
}
