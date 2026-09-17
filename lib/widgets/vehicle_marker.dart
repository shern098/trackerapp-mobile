// import 'package:flutter/material.dart';
//
// import '../models/vehicle.dart';
//
// class VehicleMarker extends StatefulWidget {
//   final Vehicle vehicle;
//
//   const VehicleMarker({
//     super.key,
//     required this.vehicle,
//   });
//
//   @override
//   State<VehicleMarker> createState() => _VehicleMarkerState();
// }
//
//
// class _VehicleMarkerState extends State<VehicleMarker> {
//   double _rotation = 0.0;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _updateRotation();
//   }
//
//   @override
//   void didUpdateWidget(
//       covariant VehicleMarker oldWidget,
//       ) {
//     super.didUpdateWidget(oldWidget);
//
//     if (oldWidget.vehicle.bearing !=
//         widget.vehicle.bearing) {
//       _updateRotation();
//     }
//   }
//
//   void _updateRotation() {
//     setState(() {
//       _rotation =
//           widget.vehicle.bearing * 3.14159265359 / 180;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final bool isBus =
//         widget.vehicle.type == VehicleType.bus;
//
//     return Transform.rotate(
//       angle: _rotation,
//       child: Container(
//         width: 30,
//         height: 30,
//         decoration: BoxDecoration(
//           shape: BoxShape.circle,
//           color: isBus ? Colors.blue : Colors.green,
//           border: Border.all(
//             color: Colors.white,
//             width: 2,
//           ),
//         ),
//         child: Icon(
//           isBus
//               ? Icons.directions_bus
//               : Icons.train,
//           color: Colors.white,
//           size: 18,
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';

import '../models/vehicle.dart';

class VehicleMarker extends StatefulWidget {
  final Vehicle vehicle;
  final Color color;

  const VehicleMarker({
    super.key,
    required this.vehicle,
    required this.color,
  });

  @override
  State<VehicleMarker> createState() => _VehicleMarkerState();
}

class _VehicleMarkerState extends State<VehicleMarker> {
  double _rotation = 0.0;

  @override
  void initState() {
    super.initState();

    _updateRotation();
  }

  @override
  void didUpdateWidget(
      covariant VehicleMarker oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.vehicle.bearing !=
        widget.vehicle.bearing) {
      _updateRotation();
    }
  }



  void _updateRotation() {
    setState(() {
      _rotation =
          widget.vehicle.bearing * 3.14159265359 / 180;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isBus =
        widget.vehicle.type == VehicleType.bus;

    return Transform.rotate(
      angle: _rotation,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
        ),
        child: Icon(
          isBus
              ? Icons.directions_bus
              : Icons.train,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

