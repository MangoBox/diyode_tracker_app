import 'dart:math';

import 'package:influxdb_client/api.dart';

class TrackerManager {
  //The query service for InfluxDB.
  late QueryService queryService;

  var trackers = <Tracker>[];

  //Update soon to be dynamic.
  int lastHoursFetched = 12;

  TrackerManager(this.queryService);

  Future<List<Tracker>> addTrackers() async {
    var fluxQuery = '''
    import "influxdata/influxdb/schema"
    schema.measurements(bucket: "tracker")
    ''';
    print("Querying Trackers...");
    var trackerList = await queryService.query(fluxQuery);
    print("Finished querying Trackers.");
    await trackerList.forEach((tracker) async {
      var tr = Tracker(tracker['_value'] as String);
      print("Found Tracker: ${tracker['_value']}");
      trackers.add(tr);
    });
    return trackers;
  }

  Tracker getTrackerByPoint(TrackerPoint point) {
    return point.owningTracker;
  }
}

class Tracker {
  var trackerPoints = <TrackerPoint>[];
  String trackerName = "";
  String displayName = "";
  int pointsRecorded = 0;

  Tracker(this.trackerName);

  void addNewTrackerPoint(var point) {
    trackerPoints.add(point);
  }

  TrackerPoint getLastPoint() {
    return trackerPoints.last;
  }

  void safeSetTrackerPoint(var index, var value) {
    try {
      trackerPoints[index] = value;
    } catch (e) {
      var curLength = trackerPoints.length;
      trackerPoints.length = max(curLength, index + 1);
      trackerPoints[index] = value;
    }
  }

  Future<void> populatePoints(
      QueryService service, int lastHours, String trackerName) async {
    //Chill until we fetch our tracker name.
    //await Future.doWhile(() => trackerName == "");
    var fluxQuery = '''
      from(bucket: "tracker")
      |> range(start: -${lastHours}h)
      |> filter(fn: (r) => r["_measurement"] == "$trackerName")
      |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")''';

    //If we're on 'recent only' mode.
    if (lastHours == 0) {
      fluxQuery = '''
      from(bucket: "tracker")
      |> range(start: -1000h)
      |> filter(fn: (r) => r["_measurement"] == "$trackerName")
      |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
      |> last(column: "_time")''';
    }

    var foundPoints = await service.query(fluxQuery);
    int numPoints = 0;

    TrackerPoint last = TrackerPoint();
    await foundPoints.forEach((record) {
      TrackerPoint tp = TrackerPoint();
      tp.time = record["last_seen"];
      tp.address = record["address"];
      tp.lat = record["lat"];
      tp.lon = record["lon"];
      tp.alt = record["altitude"];
      tp.battery = record["battery"];
      tp.emoji = record["emoji"] ?? "🔴";
      tp.owningTracker = this;
      displayName = record["name"];
      trackerPoints.add(tp);
      numPoints++;
    });
    pointsRecorded = numPoints;
    print(trackerPoints);
    trackerPoints.forEach((point) {
      print(
          "Tracker ${trackerName}: Address: ${point.address} (Lat: ${point.lat}, Lon: ${point.lon}), ${point.battery}% Battery, Time: ${point.time}");
    });
    print(fluxQuery);
  }
}

class TrackerPoint {
  num lat = double.nan;
  num lon = double.nan;
  num alt = double.nan;
  num battery = double.nan;

  String address = "";
  String emoji = "";
  num time = 0;
  Tracker owningTracker = Tracker("");

  //TrackerPoint(this.lat, this.lon, this.fullAddress, this.time);
  TrackerPoint();

  bool isEmpty() {
    return lat.isNaN && lon.isNaN;
  }
}
