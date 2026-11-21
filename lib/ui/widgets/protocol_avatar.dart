import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../../core/models/proxy_profile.dart';

class ProtocolAvatar extends StatelessWidget {
  const ProtocolAvatar({
    super.key,
    required this.profile,
    this.error = false,
    this.size = 42,
  });

  final ProxyProfile profile;
  final bool error;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final countryCode = profile.countryCode;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: countryCode == null
          ? Padding(
              padding: EdgeInsets.all(size * 0.18),
              child: FittedBox(
                child: Text(
                  profile.protocol.shortLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: size * 0.28,
                    color: error
                        ? scheme.onErrorContainer
                        : scheme.onSecondaryContainer,
                  ),
                ),
              ),
            )
          : CountryFlag.fromCountryCode(
              countryCode,
              theme: ImageTheme(
                width: size * 0.76,
                height: size * 0.54,
                shape: RoundedRectangle(size * 0.08),
              ),
            ),
    );
  }
}
