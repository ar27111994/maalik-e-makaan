/// Whether [error] is a dart:io transport failure. Without dart:io (the
/// web build) the browser client reports every one as a `ClientException`,
/// so nothing else is.
bool isTransportError(Object error) => false;
