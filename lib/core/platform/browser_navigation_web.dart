import 'package:web/web.dart' as web;

void navigateBrowserTo(Uri uri) => web.window.location.assign(uri.toString());
