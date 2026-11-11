import 'package:flutter_test/flutter_test.dart';
import 'package:punto_de_venta/features/productos/infrastructure/adapters/outbound/imagenes/cloudinary_url.dart';

void main() {
  const base = 'https://res.cloudinary.com/demo/image/upload';

  test('inserta la transformación con el tamaño redondeado hacia arriba', () {
    expect(
      urlImagenCloudinary('$base/v17/productos/a.jpg', 500),
      '$base/c_limit,w_640,h_640,f_auto,q_auto/v17/productos/a.jpg',
    );
    expect(
      urlImagenCloudinary('$base/v17/a.jpg', 100),
      '$base/c_limit,w_320,h_320,f_auto,q_auto/v17/a.jpg',
    );
  });

  test('no pide más que el tamaño máximo', () {
    expect(
      urlImagenCloudinary('$base/v17/a.jpg', 3000),
      '$base/c_limit,w_1024,h_1024,f_auto,q_auto/v17/a.jpg',
    );
  });

  test('funciona sin versión en la ruta', () {
    expect(
      urlImagenCloudinary('$base/a.jpg', 300),
      '$base/c_limit,w_320,h_320,f_auto,q_auto/a.jpg',
    );
  });

  test('deja igual las URL ajenas o ya transformadas', () {
    const ajena = 'https://example.com/image/upload/v1/a.jpg';
    expect(urlImagenCloudinary(ajena, 300), ajena);
    const transformada = '$base/w_100/v17/a.jpg';
    expect(urlImagenCloudinary(transformada, 300), transformada);
  });
}
