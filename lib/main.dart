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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PhotosApp());
}

const kAndroidUserAgent =
    'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.94 Mobile Safari/537.36';

// String selectedUrl = 'http://cryptpad.local:5000/';
String selectedUrl = 'https://cryptpad.fr/';

// ignore: prefer_collection_literals
final Set<JavascriptChannel> jsChannels = [
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
        '/widget': (_) {
          return WebviewScaffold(
            url: selectedUrl,
            javascriptChannels: jsChannels,
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
  String _output = "";

  List<AssetPathEntity> imagesList = [];
  List<AssetEntity> assetList = [];
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

  @override
  void initState() {
    requestPermission();
    super.initState();

    flutterWebViewPlugin.onStateChanged.listen((viewState) async {
      if (viewState.type == WebViewState.finishLoad) {
        flutterWebViewPluginLoaded = true;
        print("WebView loaded");
      }
    });

    // ignore: prefer_collection_literals
    Set<JavascriptChannel> jsChannels = [
      JavascriptChannel(
          name: 'Print',
          onMessageReceived: (JavascriptMessage message) {
            print("JAVASCRIPT MESSAGE: " + message.message);
            if (message.message.startsWith("/file/")) {
              // Persist the remote path on the CryptPad server
              print("Persisting output for " + currentFilename);
              saveString(selectedUrl, currentFilename, message.message);
              _showDialog("Image replicated", message.message);
              currentIndex++;
            }
          }),
    ].toSet();

    print("WebView launch");
    flutterWebViewPlugin.launch(selectedUrl + "drive/",
        javascriptChannels: jsChannels, hidden: true);

    _onHttpError =
        flutterWebViewPlugin.onHttpError.listen((WebViewHttpError error) {
      print(error.toString());
      // _showDialog("Error", error.toString());
    });
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

  Future<Image> _loadImage(index) async {
    AssetEntity entity = assetList[index % assetList.length];
    return Image.file(await entity.file);
  }

  Future getImage(index) async {
    AssetEntity entity = assetList[index];
    File file = await entity.file;
    String filename = p.basename(file.path);
    String currentRemotePage = await getString(selectedUrl, filename);
    String b64 = base64.encode(await entity.thumbDataWithSize(100, 100, format: ThumbFormat.png));
    return [await entity.fullData, filename, currentRemotePage, b64];
  }

  // 1
  String _generateKey(String server, String key) {
    return '$server/$key';
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

  @override
  Widget build(BuildContext context) {
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
                    requestPermission();
                  }),
              /*
              FlatButton(
                  textColor: Colors.blue,
                  child: Text("SyncText"),
                  onPressed: () {
                    if (flutterWebViewPluginLoaded == false) {
                      print("WebView not loaded");
                      return;
                    }

                    print("Running script");
                    String script = """
                    Print.postMessage("script start");
                    var text = "Hello\\n";
                    var result = "";
                    require(['/common/outer/upload.js'], function (Files) {
                    try {
                      Print.postMessage("begin require");
                         Print.postMessage("begin require");
                       var cb1 = function(res) {
                         Print.postMessage("In feedback1");
                         Print.postMessage(res);
                       }
                       var cb2 = function(res) {
                         Print.postMessage("In feedback2");
                         Print.postMessage(res);
                       }
                       var cb3 = function(res) {
                         Print.postMessage("In feedback3");
                         Print.postMessage(res);
                       }
                       var cb4 = function(res) {
                         Print.postMessage("In feedback4");
                         Print.postMessage(res);
                       }
                       var u8 = new TextEncoder().encode(text);
                       var metadata = {name: "filename6.txt", type: "text/plain", owners: ["a6qidzms8mmC3QfMEK2Q+VNDDzn2hxSnRfNRj90RPaA="]}
                       var file = { blob: u8, metadata : metadata, forceSave : true, owned : true, path: [], uid: CryptPad_Util.uid()}
                       Files.upload(file, false, Cryptpad, cb1, cb2, cb3, cb4);
                       Print.postMessage("End require");
                    } catch (e) {
                    Print.postMessage("Exception");
                    Print.postMessage(e);
                    }
                    });
                    Print.postMessage("run");
                    """;

                    final future = flutterWebViewPlugin.evalJavascript(script);
                    print("script run. Waiting feedback");

                    var duration = new Duration(seconds: 10);
                    final future2 = future.timeout(duration);
                    future2.then((String result) {
                      print("Timeout");
                    });
                    future.whenComplete(() {
                      print("script complete");
                      // _showDialog("Message", "complete");
                    });
                    future.then((String result) {
                      print("After eval");
                      print(result);
                      // _showDialog("Message", result);
                    });
                    future.catchError((Object result) {
                      print("script error");
                      _showDialog("Error", result);
                    });
                  }),
              FlatButton(
                  textColor: Colors.blue,
                  child: Text("SyncTestImage"),
                  onPressed: () {
                    if (flutterWebViewPluginLoaded == false) {
                      print("WebView not loaded");
                      return;
                    }

                    if (assetList.length > currentIndex) {
                      print("IMAGE get");
                      var mydata = getImage(currentIndex);
                      mydata.then((result) {
                        print("Length: ");
                        print(result.length);
                        print("Running script");
                        String script = """
                    Print.postMessage("script start");
                    var u8 = new Uint8Array( ['137','80','78','71','13','10','26','10','0','0','0','13','73','72','68','82','0','0','0','1','0','0','0','1','1','3','0','0','0','37','219','86','202','0','0','0','3','80','76','84','69','0','0','0','167','122','61','218','0','0','0','1','116','82','78','83','0','64','230','216','102','0','0','0','10','73','68','65','84','8','215','99','96','0','0','0','2','0','1','226','33','188','51','0','0','0','0','73','69','78','68','174','66','96','130']);
                    var metadata = {name: "pixel1.png", type: "image/png", owners: ["a6qidzms8mmC3QfMEK2Q+VNDDzn2hxSnRfNRj90RPaA="]}
                    var file = { blob: u8, metadata : metadata, forceSave : true, owned : true, path: [], uid: CryptPad_Util.uid()}

                    var result = "";
                    require(['/common/outer/upload.js'], function (Files) {
                      try {
                       Print.postMessage("begin require");
                       var cb1 = function(res) {
                         Print.postMessage("In feedback1");
                         Print.postMessage(res);
                       }
                       var cb2 = function(res) {
                         Print.postMessage("In feedback2");
                         Print.postMessage(res);
                       }
                       var cb3 = function(res) {
                         Print.postMessage("In feedback3");
                         Print.postMessage(res);
                       }
                       var cb4 = function(res) {
                         Print.postMessage("In feedback4");
                         Print.postMessage(res);
                       }

                       Files.upload(file, false, Cryptpad, cb1, cb2, cb3, cb4);
                       Print.postMessage("End require");
                      } catch (e) {
                      Print.postMessage("Exception");
                      Print.postMessage(e);
                     }
                    });
                    Print.postMessage("run");
                    """;

                        final future =
                            flutterWebViewPlugin.evalJavascript(script);
                        print("script run. Waiting feedback");

                        future.whenComplete(() {
                          print("script complete");
                          // _showDialog("Message", "complete");
                        });
                        future.then((String result) {
                          print("After eval");
                          print(result);
                          // _showDialog("Message", result);
                        });
                        future.catchError((Object result) {
                          print("script error");
                          _showDialog("Error", result);
                        });
                      });
                    }
                  }),
               */
              FlatButton(
                  textColor: Colors.blue,
                  child: Text("Sync"),
                  onPressed: () {
                    if (flutterWebViewPluginLoaded == false) {
                      print("WebView not loaded");
                      return;
                    }

                    if (assetList.length > currentIndex) {
                      print("IMAGE get");
                      var mydata = getImage(currentIndex);
                      mydata.then((data) {
                        var result = data[0];
                        var filename = data[1];
                        var remotePath = data[2];
                        var b64 = data[3];
                        print("File path " + filename);

                        if (remotePath == null || remotePath == "") {
                          currentFilename = filename;
                          print(result.length);
                          StringBuffer str = new StringBuffer();
                          var it = result.iterator;
                          while (it.moveNext()) {
                            var char = it.current;
                            str.write("'");
                            str.write(it.current);
                            str.write("',");
                          }
                          print("Running script");


                          String script = """
                    var filename = '""" +
                              filename +
                              """';
                    Print.postMessage("script start"); 
                    var u8 = new Uint8Array( [""" +
                              str.toString() +
                              """]);
                    var metadata = {name: filename, type: "image/jpeg", thumbnail: "data:image/jpeg;base64,""" + b64 + """", owners: []}
                    var file = { blob: u8, metadata : metadata, forceSave : true, owned : true, path: ["root"], uid: CryptPad_Util.uid()}
                    
                    var result = "";
                    require(['/common/outer/upload.js'], function (Files) {
                      try {
                       Print.postMessage("begin require");  
                       var cb1 = function(res) {
                         Print.postMessage("In feedback1");  
                         Print.postMessage(res);
                       }
                       var cb2 = function(res) {
                         Print.postMessage("In feedback2");  
                         Print.postMessage(res);
                       }
                       var cb3 = function(res) {
                         Print.postMessage("In feedback3");  
                         Print.postMessage(res);
                       }
                       var cb4 = function(res) {
                         Print.postMessage("In feedback4");  
                         Print.postMessage(res);
                       }
                       
                       Files.upload(file, false, Cryptpad, cb1, cb2, cb3, cb4);
                       Print.postMessage("End require");  
                      } catch (e) {
                      Print.postMessage("Exception"); 
                      Print.postMessage(e); 
                     }
                    }); 
                    Print.postMessage("run");
                    """;

                          print(script);
                          final future =
                              flutterWebViewPlugin.evalJavascript(script);
                          print("script run. Waiting feedback");

                          future.whenComplete(() {
                            print("script complete");
                            // _showDialog("Message", "complete");
                          });
                          future.then((String result) {
                            print("After eval");
                            print(result);
                            // _showDialog("Message", result);
                          });
                          future.catchError((Object result) {
                            print("script error");
                            _showDialog("Error", result);
                          });
                        } else {
                          print("File " +
                              filename +
                              " already replicated to " +
                              remotePath);
                          _showDialog("Image already replicated", remotePath);
                          currentIndex++;
                        }
                      });
                    } else {
                      print("No more images available");
                    }
                  })
            ]),
        body: StaggeredGridView.countBuilder(
          padding: const EdgeInsets.all(8.0),
          crossAxisCount: 3,
          itemCount: assetList.length,
          itemBuilder: (context, index) => FutureBuilder(
            future: _loadImage(index),
            builder: (BuildContext context, AsyncSnapshot<Image> image) {
              return Container(
                decoration: BoxDecoration(
                    image: DecorationImage(
                      image: image.data.image,
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(10.0)),
              );
            },
          ),
          staggeredTileBuilder: (index) => _staggeredTiles[index],
          mainAxisSpacing: 8.0,
          crossAxisSpacing: 8.0,
        ));
  }
}
