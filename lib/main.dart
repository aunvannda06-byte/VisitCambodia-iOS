import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VisitCambodiaApp());
}

class VisitCambodiaApp extends StatelessWidget {
  const VisitCambodiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Visit Cambodia',
      home: WebsiteScreen(),
    );
  }
}

class WebsiteScreen extends StatefulWidget {
  const WebsiteScreen({super.key});

  @override
  State<WebsiteScreen> createState() => _WebsiteScreenState();
}

class _WebsiteScreenState extends State<WebsiteScreen> {
  WebViewController? controller;

  int loadingProgress = 0;
  String? loadingError;
  bool isInitializing = true;

  static const String websiteUrl = 'https://visit-cambo.netlify.app/';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    try {
      final webController = WebViewController();

      await webController.setJavaScriptMode(JavaScriptMode.unrestricted);

      await webController.setBackgroundColor(Colors.white);

      // Configure Android geolocation permissions.
      if (webController.platform is AndroidWebViewController) {
        final androidController =
            webController.platform as AndroidWebViewController;

        await androidController.setGeolocationPermissionsPromptCallbacks(
          onShowPrompt: (request) async {
            final host = Uri.tryParse(request.origin)?.host;

            // Allow location requests only from the tourism site.
            if (host != 'visit-cambo.netlify.app') {
              return const GeolocationPermissionsResponse(
                allow: false,
                retain: false,
              );
            }

            final permission = await Permission.locationWhenInUse.request();

            return GeolocationPermissionsResponse(
              allow: permission.isGranted,
              retain: permission.isGranted,
            );
          },
        );
      }

      await webController.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;

            setState(() {
              loadingProgress = progress;
            });
          },
          onPageStarted: (url) {
            if (!mounted) return;

            setState(() {
              loadingProgress = 0;
              loadingError = null;
              isInitializing = true;
            });

            debugPrint('Page started: $url');
          },
          onPageFinished: (url) {
            if (!mounted) return;

            setState(() {
              loadingProgress = 100;
              loadingError = null;
              isInitializing = false;
            });

            debugPrint('Page loaded: $url');
          },
          onWebResourceError: (error) {
            debugPrint(
              'WebView error: ${error.errorCode} '
              '${error.description}; URL: ${error.url}',
            );

            // Only show an error page for main-frame failures.
            if (error.isForMainFrame != true || !mounted) {
              return;
            }

            setState(() {
              loadingError = error.description;
              isInitializing = false;
            });
          },
        ),
      );

      if (!mounted) return;

      setState(() {
        controller = webController;
      });

      await _loadWebsite(webController);
    } catch (error, stackTrace) {
      debugPrint('WebView initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        loadingError = error.toString();
        isInitializing = false;
      });
    }
  }

  Future<void> _loadWebsite(WebViewController webController) async {
    if (!mounted) return;

    setState(() {
      loadingError = null;
      loadingProgress = 0;
      isInitializing = true;
    });

    try {
      // Load the normal HTTPS URL without custom cache headers.
      await webController.loadRequest(Uri.parse(websiteUrl));
    } catch (error) {
      debugPrint('Website request failed: $error');

      if (!mounted) return;

      setState(() {
        loadingError = error.toString();
        isInitializing = false;
      });
    }
  }

  Future<void> _handleBackButton() async {
    final webController = controller;

    if (webController == null) return;

    try {
      if (await webController.canGoBack()) {
        await webController.goBack();
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are already on the home page.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      debugPrint('Back navigation failed: $error');
    }
  }

  Future<void> _refreshWebsite() async {
    final webController = controller;

    if (webController == null) {
      await _initializeWebView();
      return;
    }

    await _loadWebsite(webController);
  }

  @override
  Widget build(BuildContext context) {
    final webController = controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackButton();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (isInitializing && loadingError == null)
                const LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Color(0xFFEEEEEE),
                  color: Color(0xFF1769AA),
                ),
              Expanded(
                child: loadingError != null
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wifi_off_rounded,
                                size: 64,
                                color: Color(0xFF1769AA),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Unable to load Visit Cambodia',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Please check your internet connection '
                                'and try again.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              SelectableText(
                                loadingError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _refreshWebsite,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : webController == null
                    ? const Center(child: CircularProgressIndicator())
                    : WebViewWidget(controller: webController),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
