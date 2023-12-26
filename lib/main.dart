import 'dart:io';

import 'package:date_format/date_format.dart';
import 'package:diyode_tracker/point_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:influxdb_client/api.dart';
import 'package:latlong2/latlong.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import 'map_manager.dart';
import 'secrets.dart';

void main() async {
  runApp(const MyApp());
  ByteData data =
      await PlatformAssetBundle().load('assets/ca/lets-encrypt-r3.pem');
  SecurityContext.defaultContext
      .setTrustedCertificatesBytes(data.buffer.asUint8List());

  //client.close();
}

List<Marker> _markers = [];
MapController mapController = MapController();
late MarkerLayer markerLayer;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    markerLayer = MarkerLayer(markers: []);
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.limeAccent),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'DIYODE'),
    );
  }
}

FlutterMap getMap() {
  return (FlutterMap(
    mapController: mapController,
    options: MapOptions(
        initialCenter: LatLng(52.0082, 4.36797),
        maxZoom: 20,
        minZoom: 2,
        interactionOptions: InteractionOptions(rotationThreshold: 50)),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.app',
      ),
      markerLayer
    ],
  ));
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

const List<String> list = <String>[
  'Latest',
  '1 Hour',
  '2 Hours',
  '5 Hours',
  '10 Hours',
  '1 Day',
  '2 Days',
  '3 Days',
  '1 Week'
];

const List<int> hourReqs = <int>[0, 1, 2, 5, 10, 24, 48, 72, 168];

class _MyHomePageState extends State<MyHomePage> {
  late FlutterMap mapInst;
  int _counter = 0;

  int reqHours = 1;

  double mapWidth = 0;
  double mapHeight = 0;

  var trackerTitle = "Loading...";
  var lastSeenText = "Loading...";
  var batteryText = "...%";
  var pointsFoundText = "? points/day";

  num lat = 0;
  num lon = 0;

  var addressInfo = "";
  var altitude = "?m";

  var batteryIcon = Icons.battery_unknown;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  Future<List<Marker>> getMarkers() async {
    var client = InfluxDBClient(
        // IMPORTANT: You will need to fill these out in secrets.dart
        url: secret_url,
        token: secret_influxAPIkey,
        org: 'diyode',
        bucket: 'tracker',
        debug: true);

    //var healthCheck = await client.getHealthApi().getHealth();
    //print(
    //    'Health check: ${healthCheck.name}/${healthCheck.version} - ${healthCheck.message}');

    var queryService = client.getQueryService();

    var tm = TrackerManager(queryService);
    var trackers = await tm.addTrackers();
    print("Found Trackers: ${trackers.length}");
    //print("Trackers Found: ${trackers.length}");
    for (var tr in trackers) {
      await tr.populatePoints(queryService, reqHours, tr.trackerName);
      //tr.populatePoints(service, lastHours, trackerName)
      for (var point in tr.trackerPoints) {
        _markers.add(Marker(
            //alignment: Alignment.center,
            point: LatLng(point.lat as double, point.lon as double),
            width: 80,
            height: 80,
            child: GestureDetector(
              child: Text(
                point.emoji,
                textAlign: TextAlign.center,
                textScaleFactor: 2,
              ),
              onTap: () {
                updateTrackerInfo(point.owningTracker);
                print("${point.owningTracker.trackerName} was tapped!");
                setState(() {});
              },
            )));
        //print("Added point @ ${point.lat}, ${point.lon}");
      }
    }
    markerLayer = MarkerLayer(markers: _markers);
    updateTrackerInfo(trackers[0]);
    return _markers;
  }

  void CompletedMarkerFetch() {
    setState(() {});
    print("Setting markers...");
  }

