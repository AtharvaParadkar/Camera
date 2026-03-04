import 'dart:math' as math;
import 'package:flutter/material.dart';

class ZoomDial extends StatefulWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onZoomChanged;

  const ZoomDial({
    super.key,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomChanged,
  });

  @override
  State<ZoomDial> createState() => _ZoomDialState();
}

class _ZoomDialState extends State<ZoomDial> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) {
        // Logarithmic zoom update for smooth natural panning
        double newZoom =
            widget.currentZoom * math.exp(details.delta.dx * -0.005);
        newZoom = newZoom.clamp(widget.minZoom, widget.maxZoom);
        widget.onZoomChanged(newZoom);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            // Decreased the height of the dial
            height: 90,
            child: CustomPaint(
              painter: ZoomDialPainter(
                currentZoom: widget.currentZoom,
                minZoom: widget.minZoom,
                maxZoom: widget.maxZoom,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  // Position the current zoom text slightly lower so it stays visible
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${widget.currentZoom.toStringAsFixed(1)}x',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ZoomDialPainter extends CustomPainter {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;

  ZoomDialPainter({
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Setup dial visual geometry
    // Larger radius to make the arc look flatter
    final double radius = size.width * 0.7;
    // Position the center so the top of the arc rests at y=0
    final Offset center = Offset(size.width / 2, radius);

    // Draw the dark semi-transparent background dial
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      true,
      bgPaint,
    );

    // 2. Setup mapping from zoom to polar projection angles
    // Logarithmic scale ensures smoothly consistent zoom increments
    final double angleMultiplier = 1.2;
    double zoomToAngle(double z) => math.log(z) * angleMultiplier;

    // The visual angle offset representing the current zoom level
    final double currentAngle = zoomToAngle(currentZoom);

    // 3. Collect tick marks progressively
    // No tick marked before zoom scale 1 (so startZ is at least 1.0)
    double startZ = minZoom < 1.0 ? 1.0 : minZoom;
    startZ = (startZ * 10).round() / 10;

    List<double> tickZooms = [];
    for (double i = startZ; i <= maxZoom + 0.05;) {
      double z = (i * 10).round() / 10;
      if (z >= 1.0) tickZooms.add(z);

      // Decrease width realistically without cluttering at higher magnitudes
      if (i < 3.0) {
        i += 0.1;
      } else if (i < 6.0) {
        i += 0.2;
      } else {
        i += 0.5;
      }
    }

    final TextPainter textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    final tickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0;

    // Position radius where the number labels reside
    final double textRadius = radius - 26;

    // 4. Render visible ticks and text
    for (final z in tickZooms) {
      if (z < 1.0) continue; // Safety guard: skip ticks below 1.0

      final tickAngle = zoomToAngle(z);
      // Final angle on the dial canvas. (-math.pi / 2 is the top-center)
      final screenAngle = -math.pi / 2 + (tickAngle - currentAngle);

      // Render only if within the top semicircle bounds (-180 to 0 degrees)
      if (screenAngle > -math.pi && screenAngle < 0) {
        // Compute fade opacity on far edges
        double distanceFromCenter = (screenAngle - (-math.pi / 2)).abs();
        double opacity =
            1.0 - (distanceFromCenter / (math.pi / 2.5)).clamp(0.0, 1.0);

        if (opacity <= 0) continue;

        // Categorize the tick logic
        bool isMajor = (z % 1 == 0); // i.e. 1.0, 2.0, 3.0
        bool isHalf = (z * 10).round() % 5 == 0 && !isMajor;

        double tickLength = isMajor ? 12 : (isHalf ? 8 : 4);

        final innerRadiusOffset = radius - tickLength - 5;
        final outerRadiusOffset = radius - 5;

        tickPaint.color = Colors.white.withValues(alpha: opacity);

        final startP = Offset(
          center.dx + innerRadiusOffset * math.cos(screenAngle),
          center.dy + innerRadiusOffset * math.sin(screenAngle),
        );
        final endP = Offset(
          center.dx + outerRadiusOffset * math.cos(screenAngle),
          center.dy + outerRadiusOffset * math.sin(screenAngle),
        );

        canvas.drawLine(startP, endP, tickPaint);

        // Render zoom level numbers next to major scales on the radius
        if (isMajor) {
          textPainter.text = TextSpan(
            text: z.toInt().toString(), // Will output 1, 2, 3..
            style: TextStyle(
              color: Colors.white.withValues(alpha: opacity),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          );
          textPainter.layout();

          final textCenter = Offset(
            center.dx + textRadius * math.cos(screenAngle),
            center.dy + textRadius * math.sin(screenAngle),
          );

          canvas.save();
          canvas.translate(textCenter.dx, textCenter.dy);
          // Draw evenly upright
          textPainter.paint(
            canvas,
            Offset(-textPainter.width / 2, -textPainter.height / 2),
          );
          canvas.restore();
        }
      }
    }

    // 5. Render central active fixed orange line representing exact value
    final orangePaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2.0;

    final activeInner = radius - 20;
    final activeOuter = radius - 5;

    canvas.drawLine(
      Offset(center.dx, center.dy - activeOuter),
      Offset(center.dx, center.dy - activeInner),
      orangePaint,
    );
  }

  @override
  bool shouldRepaint(covariant ZoomDialPainter oldDelegate) {
    return oldDelegate.currentZoom != currentZoom ||
        oldDelegate.minZoom != minZoom ||
        oldDelegate.maxZoom != maxZoom;
  }
}
