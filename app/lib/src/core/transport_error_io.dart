import 'dart:io';

/// Whether [error] is a dart:io transport failure that package:http passes on
/// without wrapping it in a `ClientException`: TLS failures
/// ([HandshakeException], [CertificateException]) above all. A
/// [FileSystemException] is an [IOException] too but says nothing about the
/// network, so only these types count.
bool isTransportError(Object error) =>
    error is SocketException || error is TlsException || error is HttpException;
