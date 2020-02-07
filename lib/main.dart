import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'package:preferences/preferences.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:cryptpad_photos_app/preferences.dart';
import 'package:logger/logger.dart';
import 'package:logger_flutter/logger_flutter.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

enum ConfirmAction { CANCEL, ACCEPT }
var logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PrefService.init(prefix: '');
  runApp(PhotosApp());
}

const kAndroidUserAgent =
    'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Mobile Safari/537.36';

// ignore: prefer_collection_literals
final Set<JavascriptChannel> jsChannels1 = [
  JavascriptChannel(
      name: 'Print1',
      onMessageReceived: (JavascriptMessage message) {
        logger.d("JSMESSAGE MAIN");
        logger.d(message.message);
      }),
].toSet();

class PhotosApp extends StatelessWidget {
  // WebView to manage the relationship with CryptPad.
  MyHomePage homePage = MyHomePage(title: 'CryptPad Photos');

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photos',
      theme: ThemeData(
          primarySwatch: Colors.blue,
          buttonTheme: ButtonThemeData(
            minWidth: 30,
          )),
      home: homePage,
      routes: {
        '/preferences': (context) => PreferencesPage(title: 'Settings'),
        '/photo': (_) {
          return homePage.homePageState.photoViewWidget();
        }
      },
    );
  }

/*
  WebviewScaffold _cryptpadLoginWidget() {
    return WebviewScaffold(
      url: homePage.getCryptPadInstanceURL(),
      javascriptChannels: jsChannels1,
      mediaPlaybackRequiresUserGesture: false,
      appBar: AppBar(
        title: const Text('CryptPad'),
      ),
      withZoom: true,
      withLocalStorage: true,
      hidden: true,
      initialChild: Container(
        color: Colors.redAccent,
        child: const Center(
          child: Text('Waiting.....'),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () {
                homePage.homePageState.flutterWebViewPlugin.goBack();
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () {
                homePage.homePageState.flutterWebViewPlugin.goForward();
              },
            ),
            IconButton(
              icon: const Icon(Icons.autorenew),
              onPressed: () {
                homePage.homePageState.flutterWebViewPlugin.reload();
              },
            ),
          ],
        ),
      ),
    );
  }
*/
}

class MyHomePage extends StatefulWidget {
  MyHomePageState homePageState;

  MyHomePage({Key key, this.title}) : super(key: key) {
    homePageState = MyHomePageState();
  }

  final String title;

  @override
  MyHomePageState createState() => homePageState;

  String getCryptPadInstanceURL() {
    return MyHomePageState.getCryptPadInstanceURL();
  }
}

class MyHomePageState extends State<MyHomePage> {
  String currentView = "local";
  int selectedImageindex = 0;
  String selectedLocalImage = "";
  Image selectedImage = null;
  bool selectedImageFail = false;

  List<AssetPathEntity> imagesList = [];
  List<AssetEntity> assetList = [];
  Map<String, dynamic> remoteImagesListMap = new Map<String, dynamic>();
  List<String> remoteImagesList = new List<String>();

  String currentFilename = "";
  int currentIndex = 0;

  bool flutterWebViewPluginLoaded = false;
  bool webViewVisible = false;

  FlutterWebviewPlugin flutterWebViewPlugin;
  final List<StaggeredTile> _staggeredTiles = const <StaggeredTile>[
    const StaggeredTile.count(2, 2),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(2, 2),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(2, 1),
    const StaggeredTile.count(1, 2),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
    const StaggeredTile.count(1, 1),
  ];

  StreamSubscription<WebViewHttpError> _onHttpError;

  Base64Codec base64 = const Base64Codec();

  bool uploadStarted = false;
  bool autoSyncStarted = false;
  bool silentUpload = false;
  bool reloadWebView = false;
  Map<String, dynamic> driveData;
  Map<String, dynamic> uploadStatus;
  double uploadProgress = 0;
  Set<JavascriptChannel> jsChannels;

  // App Settings
  static String cryptpadInstanceURL = "https://cryptpad.fr/";
  static bool autoSync = false;
  static bool autoSyncWifiOnly = true;
  static bool syncVideos = false;

  static int maxDays = 0;
  static String startPage = "local";

  static String getCryptPadInstanceURL() {
    var url = cryptpadInstanceURL;
    if (!url.endsWith("/")) url += "/";
    return url;
  }

  static void setCryptPadInstanceURL(String url) {
    cryptpadInstanceURL = url;
  }

  static bool isAutoSync() {
    return autoSync;
  }

  static void setAutoSync(sync) {
    autoSync = sync;
  }

