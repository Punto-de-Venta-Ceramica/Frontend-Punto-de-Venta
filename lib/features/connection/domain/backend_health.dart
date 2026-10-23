/// A confirmed response from the point-of-sale service, independent of HTTP.
class BackendHealth {
  const BackendHealth({required this.application});
  final String application;
}
