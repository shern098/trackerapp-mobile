import 'package:flutter/material.dart';

class BusStopMarker extends StatelessWidget {
  final String stopName;
  final VoidCallback onTap;

  const BusStopMarker({
    super.key,
    required this.stopName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(
        'assets/images/bus-stop.png',
      ),
    );
  }
}