  static bool isAutoSyncWifiOnly() {
    return autoSyncWifiOnly;
  }

  static void setAutoSyncWifiOnly(sync) {
    autoSyncWifiOnly = sync;
  }

  static bool isSyncVideos() {
    return syncVideos;
  }

  static void setSyncVideos(sync) {
    syncVideos = sync;
  }

  static int getMaxDays() {
    return maxDays;
  }

  static void setMaxDays(int max) {
    maxDays = max;
  }

  Future<Null> readSettings() async {
    final prefs = await SharedPreferences.getInstance();
    var url = prefs.getString("server");
    if (url != null && url != "") {
      setCryptPadInstanceURL(url);
    }
    bool aSync = prefs.getBool("autosync");
    setAutoSync((aSync == null) ? false : aSync);

    bool aSyncWifi = prefs.getBool("autosyncwikionly");
    setAutoSyncWifiOnly((aSyncWifi == null) ? false : aSyncWifi);

    bool vSync = prefs.getBool("syncvideos");
    setSyncVideos((vSync == null) ? false : vSync);

    String mDays = "1";
    try {
      mDays = prefs.getString('maxdays');
    } catch (e) {
      logger.d("Cannot read max days");
    }
    if (mDays==null)
      mDays = "1";

    setMaxDays(int.parse(mDays));
    startPage = prefs.getString("startpage");
    if (startPage == null) startPage = "local";

    logger.d("Current settings");
    logger.d("URL: " + getCryptPadInstanceURL());
    logger.d("autoSync: " + autoSync.toString());
    logger.d("autoSyncWifiOnly: " + autoSyncWifiOnly.toString());
    logger.d("syncVideos: " + syncVideos.toString());
    logger.d("maxDays: " + maxDays.toString());
    logger.d("startPage: " + startPage);
  }

  @override
  void initState() {
    requestPermission();
    super.initState();
    readSettings().then((value) {
      jsChannels = [
        JavascriptChannel(
            name: 'UploadComplete',
            onMessageReceived: (JavascriptMessage message) {
              logger.d("JAVASCRIPT MESSAGE: " + message.message);
              if (message.message.startsWith("/file/")) {
                // Persist the remote path on the CryptPad server
                logger.d("Persisting output for " + currentFilename);
                saveString(
                    getCryptPadInstanceURL(), currentFilename, message.message);
                uploadStarted = false;
                uploadProgress = 0;
                if (!silentUpload)
                  _showDialog("Image replicated", message.message);
                requestPermission();
              }
            }),
        JavascriptChannel(
            name: 'CryptPadReady',
            onMessageReceived: (JavascriptMessage message) {
              flutterWebViewPluginLoaded = true;
              // load the drive data
              _getUserObject();
              logger.d("JAVASCRIPT CryptPadReady");
            }),
        JavascriptChannel(
            name: 'Console',
            onMessageReceived: (JavascriptMessage message) {
              logger.d("JAVASCRIPT Console: " + message.message);
            }),
        JavascriptChannel(
            name: 'Alert',
            onMessageReceived: (JavascriptMessage message) {
              logger.d("JAVASCRIPT Alert: " + message.message);
              _showDialog("Alert", message.message);
            }),
        JavascriptChannel(
            name: 'Drive',
            onMessageReceived: (JavascriptMessage message) {
              logger.d("JAVASCRIPT Drive data: " + message.message);
              setState(() {
                driveData = jsonDecode(message.message);
                remoteImagesList = new List<String>();
              });
              if ((driveData == null) ||
                  (driveData["cryptpad.username"] == null)) {
                _showDialog("Error",
                    "You are not connected to CryptPad. Use the CryptPad view to login.");
              } else {
                // Forcing a sync if autoSync is enabled
                if (isAutoSync()) {
                  syncImages(10, true);
                }
              }
            }),
        JavascriptChannel(
            name: 'UploadProgress',
            onMessageReceived: (JavascriptMessage message) {
              logger.d("JAVASCRIPT Upload progress: " + message.message);
              setState(() {
                uploadProgress = double.parse(message.message);
              });
            }),
        JavascriptChannel(
            name: 'UploadStatus',
            onMessageReceived: (JavascriptMessage message) {
              logger.d("JAVASCRIPT Upload status: " + message.message);
              uploadStatus = jsonDecode(message.message);
            }),
        JavascriptChannel(
            name: 'UploadError',
            onMessageReceived: (JavascriptMessage message) {
              logger.d("JAVASCRIPT Upload error: " + message.message);
              if (message.message == "RPC_NOT_READY") {
                _showDialog("Upload Error",
                    "You are not connected to CryptPad. Use the cryptpad view to login.");
                reloadWebView = true;
              } else {
                _showDialog("Upload Error", message.message);
              }
              uploadStarted = false;
            }),
        JavascriptChannel(
            name: 'GetFileMetadata',
            onMessageReceived: (JavascriptMessage message) {
              logger.d("JAVASCRIPT GetMetadata: " + message.message);
              var data = jsonDecode(message.message);
              var href = data["href"];
              var thumbnail = data["metadata"]["thumbnail"];
              var file = remoteImagesListMap[href];
              file["thumbnail"] = thumbnail;
            }),
        JavascriptChannel(
            name: 'GetFileFulldata',
            onMessageReceived: (JavascriptMessage message) {
              logger.d("JAVASCRIPT GetFileFulldata: " + message.message);
              var data = message.message;
              var bytes = null;
              try {
                var bytes = base64.decode(data);
                Image image = new Image.memory(bytes);
                setState(() {
                  selectedImage = image;
                });
              } catch (e) {
                selectedImageFail = true;
                logger.d("Error decoding base64 image data");
                logger.d(e);
              }
            }),
      ].toSet();

      PhotoManager.addChangeCallback((value) {
        // Force recheck of images
        Future.delayed(new Duration(seconds: 2)).then((value) {
          requestPermission().then((value) {
            if (isAutoSync()) {
              syncImages(10, true);
            }
          });
        });
      });
      PhotoManager.startChangeNotify();

      startFlutterWebviewPlugin();
    });
  }

