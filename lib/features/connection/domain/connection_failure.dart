/// Failure exposed to the application without depending on a transport library.
class ConnectionFailure implements Exception {
  const ConnectionFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
