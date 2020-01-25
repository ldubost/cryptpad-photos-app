import 'dart:ui';

import 'package:cryptpad_photos_app/cryptpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'dart:async';
import 'dart:io';
import 'dart:convert';

enum ConfirmAction { CANCEL, ACCEPT }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PhotosApp());
}

const kAndroidUserAgent =
    'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Mobile Safari/537.36';

String selectedUrl = 'http://cryptpad.local:5000/';
// String selectedUrl = 'https://cryptpad.fr/';

// ignore: prefer_collection_literals
final Set<JavascriptChannel> jsChannels1 = [
  JavascriptChannel(
      name: 'Print1',
      onMessageReceived: (JavascriptMessage message) {
        print("JSMESSAGE MAIN");
        print(message.message);
      }),
].toSet();

class PhotosApp extends StatelessWidget {
  // WebView to manage the relationship with CryptPad.
  final flutterWebViewPlugin = FlutterWebviewPlugin();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photos',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'CryptPad Photos'),
      routes: {
        '/remote': (_) {},
        '/widget': (_) {
          return WebviewScaffold(
            url: selectedUrl,
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
                      flutterWebViewPlugin.goBack();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: () {
                      flutterWebViewPlugin.goForward();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.autorenew),
                    onPressed: () {
                      flutterWebViewPlugin.reload();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String currentView = "local";
  List<AssetPathEntity> imagesList = [];
  List<AssetEntity> assetList = [];
  Map<String, dynamic> remoteImagesListMap = new Map<String, dynamic>();
  List<String> remoteImagesList = new List<String>();

  String currentFilename = "";
  int currentIndex = 0;

  bool flutterWebViewPluginLoaded = false;
  final flutterWebViewPlugin = FlutterWebviewPlugin();
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
  bool reloadWebView = false;
  Map<String, dynamic> driveData;
  Map<String, dynamic> uploadStatus;
  double uploadProgress = 0;
  Set<JavascriptChannel> jsChannels;

  @override
  void initState() {
    requestPermission();
    super.initState();

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
        print("WebView loaded");
      }
    });
    jsChannels = [
      JavascriptChannel(
          name: 'UploadComplete',
          onMessageReceived: (JavascriptMessage message) {
            print("JAVASCRIPT MESSAGE: " + message.message);
            if (message.message.startsWith("/file/")) {
              // Persist the remote path on the CryptPad server
              print("Persisting output for " + currentFilename);
              saveString(selectedUrl, currentFilename, message.message);
              uploadStarted = false;
              uploadProgress = 0;
              _showDialog("Image replicated", message.message);
              currentIndex++;
              requestPermission();
            }
          }),
      JavascriptChannel(
          name: 'CryptPadReady',
          onMessageReceived: (JavascriptMessage message) {
            flutterWebViewPluginLoaded = true;
            // load the drive data
            _getUserObject();
            print("JAVASCRIPT CryptPadReady");
          }),
      JavascriptChannel(
          name: 'Console',
          onMessageReceived: (JavascriptMessage message) {
            print("JAVASCRIPT Console: " + message.message);
          }),
      JavascriptChannel(
          name: 'Alert',
          onMessageReceived: (JavascriptMessage message) {
            print("JAVASCRIPT Alert: " + message.message);
            _showDialog("Alert", message.message);
          }),
      JavascriptChannel(
          name: 'Drive',
          onMessageReceived: (JavascriptMessage message) {
            print("JAVASCRIPT Drive data: " + message.message);
            driveData = jsonDecode(message.message);
          }),
      JavascriptChannel(
          name: 'UploadProgress',
          onMessageReceived: (JavascriptMessage message) {
            print("JAVASCRIPT Upload progress: " + message.message);
            uploadProgress = double.parse(message.message);
          }),
      JavascriptChannel(
          name: 'UploadStatus',
          onMessageReceived: (JavascriptMessage message) {
            print("JAVASCRIPT Upload status: " + message.message);
            uploadStatus = jsonDecode(message.message);
          }),
      JavascriptChannel(
          name: 'UploadError',
          onMessageReceived: (JavascriptMessage message) {
            print("JAVASCRIPT Upload error: " + message.message);
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
            print("JAVASCRIPT GetMetadata: " + message.message);
            var data = jsonDecode(message.message);
            print("HREF: " + data.href);
          }),


    ].toSet();

    _loadWebView();

    _onHttpError =
        flutterWebViewPlugin.onHttpError.listen((WebViewHttpError error) {
      print(error.toString());
      // _showDialog("Error", error.toString());
    });
  }

  Future<Null> _reloadWebView() async {
    Future<Null> future = await flutterWebViewPlugin.close();
    _loadWebView();
    return future;
  }

  void _loadWebView() {
    print("WebView launch");
    flutterWebViewPlugin.launch(selectedUrl + "drive/",
        javascriptChannels: jsChannels,
        hidden: true,
        rect: new Rect.fromLTWH(
          0.0,
          0.0,
          200.0,
          500.0,
        ));
  }

  void requestPermission() async {
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
      /// if result is fail, you can call `PhotoManager.openSetting();`  to open android/ios applicaton's setting to get permission
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
    String currentRemotePage =
        (filename == null) ? "" : await getString(selectedUrl, filename);
    bool isReplicated = (currentRemotePage != null);
    print("Image: " +
        filename +
        " remote: " +
        currentRemotePage.toString() +
        " isReplicated: " +
        isReplicated.toString());
    return [Image.file(await entity.file), isReplicated];
  }

  Future<List> getImage(index) async {
    AssetEntity entity = assetList[index];
    File file = await entity.file;
    String filename = p.basename(file.path);
    // Check if we have not already pushed this image to cryptpad
    String currentRemotePage = await getString(selectedUrl, filename);
    if (currentRemotePage != null && index < assetList.length) {
      currentIndex++;
      return getImage(index + 1);
    }

    // Check if we find this image in the drive data
    var remoteImageData = await _getRemoteImageData(filename, false);
    if (remoteImageData != null) {
      print("Image already in drive");
      currentIndex++;
      return getImage(index + 1);
    }

    // Retrieve base64 thumbnail
    String b64 = base64.encode(
        await entity.thumbDataWithSize(100, 100, format: ThumbFormat.png));
    return [await entity.fullData, filename, currentRemotePage, b64];
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

    for (var i = 0; i < 5; i++) {
      if (driveData != null)
        return driveData;
      else
        await Future.delayed(new Duration(seconds: 1));
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
        print("Found remote value: " + value.toString());
        // store this locally
        var href = value["href"];
        saveString(selectedUrl, filename, href);
        return value;
      }
    }
    print("Did not find remote value");
    return null;
  }

