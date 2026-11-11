/// Tamaños (px, lado mayor) que se piden a Cloudinary. Son pocos y fijos a
/// propósito: cada combinación distinta es una transformación derivada que
/// Cloudinary genera y cobra una vez, y que la caché del dispositivo guarda
/// por separado.
const tamaniosImagenCloudinary = [320, 640, 1024];

/// URL de entrega de Cloudinary escalada a lo que realmente se va a mostrar.
///
/// [ladoPx] es el lado mayor del recuadro en píxeles físicos; se redondea
/// hacia arriba al siguiente tamaño de [tamaniosImagenCloudinary]. Además pide
/// el formato más ligero que acepte el dispositivo (`f_auto`, WebP o AVIF) y
/// la calidad automática (`q_auto`). `c_limit` nunca agranda ni recorta: solo
/// reduce conservando la proporción.
///
/// Las URL que no son de Cloudinary, o que ya traen transformaciones, se
/// devuelven sin cambios.
String urlImagenCloudinary(String url, double ladoPx) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host != 'res.cloudinary.com') return url;
  final segmentos = uri.pathSegments;
  // /<cloud>/image/upload/[v123/]<public_id>
  final upload = segmentos.indexOf('upload');
  if (upload < 2 ||
      segmentos[upload - 1] != 'image' ||
      upload + 1 >= segmentos.length) {
    return url;
  }
  final siguiente = segmentos[upload + 1];
  final esVersion = RegExp(r'^v\d+$').hasMatch(siguiente);
  if (!esVersion && segmentos.length > upload + 2) return url;

  final lado = tamaniosImagenCloudinary.firstWhere(
    (t) => t >= ladoPx,
    orElse: () => tamaniosImagenCloudinary.last,
  );
  return uri
      .replace(
        pathSegments: [
          ...segmentos.take(upload + 1),
          'c_limit,w_$lado,h_$lado,f_auto,q_auto',
          ...segmentos.skip(upload + 1),
        ],
      )
      .toString();
}
