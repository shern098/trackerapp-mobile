import 'package:flutter/material.dart';

import '../models/vehicle.dart';

class VehiclePopup extends StatelessWidget {
  final Vehicle vehicle;
  final String routeName;

  const VehiclePopup({
    super.key,
    required this.vehicle,
    required this.routeName,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Consume the tap so tapping
        // the popup does not close it.
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                blurRadius: 6,
                color: Colors.black26,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Route: $routeName',
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),

              Text(
                'Speed: ${vehicle.speed.toStringAsFixed(1)} km/h',
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),

              Text(
                'Bearing: ${vehicle.bearing.toStringAsFixed(0)}°',
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}