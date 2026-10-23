# Recursos del registro de propietario

- Fuente visual: [Bocetos Aplicación en Figma](https://www.figma.com/design/9lOGkDdFGtbAiO15OwXyTI?node-id=13-35).
- Marcos usados: `13:35` (registro normal), `27:265` (validaciones) y `13:16` (login).
- El login reutiliza exactamente los componentes originales `24:60` (marca),
  `24:24` (correo), `24:35` (candado) y `24:28` (ojo), ya descargados para registro.
- Los ocho SVG locales provienen de los componentes originales de ese archivo:
  marca (32 × 32), persona, correo, teléfono, candado, ojo, error y éxito (20 × 20).
- Los campos usan iconos de 20 × 20. Los mensajes conservan el contenedor de 14 × 14
  del diseño y su icono original de 20 × 20, sin recortar.
- Inter se incluye localmente para funcionar sin depender de descargas de fuentes
  durante la ejecución. Fuente: repositorio oficial `google/fonts`, `ofl/inter`.
  Su licencia SIL Open Font License está en `fonts/OFL.txt`.

Las pantallas se construyen con widgets y campos editables. Las capturas de Figma
no forman parte de la interfaz ni se usan como imágenes de fondo.
