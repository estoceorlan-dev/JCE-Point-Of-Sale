import 'package:flutter/material.dart';

class LoginBrandHeader extends StatelessWidget {
  const LoginBrandHeader({super.key, required this.logoAsset});

  final String logoAsset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ClipOval(
        child: Image.asset(
          logoAsset,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          semanticLabel: 'JCE logo',
        ),
      ),
    );
  }
}
