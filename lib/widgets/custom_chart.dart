// import 'package:flutter/material.dart';

// class CustomBarChart extends StatelessWidget {
//   final int passedCount;
//   final int failedCount;
  
//   const CustomBarChart({
//     super.key,
//     required this.passedCount,
//     required this.failedCount,
//   });
  
//   @override
//   Widget build(BuildContext context) {
//     final maxValue = (passedCount + failedCount == 0) 
//         ? 10.0 
//         : (passedCount + failedCount + 2).toDouble();
    
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           "Exam Performance",
//           style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//         ),
//         const SizedBox(height: 30),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: [
//             _buildBar("PASS", passedCount.toDouble(), Colors.greenAccent, maxValue),
//             _buildBar("FAIL", failedCount.toDouble(), Colors.redAccent, maxValue),
//           ],
//         ),
//         const SizedBox(height: 20),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: [
//             Text("Passed: $passedCount", style: const TextStyle(color: Colors.greenAccent)),
//             Text("Failed: $failedCount", style: const TextStyle(color: Colors.redAccent)),
//           ],
//         ),
//       ],
//     );
//   }
  
//   Widget _buildBar(String label, double value, Color color, double maxValue) {
//     final barHeight = maxValue > 0 ? (value / maxValue) * 150 : 0;
    
//     return Column(
//       children: [
//         Container(
//           height: 150,
//           width: 50,
//           decoration: BoxDecoration(
//             color: Colors.grey[800],
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Align(
//             alignment: Alignment.bottomCenter,
//             child: Container(
//               height: barHeight,
//               width: 50,
//               decoration: BoxDecoration(
//                 color: color,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(label, style: TextStyle(color: color)),
//         Text(value.toInt().toString(), style: const TextStyle(color: Colors.white)),
//       ],
//     );
//   }
// }