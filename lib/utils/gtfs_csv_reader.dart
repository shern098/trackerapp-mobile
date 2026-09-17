import 'dart:convert';
// import 'dart:io'; // use this and comment package line below when move to mobile
import 'package:flutter/services.dart';

class GtfsCsvReader {
  static Future<List<Map<String, String>>> read(
      String filePath,
      ) async {
    final content =
    await rootBundle.loadString(filePath);

    final lines =
    const LineSplitter().convert(content);

    if (lines.isEmpty) {
      return [];
    }

    final headers = _parseLine(lines.first);

    final rows =
    <Map<String, String>>[];

    for (int i = 1; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) {
        continue;
      }

      final values =
      _parseLine(lines[i]);

      final row =
      <String, String>{};

      for (int j = 0;
      j < headers.length;
      j++) {
        row[headers[j]] =
        j < values.length
            ? values[j]
            : '';
      }

      rows.add(row);
    }

    return rows;
  }

  // for mobile read from file
  // static Future<List<Map<String, String>>> read(
  //     String filePath,
  //     ) async {
  //   final file = File(filePath);
  //
  //   final content = await file.readAsString();
  //   final lines = const LineSplitter().convert(content);
  //
  //   if (lines.isEmpty) {
  //     return [];
  //   }
  //
  //   final headers = _parseLine(lines.first);
  //   final List<Map<String, String>> rows = [];
  //
  //   for (int i = 1; i < lines.length; i++) {
  //     if (lines[i].trim().isEmpty) {
  //       continue;
  //     }
  //
  //     final values = _parseLine(lines[i]);
  //
  //     final row = <String, String>{};
  //
  //     for (int j = 0; j < headers.length; j++) {
  //       row[headers[j]] =
  //       j < values.length ? values[j] : '';
  //     }
  //
  //     rows.add(row);
  //   }
  //
  //   return rows;
  // }

  static List<String> _parseLine(String line) {
    // basic CSV parser.
    // GTFS files can contain commas inside quoted values,
    // don't simply use line.split(',').

    final result = <String>[];
    final buffer = StringBuffer();

    bool insideQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        insideQuotes = !insideQuotes;
      } else if (char == ',' && !insideQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }

    result.add(buffer.toString());

    return result;
  }
}