  Future<Null> stopFlutterWebviewPlugin() async {
    flutterWebViewPluginLoaded = false;
    if (flutterWebViewPlugin == null) return;
    try {
      webViewVisible = false;
      await flutterWebViewPlugin.close().timeout(new Duration(seconds: 5));
    } catch (e) {}
    flutterWebViewPlugin.dispose();
    flutterWebViewPlugin = null;
  }

  Future<Null> startFlutterWebviewPlugin() async {
    flutterWebViewPlugin = FlutterWebviewPlugin();
    flutterWebViewPlugin.onStateChanged.listen((viewState) async {
      if (viewState.type == WebViewState.finishLoad) {
        Future.delayed(new Duration(seconds: 5), () {
          flutterWebViewPlugin.evalJavascript(
              """Console.postMessage("Test cryptpad ready start");
                                               Cryptpad.ready(function() { 
                                                      Console.postMessage("CryptPad Ready"); 
                                                      CryptPadReady.postMessage(""); 
                                               }); 
                                               Console.postMessage("Test cryptpad ready end");
                                               """);
        });
        logger.d("WebView loaded");
      }
    });
    _onHttpError =
        flutterWebViewPlugin.onHttpError.listen((WebViewHttpError error) {
      logger.d("In HTTP error for url: " + error.url);
      logger.d("Error code: " + error.code);
      if (error.code == "-6") {
        _showDialog("Error",
            "An error occured while loading CryptPad. Check your settings.");
      }
    });
    return _loadWebView();
  }

  Future<Null> restartFlutterWebviewPlugin() async {
    await stopFlutterWebviewPlugin();
    return startFlutterWebviewPlugin();
  }

  Future<Null> _loadWebView() async {
    var url = getCryptPadInstanceURL() + "drive/";
    logger.d("WebView launch: " + url);
    var size = MediaQuery.of(context).size;
    var future = flutterWebViewPlugin.launch(url,
        javascriptChannels: jsChannels,
        hidden: true,
        rect: new Rect.fromLTWH(
          0.0,
          85,
          size.width,
          size.height - 85,
        ));
    future.then((value) {
      logger.d("Webview launch done");
    });
    return future;
  }

  Future<Null> requestPermission() async {
    var result = await PhotoManager.requestPermission();
    if (result) {
      currentIndex = 0;
      var myimagesList = await PhotoManager.getImageAsset();
      if (myimagesList == null || myimagesList.length == 0) return;

      var myassetList = await myimagesList[0].assetList;
      setState(() {
        imagesList = myimagesList;
        assetList = myassetList;
      });
    } else {
      // fail
    }
  }