  Future<String> _loadDriveImageData(index) async {
    var href = remoteImagesList[index];
    var file = remoteImagesListMap[href];

    var script = """
     var href = '""" + href + """';
     require(['/file/file-crypto.js'], function (FileCrypto) {
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


    return "";
  }

  /*
   CryptPad functions get number of images
   */
  int _getDriveImageNumber() {
    try {
      if (driveData == null) {
        print("Drive not loaded");
        return 0;
      }
      int nb = 0;
      Map filesData = driveData["drive"]["filesData"];
      for (var key in filesData.keys) {
        var file = filesData[key];
        var fileType = file["fileType"];
        if (fileType!=null && fileType.startsWith("image/")) {
          var href = file["href"];
          remoteImagesList.add(href);
          remoteImagesListMap[href] = file;
          nb++;
        }
      }
      print("Found " + nb.toString() + " images");
      return nb;
    } catch (e) {
      print("Exception counting images");
      print(e);
      return 0;
    }
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
        var metadata = {name: filename, type: "image/jpeg", thumbnail: "data:image/jpeg;base64,""" +
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
           var uploadPending = function(res) {
             Console.postMessage("In complete");  
             Console.postMessage(res);
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
    uploadStarted = true;

    if (assetList.length > currentIndex) {
      // Make sure the drive is loaded
      driveData = null;
      var mydata = getImage(currentIndex);
      mydata.then((data) {
        var imageData = data[0];
        var filename = data[1];
        var remotePath = data[2];
        var b64 = data[3];
        print("File path " + filename);

        if (remotePath == null || remotePath == "") {
          currentFilename = filename;
          print(imageData.length);

          String script = _getUploadScript(imageData, filename, b64);
          print("Running script");
          print(script);
          final future = flutterWebViewPlugin.evalJavascript(script);
          print("script run. Waiting feedback");
          future.whenComplete(() {
            print("script complete");
          });
          future.then((String result) {
            print("script launched");
            print(result);
          });
          future.catchError((Object result) {
            uploadStarted = false;
            print("script error");
            _showDialog("Error", result);
          });
        } else {
          print("File " + filename + " already replicated to " + remotePath);
          _showDialog("Image already replicated", remotePath);
          uploadStarted = false;
          currentIndex++;
        }
      });
    } else {
      uploadStarted = false;
      print("No more images available");
    }
  }

  Future<bool> _readyForUpload(bool withStarted) async {
    // Check if flutter webview is loaded
    if (flutterWebViewPluginLoaded == false) {
      print("WebView not loaded");
      _showDialog("Error", "WebView is not loaded.");
      return false;
    }

    // Check if we need to reload the web view
    if (reloadWebView) {
      await _reloadWebView();
    }

    // Check if we need to ask to force upload
    if (withStarted && uploadStarted) {
      ConfirmAction action = await _asyncConfirmDialog(
          "Upload already in progress",
          "Would you like to cancel it and launch a new upload ?");
      if (action == ConfirmAction.ACCEPT) {
        print("Forcing upload");
        return true;
      } else {
        return false;
      }
    }

    print("Ready for upload");
    return true;
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (currentView == "local")
      body = new Stack(children: <Widget>[
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
              return new Stack(
                  alignment: Alignment.bottomRight,
                  children: <Widget>[
                    new Container(
                      decoration: BoxDecoration(
                          image: DecorationImage(
                            image: snapshot.data[0].image,
                            fit: BoxFit.cover,
                          ),
                          borderRadius: BorderRadius.circular(10.0)),
                    ),
                    new Container(
                        height: (snapshot.data[1] == true) ? 25 : 0,
                        width: (snapshot.data[1] == true) ? 25 : 0,
                        margin: EdgeInsets.only(bottom: 5, right: 5),
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: new AssetImage(
                                'assets/cryptpad-logo-white-50.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        alignment: Alignment.bottomRight)
                  ]);
            },
          ),
          staggeredTileBuilder: (index) => _staggeredTiles[index % _staggeredTiles.length],
          mainAxisSpacing: 8.0,
          crossAxisSpacing: 8.0,
        )
      ]);
    else
      body = new StaggeredGridView.countBuilder(
        padding: const EdgeInsets.all(8.0),
        crossAxisCount: 3,
        itemCount: _getDriveImageNumber(),
        itemBuilder: (context, index) => FutureBuilder(
          future: _loadDriveImageData(index),
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            return new Container(
              decoration: BoxDecoration(
                  image: DecorationImage(
                    image: new AssetImage('assets/cryptpad-logo-50.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(10.0)),
            );
          },
        ),
        staggeredTileBuilder: (index) => _staggeredTiles[index % _staggeredTiles.length],
        mainAxisSpacing: 8.0,
        crossAxisSpacing: 8.0,
      );

    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
            centerTitle: true,
            elevation: 0,
            title: Text(
              'Photos',
              style: TextStyle(color: Colors.black),
            ),
            backgroundColor: Colors.transparent,
            iconTheme: IconThemeData(color: Colors.black),
            actions: <Widget>[
              FlatButton(
                textColor: Colors.blue,
                child: Text("CryptPad"),
                onPressed: () {
                  Navigator.of(context).pushNamed('/widget');
                },
              ),
              FlatButton(
                  textColor: Colors.blue,
                  child: Text("Refresh"),
                  onPressed: () {
                    flutterWebViewPluginLoaded = false;
                    _reloadWebView();
                    requestPermission();
                  }),
              FlatButton(
                  textColor: Colors.blue,
                  child: Text("Sync"),
                  onPressed: () {
                    uploadProgress = 0;
                    _readyForUpload(true).then((bool ready) {
                      if (ready) {
                        _uploadNextImage();
                      } else {
                        print("Upload cancelled");
                      }
                    });
                  }),
              FlatButton(
                textColor: Colors.blue,
                child: Text("Switch"),
                onPressed: () {
                  setState(() {
                    if (currentView == "local")
                      currentView = "cryptpad";
                    else
                      currentView = "local";
                  });
                },
              ),
            ]),
        body: body);
  }
}
