import 'package:flutter/material.dart';

// Card used for the main actions in Home (search, lost item, found item).
class HomeActionCard extends StatelessWidget {
  const HomeActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
    this.large = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  // Yellow background for the primary action.
  final bool highlighted;

  // Taller card with a bigger icon, used for the first action.
  final bool large;

  static const _yellow = Color(0xFFFEFD05);
  static const _border = Color(0xFFE2DEDE);
  static const _grey = Color(0xFF999798);

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);

    return Material(
      color: highlighted ? _yellow : Colors.white,
      shape: RoundedRectangleBorder(
        side: highlighted ? BorderSide.none : const BorderSide(color: _border),
        borderRadius: radius,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: SizedBox(
          height: large ? 122 : 104,
          child: Padding(
            padding: large
                ? const EdgeInsets.fromLTRB(24, 22, 24, 0)
                : const EdgeInsets.fromLTRB(24, 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: large ? 3 : 5),
                  child: Icon(icon, size: large ? 31 : 28, color: Colors.black),
                ),
                SizedBox(width: large ? 23 : 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          color: highlighted ? Colors.black : _grey,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
