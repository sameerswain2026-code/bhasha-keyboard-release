import 'package:flutter/material.dart';

class FlowStep extends StatelessWidget {
  const FlowStep(this.icon, this.label, {super.key});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class FlowArrow extends StatelessWidget {
  const FlowArrow({super.key});

  @override
  Widget build(BuildContext context) => Icon(
    Icons.arrow_forward_rounded,
    size: 16,
    color: Theme.of(context).colorScheme.outline,
  );
}
