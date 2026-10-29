import 'package:flutter/material.dart';

/// Local animation resource slot. Replace the painter with a cached character
/// asset later; the static painter stays available without files or network.
class DogAvatar extends StatefulWidget {
  final bool animate;
  final double size;
  const DogAvatar({super.key, this.animate = false, this.size = 96});
  @override
  State<DogAvatar> createState() => _DogAvatarState();
}

class _DogAvatarState extends State<DogAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncAnimation();
  }

  @override
  void didUpdateWidget(DogAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncAnimation();
  }

  void syncAnimation() {
    final enabled =
        widget.animate &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (enabled) {
      if (!controller.isAnimating) controller.repeat(reverse: true);
    } else {
      controller.stop();
      controller.value = 0;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: '陪伴小狗',
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, _) => CustomPaint(painter: DogPainter(controller.value)),
        ),
      ),
    ),
  );
}

class DogPainter extends CustomPainter {
  final double mouth;
  DogPainter(this.mouth);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawCircle(
      const Offset(50, 50),
      49,
      Paint()..color = const Color(0xffe2efff),
    );
    final brown = Paint()..color = const Color(0xffa96938);
    final cream = Paint()..color = const Color(0xffffdca9);
    final ink = Paint()..color = const Color(0xff34281f);
    final white = Paint()..color = const Color(0xfffff4df);
    canvas.drawOval(const Rect.fromLTWH(9, 15, 24, 61), brown);
    canvas.drawOval(const Rect.fromLTWH(67, 15, 24, 61), brown);
    canvas.drawOval(const Rect.fromLTWH(23, 15, 54, 73), cream);
    canvas.drawOval(const Rect.fromLTWH(31, 53, 38, 31), white);
    canvas.drawCircle(const Offset(37, 43), 4, ink);
    canvas.drawCircle(const Offset(63, 43), 4, ink);
    canvas.drawCircle(const Offset(38, 42), 1.1, white);
    canvas.drawCircle(const Offset(64, 42), 1.1, white);
    canvas.drawOval(const Rect.fromLTWH(43, 55, 14, 10), ink);
    if (mouth > 0.15) {
      canvas.drawOval(Rect.fromLTWH(42, 69, 16, 3 + mouth * 11), ink);
      if (mouth > 0.3) {
        canvas.drawOval(
          Rect.fromLTWH(46, 73, 8, mouth * 7),
          Paint()..color = const Color(0xffef8e9b),
        );
      }
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(41, 69)
          ..quadraticBezierTo(50, 77, 59, 69),
        Paint()
          ..color = ink.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(33, 83, 34, 8),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xff1469d8),
    );
    canvas.drawCircle(const Offset(50, 89), 6, Paint()..color = Colors.white);
    canvas.drawRect(
      const Rect.fromLTWH(49, 85, 2, 8),
      Paint()..color = const Color(0xff1469d8),
    );
    canvas.drawRect(
      const Rect.fromLTWH(46, 88, 8, 2),
      Paint()..color = const Color(0xff1469d8),
    );
  }

  @override
  bool shouldRepaint(DogPainter oldDelegate) => oldDelegate.mouth != mouth;
}
