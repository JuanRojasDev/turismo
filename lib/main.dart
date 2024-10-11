import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: const WebViewExample(),
    );
  }
}

class WebViewExample extends StatefulWidget {
  const WebViewExample({super.key});

  @override
  WebViewExampleState createState() => WebViewExampleState();
}

class WebViewExampleState extends State<WebViewExample> {
  late final WebViewController _controller;
  bool isLoading = true;
  bool loadError = false;
  StreamSubscription<List<ConnectivityResult>>?
      subscription; // Esto es correcto
  bool isConnected = true;

  final List<String> offlineRoutes = [
    'https://creamosideas.com.co/',
    'https://creamosideas.com.co/index.php/nosotros/',
    'https://creamosideas.com.co/index.php/servicios/',
    'https://creamosideas.com.co/index.php/contact/'
  ];

  final List<String> socialMediaLinks = [
    'https://api.whatsapp.com/send/?phone=573138687749&text&type=phone_number&app_absent=0',
    'https://www.facebook.com/Creamosideas.com.co',
    'https://www.instagram.com/creamosideas.com.co/',
    'https://www.tiktok.com/@creamosideas.com.co?is_from_webapp=1&sender_device=pc'
  ];

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _initializeConnectivity();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (url) {
          setState(() {
            isLoading = false;
          });
          _cachePage(url);
        },
        onPageStarted: (url) {
          setState(() {
            isLoading = true;
          });
        },
        onWebResourceError: (error) {
          _handleWebResourceError(error);
        },
        onNavigationRequest: (request) {
          if (_isSocialMedia(request.url)) {
            _launchSocialMedia(request.url);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));

    _controller.loadRequest(Uri.parse('https://creamosideas.com.co/'));
  }

  void _initializeConnectivity() {
    subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      for (var result in results) {
        _updateConnectionStatus(
            result); // El 'result' es de tipo ConnectivityResult
      }
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      setState(() {
        isConnected = false;
        loadError = true;
      });
      _showOfflineBanner();
      _loadOfflinePage(); // Intenta cargar una página almacenada en caché si no hay conexión
    } else {
      setState(() {
        isConnected = true;
        loadError = false;
      });
      _controller.loadRequest(Uri.parse('https://creamosideas.com.co/'));
    }
  }

  Future<void> _cachePage(String url) async {
    final prefs = await SharedPreferences.getInstance();
    if (offlineRoutes.contains(url)) {
      prefs.setString(url, url); // Guarda la URL en el almacenamiento local
    }
  }

  Future<void> _loadOfflinePage() async {
    final prefs = await SharedPreferences.getInstance();
    for (String route in offlineRoutes) {
      if (prefs.containsKey(route)) {
        _controller.loadRequest(Uri.parse(route));
        return;
      }
    }
    // Mostrar un mensaje si no se encuentra ninguna página en caché
    _showOfflineDialog();
  }

  void _handleWebResourceError(WebResourceError error) {
    if (error.errorCode == -2) {
      setState(() {
        loadError = true;
      });
      _showOfflineBanner();
    } else {
      print("Error cargando página: ${error.description}");
    }
  }

  void _showOfflineBanner() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Estás navegando en modo offline.'),
        action: SnackBarAction(
          label: 'Recargar',
          onPressed: () {
            _controller.loadRequest(Uri.parse('https://creamosideas.com.co/'));
          },
        ),
        duration: const Duration(days: 365), // Mantener visible indefinidamente
      ),
    );
  }

  void _showOfflineDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sin conexión a internet'),
          content: const Text(
              'No tienes conexión a internet, por favor intenta más tarde.'),
          backgroundColor: Colors.white.withOpacity(0.9),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  bool _isSocialMedia(String url) {
    return socialMediaLinks.any((link) => url.startsWith(link));
  }

  Future<void> _launchSocialMedia(String url) async {
    // ignore: deprecated_member_use
    if (await canLaunch(url)) {
      // ignore: deprecated_member_use
      await launch(url);
    } else {
      throw 'No se pudo abrir $url';
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          _controller.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (isLoading) buildSkeletonScreen(),
            if (loadError) buildNoConnectionScreen(),
          ],
        ),
      ),
    );
  }

  Widget buildSkeletonScreen() {
    return Skeletonizer(
      enabled: true,
      child: Container(
        color: Colors.white, // Color blanco para el skeleton
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  Widget buildNoConnectionScreen() {
    return Skeletonizer(
      enabled: loadError,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 200,
              height: 20,
              color: Colors.white, // Color blanco para el skeleton
            ),
            const SizedBox(height: 20),
            Container(
              width: 200,
              height: 20,
              color: Colors.white, // Color blanco para el skeleton
            ),
          ],
        ),
      ),
    );
  }
}