  void _showDialog(String title, String message) {
    // flutter defined function
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text(title),
          content: new Text(message),
          actions: <Widget>[
            // usually buttons at the bottom of the dialog
            new FlatButton(
              child: new Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<ConfirmAction> _asyncConfirmDialog(
      String title, String message) async {
    return showDialog<ConfirmAction>(
      context: context,
      barrierDismissible: false, // user must tap button for close dialog!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            FlatButton(
              child: const Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.CANCEL);
              },
            ),
            FlatButton(
              child: const Text('ACCEPT'),
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.ACCEPT);
              },
            )
          ],
        );
      },
    );
  }

  Future<List> _loadImageData(index) async {
    AssetEntity entity = assetList[index % assetList.length];
    File file = await entity.file;
    String filename = p.basename(file.path);
    String currentRemotePage = (filename == null)
        ? ""
        : await getString(getCryptPadInstanceURL(), filename);
    bool isReplicated = (currentRemotePage != null);
    // logger.d("Image: " + filename + " remote: " + currentRemotePage.toString() + " isReplicated: " + isReplicated.toString());
    return [Image.file(await entity.file), isReplicated, filename];
  }

  Future<List> getImage(index) async {
    if (index >= assetList.length) return null;
    AssetEntity entity = assetList[index];
    File file = await entity.file;
    DateTime fileDate = entity.createDateTime;
    String filename = p.basename(file.path);
    // Check if we have not already pushed this image to cryptpad
    String currentRemotePage =
        await getString(getCryptPadInstanceURL(), filename);
    if (currentRemotePage != null && index < assetList.length) {
      currentIndex++;
      return getImage(index + 1);
    }

    // Check if we find this image in the drive data
    var remoteImageData = await _getRemoteImageData(filename, false);
    if (remoteImageData != null) {
      logger.d("Image already in drive");
      currentIndex++;
      return getImage(index + 1);
    }

    // Retrieve base64 thumbnail
    String b64 = base64.encode(
        await entity.thumbDataWithSize(100, 100, format: ThumbFormat.png));
    return [await entity.fullData, filename, currentRemotePage, b64, fileDate];
  }

  // 1
  String _generateKey(String server, String key) {
    return '$server/$key';
  }

  /*
   CryptPad functions: get drive data
   */
  Future<Map<String, dynamic>> _getUserObject() async {
    driveData = null;
    String script = """Console.postMessage("getUserObject start");
                     Cryptpad.getUserObject("", function(data) { 
                      Console.postMessage("getUserObject callback");
                      Drive.postMessage(JSON.stringify(data));
                     });
                    Console.postMessage("getUserObject end"); 
                     """;
    _readyForUpload(false).then((bool ready) {
      if (ready) {
        flutterWebViewPlugin.evalJavascript(script);
      }
    });

    return await waitForDriveData(5, 1);
  }

  Future<List<dynamic>> getImagesToSync(int max) async {
    int nb = 0;
    DateTime now = DateTime.now();
    List<dynamic> imagesToSync = new List<dynamic>();
    assetList.sort((e1, e2) => e2.createDateTime.compareTo(e1.createDateTime));
    for (var index = 0; index < assetList.length; index++) {
      AssetEntity entity = assetList[index];
      File file = await entity.file;
      DateTime fileDate = entity.createDateTime;
      var nbDays = now.difference(fileDate).inDays;
      if (nbDays <= maxDays) {
        String filename = p.basename(file.path);
        // Check if we have not already pushed this image to cryptpad
        String currentRemotePage =
            await getString(getCryptPadInstanceURL(), filename);
        if (currentRemotePage == null) {
          // Check if we find this image in the drive data
          var remoteImageData = await _getRemoteImageData(filename, false);
          if (remoteImageData != null) {
            logger.d("Image already in drive");
          } else {
            nb++;
            // Retrieve base64 thumbnail
            String b64 = base64.encode(await entity.thumbDataWithSize(100, 100,
                format: ThumbFormat.png));
            logger.d("Adding image " + filename + " to images to sync");
            imagesToSync
                .add([await entity.fullData, filename, currentRemotePage, b64]);
            if (nb > max) {
              break;
            }
          }
        }
      } else {
        logger.d("Images is " +
            nbDays.toString() +
            " old so more than " +
            maxDays.toString());
        // there cannot be more images to sync as all are older
        return imagesToSync;
      }
    }
    return imagesToSync;
  }

  Future<Null> syncImages(int max, bool silence) async {
    if (autoSyncStarted == true) {
      logger.d("A sync is already in progress");
      return;
    }

    autoSyncStarted = true;
    List<dynamic> images = await getImagesToSync(max);
    if (images.length >= max) {
      ConfirmAction action = await _asyncConfirmDialog(
          "There are more than " + max.toString() + " images to sync",
          "Would you like to cancel the sync or still perform it ?");
      if (action == ConfirmAction.CANCEL) {
        autoSyncStarted = false;
        return;
      }
    }

    logger.d("Starting sync");
    int nb = 0;
    for (List<dynamic> data in images) {
      silentUpload = true;
      _syncImage(data, true);
      for (var i = 0; i < 50; i++) {
        if (uploadStarted == false) break;
        await Future.delayed(new Duration(seconds: 2));
      }

      if (uploadStarted == true) {
        if (!silence)
          _showDialog(
              "Error",
              "A sync did not finish in time. Stopped at sync " +
                  nb.toString());
        autoSyncStarted = false;
        return;
      }
      nb++;
    }
    if (!silence) _showDialog("Sync", nb.toString() + " images synced");
    logger.d("Sync done: " + nb.toString() + " images");
    autoSyncStarted = false;
  }

  Future<Map<String, dynamic>> waitForDriveData(int nb, int seconds) async {
    for (var i = 0; i < nb; i++) {
      if (driveData != null)
        return driveData;
      else
        await Future.delayed(new Duration(seconds: seconds));
    }
    return driveData;
  }

  /*
   CryptPad functuions: get remote data for one file
   */
  Future<Map<String, dynamic>> _getRemoteImageData(
      String filename, bool forceLoad) async {
    if (forceLoad || (driveData == null)) {
      driveData = await _getUserObject();
    }

    Map filesData = driveData["drive"]["filesData"];
    for (var key in filesData.keys) {
      var value = filesData[key];
      if (value["title"] == filename) {
        logger.d("Found remote value: " + value.toString());
        // store this locally
        var href = value["href"];
        saveString(getCryptPadInstanceURL(), filename, href);
        return value;
      }
    }
    logger.d("Did not find remote value");
    return null;
  }

  Future<List<dynamic>> _loadDriveImageData(index) async {
    var href = remoteImagesList[index];
    var file = remoteImagesListMap[href];
    var name = file["title"];
    var image = file["image"];
    if (image != null) {
      // logger.d("Found image in cache for " + href + " " + name);
      return [image, name];
    }

    var thumbnail = file["thumbnail"];
    if (thumbnail == null) {
      var script = """
     require(['/file/file-crypto.js'], function (FileCrypto) {
       var href = '""" +
          href +
          """';
       var data =CryptPad_Hash.parsePadUrl(href)
       var secret = CryptPad_Hash.getSecrets(data.type, data.hash, data.password)
       var src = "" + CryptPad_Hash.getBlobPathFromHex(secret.channel);
       var key = secret.keys && secret.keys.cryptKey;
       FileCrypto.fetchDecryptedMetadata(src, key, function (e, metadata) {
          var json = { href : href, metadata : metadata };
          GetFileMetadata.postMessage(JSON.stringify(json));          
       });
     });
    """;
      flutterWebViewPlugin.evalJavascript(script);
    }

    for (var i = 0; i < 10; i++) {
      thumbnail = file["thumbnail"];
      if (thumbnail != null) {
        logger.d("Found thumbnail for " + href + " " + name);
        break;
      }
      await Future.delayed(new Duration(seconds: 3));
    }

    if (thumbnail != null) {
      logger.d("Decoding base64 image for " + href + " " + name);
      var str = thumbnail.substring(thumbnail.indexOf(",") + 1);
      logger.d(str);
      var bytes = base64.decode(str);
      var image = new Image.memory(bytes);
      file["image"] = image.image;
      return [image.image, name];
    }

    logger.d("Could not find image for " + href + " " + name);
    return null;
  }

  /*
   CryptPad functions get number of images
   */
  int _getDriveImageNumber() {
    try {
      if (driveData == null) {
        logger.d("Drive not loaded");
        return 0;
      }

      if (remoteImagesList.length == 0) {
        logger.d("Sorting drive files list");
        int nb = 0;
        Map filesData = driveData["drive"]["filesData"];
        var sortedMap = Map.fromEntries(filesData.entries.toList()
          ..sort((e1, e2) => e2.value["ctime"].compareTo(e1.value["ctime"])));

        for (var key in sortedMap.keys) {
          var file = filesData[key];
          var fileType = file["fileType"];
          if (fileType != null && fileType.startsWith("image/")) {
            var href = file["href"];
            remoteImagesList.add(href);
            remoteImagesListMap[href] = file;
            nb++;
          }
        }
        logger.d("Found " + nb.toString() + " images");
        return nb;
      } else {
        logger.d("Drive already sorted");
        return remoteImagesList.length;
      }
    } catch (e) {
      logger.d("Exception counting images");
      logger.d(e);
      return 0;
    }
  }

  Widget photoViewWidget() {
    if (currentView == "local")
      return FutureBuilder(
          future: _loadImageData(selectedImageindex),
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            return Container(
                child: PhotoView(
                    imageProvider: (snapshot.data == null)
                        ? new AssetImage('assets/cryptpad-logo-512.png')
                        : snapshot.data[0].image));
          });
    else
      return FutureBuilder(
          future: _loadDriveImageFullData(selectedImageindex),
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            return Container(
                child: PhotoView(
                    imageProvider: (snapshot.data == null)
                        ? new AssetImage('assets/cryptpad-logo-512.png')
                        : snapshot.data.image));
          });
  }

  /*
  Function to read the full file decrypted data from the href of the file pad
  The return is going through the JSChannel called GetFileFulldata
   */
  Future<Image> _loadDriveImageFullData(index) async {
    selectedImage = null;
    selectedImageFail = false;
    var href = remoteImagesList[index];
    var file = remoteImagesListMap[href];
    logger.d("_loadDriveImageFullData Getting image: " +
        href +
        " " +
        file["channel"]);
    var script = """
    Console.postMessage("In script");     
    require(['/file/file-crypto.js'], function (FileCrypto) {
       function _arrayBufferToBase64( buffer ) {
          var binary = '';
          var bytes = new Uint8Array( buffer );
          var len = bytes.byteLength;
          for (var i = 0; i < len; i++) {
              binary += String.fromCharCode( bytes[ i ] );
          }
          return window.btoa( binary );
       }
       
       var readFile = function(fData, cb) {
         try {
         var href = (fData.href && fData.href.indexOf('#') !== -1) ? fData.href : fData.roHref;
         var parsed = CryptPad_Hash.parsePadUrl(href);
         var hash = parsed.hash;
         var name = fData.filename || fData.title;
      
         var secret = CryptPad_Hash.getSecrets('file', hash, fData.password);
         var src = CryptPad_Hash.getBlobPathFromHex(fData.channel);
         var key = secret.keys && secret.keys.cryptKey;
         CryptPad_Util.fetch(src, function (err, u8) {
            FileCrypto.decrypt(u8, key, function (err, res) {
              var reader = new FileReader();
              reader.addEventListener("loadend", function() {
              cb(reader.result);
              });
              reader.readAsArrayBuffer(res.content); 
            });
         }); 
         } catch (e) {
          Console.postMessage("Error");
          Console.postMessage(e);
         } 
       };
       Console.postMessage("In readfile prepare data");     
       var fData = {
        "channel": '""" +
        file["channel"] +
        """',
        "href": '""" +
        href +
        """',
       }
       readFile(fData, function(data) {
        Console.postMessage("In readfile feedback");     
        GetFileFulldata.postMessage(_arrayBufferToBase64(data)); 
       }); 
    });
    Console.postMessage("End script");     
 """;
    logger.d("Launching javascript");
    logger.d(script);
    flutterWebViewPlugin.evalJavascript(script);

    logger.d("Waiting for image load");
    for (var i = 0; i < 10; i++) {
      if (selectedImage != null) {
        logger.d("Image has been loaded");
        return selectedImage;
      }
      if (selectedImageFail) {
        logger.d("Image failed to load");
        return null;
      }
      await Future.delayed(new Duration(seconds: 3));
      logger.d("Waiting more");
    }
    logger.d("Giving up");
    return null;
  }

  @override
  void saveString(String server, String filename, String value) async {
    // 2
    final prefs = await SharedPreferences.getInstance();
    // 3
    await prefs.setString(_generateKey(server, filename), value);
  }

  @override
  Future<String> getString(String server, String filename) async {
    // 1
    final prefs = await SharedPreferences.getInstance();
    // 2
    return prefs.getString(_generateKey(server, filename));
  }

  String _getUploadScript(imageData, filename, b64) {
    StringBuffer str = new StringBuffer();
    var it = imageData.iterator;
    while (it.moveNext()) {
      var char = it.current;
      str.write("'");
      str.write(it.current);
      str.write("',");
    }
    String script = """
          var filename = '""" +
        filename +
        """';
        Console.postMessage("script start"); 
        var u8 = new Uint8Array( [""" +
        str.toString() +
        """]);
        var metadata = {name: filename, type: "image/png", thumbnail: "data:image/png;base64,""" +
        b64 +
        """", owners: []}
        var file = { blob: u8, metadata : metadata, forceSave : true, owned : true, path: ["root"], uid: CryptPad_Util.uid()}
        
        var result = "";
        require(['/common/outer/upload.js'], function (Files) {
          try {
           Console.postMessage("begin require");  
           var uploadProgress = function(res) {
             Console.postMessage("In progress");  
             Console.postMessage(res);
             UploadProgress.postMessage(res);
           }
           var uploadComplete = function(res) {
             Console.postMessage("In complete");  
             Console.postMessage(res);
             UploadComplete.postMessage(res);
          }
           var uploadError = function(res) {
             Console.postMessage("In error");  
             Console.postMessage(res);
             UploadError.postMessage(res);
            }
           var uploadPending = function(cb) {
             Console.postMessage("In pending");  
             cb();
           }
           
           Files.upload(file, false, Cryptpad, uploadProgress, uploadComplete, uploadError, uploadPending);
           Console.postMessage("End require");  
          } catch (e) {
          Console.postMessage("Exception"); 
          Console.postMessage(e); 
         }
        }); 
        Console.postMessage("run");
        """;
    return script;
  }

  void _uploadNextImage() {
    if (assetList.length > currentIndex) {
      // Make sure the drive is loaded
      driveData = null;
      var mydata = getImage(currentIndex);
      mydata.then((data) {
        currentIndex++;
        if (data != null) {
          silentUpload = false;
          _syncImage(data, false);
        } else {
          _showDialog("Information", "All images have been synced");
          logger.d("No more images available");
        }
      });
    } else {
      _showDialog("Information", "All images have been synced");
      logger.d("No more images available");
    }
  }

  void _syncImage(List data, bool silence) {
    var imageData = data[0];
    var filename = data[1];
    var remotePath = data[2];
    var b64 = data[3];
    logger.d("File path " + filename);

    if (remotePath == null || remotePath == "") {
      uploadStarted = true;
      currentFilename = filename;
      logger.d(imageData.length);

      String script = _getUploadScript(imageData, filename, b64);
      logger.d("Running script");
      logger.d(script);
      final future = flutterWebViewPlugin.evalJavascript(script);
      logger.d("script run. Waiting feedback");
      future.whenComplete(() {
        logger.d("script complete");
      });
      future.then((String result) {
        logger.d("script launched");
        logger.d(result);
      });
      future.catchError((Object result) {
        uploadStarted = false;
        logger.d("script error");
        if (!silence) _showDialog("Error", result);
      });
    } else {
      logger.d("File " + filename + " already replicated to " + remotePath);
      if (!silence) _showDialog("Image already replicated", remotePath);
    }
  }

  Future<bool> _readyForUpload(bool withStarted) async {
    // Check if flutter webview is loaded
    if (flutterWebViewPluginLoaded == false) {
      logger.d("WebView not loaded");
      _showDialog("Error", "WebView is not loaded.");
      return false;
    }

    // Check if we need to reload the web view
    if (reloadWebView) {
      reloadWebView = false;
      await restartFlutterWebviewPlugin();
    }

    // Check if we need to ask to force upload
    if (withStarted && uploadStarted) {
      ConfirmAction action = await _asyncConfirmDialog(
          "Upload already in progress",
          "Would you like to cancel it and launch a new upload ?");
      if (action == ConfirmAction.ACCEPT) {
        logger.d("Forcing upload");
        return true;
      } else {
        return false;
      }
    }

    logger.d("Ready for upload");
    return true;
  }

  Future<Null> _handleRefreshLocal() async {
    setState(() {
      requestPermission();
    });
    return null;
  }

  Future<Null> _handleRefreshRemote() async {
    setState(() {
      driveData = null;
    });
    await _getUserObject();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (currentView == "local")
      body = new RefreshIndicator(
          onRefresh: _handleRefreshLocal,
          child: new Stack(children: <Widget>[
            LogConsoleOnShake(dark: true, child: new Text("")),
            LinearProgressIndicator(
              value: uploadProgress / 100,
              backgroundColor: Color(0),
            ),
            StaggeredGridView.countBuilder(
              padding: const EdgeInsets.all(8.0),
              crossAxisCount: 3,
              itemCount: assetList.length,
              itemBuilder: (context, index) => FutureBuilder(
                future: _loadImageData(index),
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  return new Tooltip(
                      message:
                          (snapshot.data == null) ? "Image" : snapshot.data[2],
                      child: new GestureDetector(
                          onTap: () {
                            selectedImageindex = index;
                            Navigator.of(context).pushNamed('/photo');
                          },
                          child: new Stack(
                              alignment: Alignment.bottomRight,
                              children: <Widget>[
                                new Container(
                                  decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: (snapshot.data == null)
                                            ? new AssetImage(
                                                'assets/cryptpad-logo-white-50.png')
                                            : snapshot.data[0].image,
                                        fit: BoxFit.cover,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(10.0)),
                                ),
                                new Container(
                                    height: (snapshot.data != null &&
                                            snapshot.data[1] == true)
                                        ? 25
                                        : 0,
                                    width: (snapshot.data != null &&
                                            snapshot.data[1] == true)
                                        ? 25
                                        : 0,
                                    margin:
                                        EdgeInsets.only(bottom: 5, right: 5),
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: new AssetImage(
                                            'assets/cryptpad-logo-white-50.png'),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    alignment: Alignment.bottomRight)
                              ])));
                },
              ),
              staggeredTileBuilder: (index) =>
                  _staggeredTiles[index % _staggeredTiles.length],
              mainAxisSpacing: 8.0,
              crossAxisSpacing: 8.0,
            )
          ]));
    else
      body = new RefreshIndicator(
          onRefresh: _handleRefreshRemote,
          child: new StaggeredGridView.countBuilder(
            padding: const EdgeInsets.all(8.0),
            crossAxisCount: 3,
            itemCount: _getDriveImageNumber(),
            itemBuilder: (context, index) => FutureBuilder(
              future: _loadDriveImageData(index),
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                return new Tooltip(
                    message:
                        (snapshot.data == null) ? "Image" : snapshot.data[1],
                    child: new GestureDetector(
                        onTap: () {
                          print("Container clicked");
                          selectedImageindex = index;
                          Navigator.of(context).pushNamed('/photo');
                        },
                        child: new Container(
                          decoration: BoxDecoration(
                              image: DecorationImage(
                                image: (snapshot.data == null)
                                    ? new AssetImage(
                                        'assets/cryptpad-logo-50.png')
                                    : snapshot.data[0],
                                fit: BoxFit.cover,
                              ),
                              borderRadius: BorderRadius.circular(10.0)),
                        )));
              },
            ),
            staggeredTileBuilder: (index) =>
                _staggeredTiles[index % _staggeredTiles.length],
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
          ));

    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
            centerTitle: true,
            elevation: 0,
            leading: new Tooltip(
                message: "CryptPad View",
                child: new GestureDetector(
                    onTap: () {
                      if (!webViewVisible) {
                        flutterWebViewPlugin.show();
                        webViewVisible = true;
                      } else {
                        flutterWebViewPlugin.hide();
                        webViewVisible = false;
                      }
                    },
                    child: Image(
                        image: AssetImage('assets/cryptpad-logo-50.png')))),
            title: Text(""),
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: Colors.black),
            actions: <Widget>[
              new Tooltip(
                  message: "Settings",
                  child: FlatButton(
                    textColor: Colors.blue,
                    child: Icon(Icons.settings),
                    onPressed: () {
                      Navigator.of(context).pushNamed('/preferences');
                    },
                  )),
              /*
              new Tooltip(
                  message: "Login / CryptPad View",
                  child: FlatButton(
                    textColor: Colors.blue,
                    child: Icon(Icons.web),
                    onPressed: () {
                      if (!webViewVisible) {
                        flutterWebViewPlugin.show();
                        webViewVisible = true;
                      } else {
                        flutterWebViewPlugin.hide();
                        webViewVisible = false;
                      }
                    },
                  )),
               */
              new Tooltip(
                  message: "Force reconnect",
                  child: FlatButton(
                      textColor: Colors.blue,
                      child: Icon((driveData == null)
                          ? Icons.settings_remote
                          : Icons.refresh),
                      onPressed: () {
                        restartFlutterWebviewPlugin().then((str) {
                          logger.d("Finished reload");
                          setState(() {
                            driveData = null;
                            remoteImagesList = new List<String>();
                          });
                          waitForDriveData(10, 1).then((value) {
                            setState(() {
                              remoteImagesList = new List<String>();
                            });
                          });
                        });
                        requestPermission();
                      })),
              new Tooltip(
                  message: "Sync one image",
                  child: FlatButton(
                      textColor: Colors.blue,
                      child: Icon(Icons.content_copy),
                      onPressed: () {
                        uploadProgress = 0;
                        _readyForUpload(true).then((bool ready) {
                          if (ready) {
                            _uploadNextImage();
                          } else {
                            logger.d("Upload cancelled");
                          }
                        });
                      })),
              new Tooltip(
                  message: "Sync All",
                  child: FlatButton(
                      textColor: Colors.blue,
                      child: Icon(Icons.sync),
                      onPressed: () {
                        uploadProgress = 0;
                        _readyForUpload(true).then((bool ready) {
                          if (ready) {
                            syncImages(10, false);
                          } else {
                            logger.d("Upload cancelled");
                          }
                        });
                      })),
              new Tooltip(
                  message: "Switch View",
                  child: FlatButton(
                    textColor: Colors.blue,
                    child: Icon(Icons.image),
                    onPressed: () {
                      setState(() {
                        if (currentView == "local")
                          currentView = "cryptpad";
                        else
                          currentView = "local";
                      });
                    },
                  )),
            ]),
        body: body);
  }
}
