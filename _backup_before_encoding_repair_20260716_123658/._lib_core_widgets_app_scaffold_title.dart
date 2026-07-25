import 'package:flutter/material.dart';

class AppScaffoldTitle extends StatelessWidget {
  const AppScaffoldTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (subtitle != null) Text(subtitle!),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}
