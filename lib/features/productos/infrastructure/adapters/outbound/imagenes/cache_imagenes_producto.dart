import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Caché en disco de las fotos de productos (Cloudinary), compartida por
/// todas las pantallas que las muestran.
///
/// La caché por defecto de `cached_network_image` guarda solo 200 archivos, y
/// cada producto puede ocupar hasta tres (uno por tamaño de
/// `tamaniosImagenCloudinary`): con unos 70 productos ya se llenaría y las
/// fotos se volverían a descargar. Aquí:
///
/// - [maxNrOfCacheObjects]: 1000 archivos (~300 productos en los tres
///   tamaños). Con `f_auto,q_auto` cada uno pesa decenas de KB, así que
///   ocupa como mucho unas decenas de MB.
/// - [stalePeriod]: 60 días sin usarse. No hay riesgo de ver una foto vieja:
///   al reemplazarla, Cloudinary cambia la versión (`v123…`) y con ella la URL.
///
/// En web no aplica: el navegador usa su propia caché HTTP con las cabeceras
/// que manda Cloudinary.
final cacheImagenesProducto = CacheManager(
  Config(
    'imagenesProducto',
    stalePeriod: const Duration(days: 60),
    maxNrOfCacheObjects: 1000,
  ),
);
