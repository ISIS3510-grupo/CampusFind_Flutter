import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

typedef StorageUrlResolver = Future<String> Function(String path);

// Shows a photo saved as a Firebase Storage path (photoPath, e.g.
// "lostReports/abc.jpg"). Image.network needs a URL, so the path is first
// resolved with getDownloadURL. Resolved URLs are kept in memory so the same
// photo is not resolved again when the screen rebuilds or reopens.
class StorageImage extends StatefulWidget {
  const StorageImage({
    super.key,
    required this.path,
    required this.placeholder,
    this.fit = BoxFit.cover,
    this.resolveUrl,
  });

  final String? path;
  final Widget placeholder;
  final BoxFit fit;
  // Injected in tests; the app uses Firebase Storage.
  final StorageUrlResolver? resolveUrl;

  static final Map<String, Future<String>> _urls = {};

  @visibleForTesting
  static void clearCache() => _urls.clear();

  @override
  State<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<StorageImage> {
  Future<String>? _url;

  @override
  void initState() {
    super.initState();
    _url = _resolve();
  }

  @override
  void didUpdateWidget(StorageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _url = _resolve();
  }

  Future<String>? _resolve() {
    final path = widget.path?.trim() ?? '';
    if (path.isEmpty) return null;
    // Older documents or tests may already store a full URL.
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Future.value(path);
    }
    final resolver =
        widget.resolveUrl ??
        (path) => FirebaseStorage.instance.ref(path).getDownloadURL();
    return StorageImage._urls.putIfAbsent(
      path,
      () => resolver(path).catchError((Object error) {
        // A failed lookup (offline, photo not uploaded yet) is retried later.
        StorageImage._urls.remove(path);
        throw error;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    if (url == null) return widget.placeholder;
    return FutureBuilder<String>(
      future: url,
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        if (resolved == null) return widget.placeholder;
        return Image.network(
          resolved,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) => widget.placeholder,
        );
      },
    );
  }
}