  void updateTrackerInfo(Tracker tracker) {
    TrackerPoint lastPoint = tracker.trackerPoints.last;
    trackerTitle = "${lastPoint.emoji}  ${tracker.displayName}";
    batteryText = "${lastPoint.battery}%";
    altitude = "${lastPoint.alt}m";
    addressInfo = lastPoint.address;
    pointsFoundText = "${tracker.pointsRecorded} points";
    lat = lastPoint.lat;
    lon = lastPoint.lon;

    var date =
        DateTime.fromMillisecondsSinceEpoch(lastPoint.time.toInt() * 1000);
    var now = DateTime.now();
    var format = [HH, ':', nn];
    var diff = now.difference(date);
    //Add date info if it was from a different day or more than 24 hours ago.
    if (now.day != date.day || diff.inHours >= 24) {
      format = [HH, ':', nn, ' ', d, '/', m];
    }

    var formatted = formatDate(date, format);

    lastSeenText = "Last Seen: $formatted";

    switch (lastPoint.battery) {
      case <= 0:
        batteryIcon = Icons.battery_0_bar;
        break;
      case < 15:
        batteryIcon = Icons.battery_1_bar;
        break;
      case < 30:
        batteryIcon = Icons.battery_2_bar;
        break;
      case < 45:
        batteryIcon = Icons.battery_3_bar;
        break;
      case < 60:
        batteryIcon = Icons.battery_4_bar;
        break;
      case < 75:
        batteryIcon = Icons.battery_5_bar;
        break;
      case < 90:
        batteryIcon = Icons.battery_6_bar;
      case >= 90:
        batteryIcon = Icons.battery_full;
        break;
      case double() || int():
        // TODO: Handle this case.
        batteryIcon = Icons.battery_unknown;
    }
  }

  @override
  void initState() {
    super.initState();
    getMarkers().whenComplete(() => CompletedMarkerFetch());
  }

  String dropdownValue = list.first;

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.bebasNeue(),
              textScaleFactor: 2,
            ),
            DropdownButton<String>(
              value: dropdownValue,
              icon: const Icon(Icons.keyboard_arrow_down_sharp),
              elevation: 16,
              onChanged: (String? value) {
                // This is called when the user selects an item.
                setState(() {
                  dropdownValue = value!;

                  reqHours = hourReqs[list.indexOf(dropdownValue)];
                  _markers.clear();
                  getMarkers().whenComplete(() => CompletedMarkerFetch());
                });
              },
              items: list.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            )
          ],
        ),

        /*flexibleSpace: Container(
            //color: Colors.orange,
            child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Two'),
            Text('Three'),
            Text('Four'),
          ],
        ))*/ // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Colors.limeAccent,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
      ),
      body: SlidingUpPanel(
        color: Theme.of(context).colorScheme.inversePrimary,
        parallaxEnabled: true,
        parallaxOffset: 0.5,
        maxHeight: 500,
        minHeight: 115,
        panel: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: Container(
                    color: Colors.limeAccent,
                    child: Padding(
                        padding: EdgeInsets.all(10.0),
                        child: Text(trackerTitle,
                            textScaleFactor: 2,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.merriweatherSans()))))
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(batteryIcon, color: Colors.black, size: 35.0),
            Text(batteryText,
                textScaleFactor: 1.25,
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 50),
            Text(
              lastSeenText,
              textScaleFactor: 1.25,
            ),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.arrow_upward),
            const SizedBox(width: 5),
            Text(
              altitude,
              textScaleFactor: 1.25,
            ),
            const SizedBox(width: 50),
            ElevatedButton(
              child: Icon(Icons.map),
              style: ElevatedButton.styleFrom(
                primary: Theme.of(context).secondaryHeaderColor,
                elevation: 0,
              ),
              onPressed: () {
                attemptLaunchGoogleMaps();
              },
            ),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.location_on, color: Colors.black, size: 35.0),
            const SizedBox(width: 10),
            Flexible(
                child: Text(addressInfo,
                    textScaleFactor: 1.25,
                    style: const TextStyle(fontWeight: FontWeight.bold)))
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.remove_red_eye, color: Colors.black, size: 35.0),
            const SizedBox(width: 10),
            Flexible(
                child: Text(
              pointsFoundText,
              textScaleFactor: 1.25,
            ))
            //style: const TextStyle(fontWeight: FontWeight.bold)))
          ]),
        ]),
        body: Center(
            // Center is a layout widget. It takes a single child and positions it
            // in the middle of the parent.
            child: (mapInst = getMap())),
      ),

      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void attemptLaunchGoogleMaps() {
    MapUtils.openMap(lat.toDouble(), lon.toDouble(), trackerTitle);
  }
}
