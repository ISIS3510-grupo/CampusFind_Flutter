import 'package:flutter/material.dart';

import '../../../core/models/lost_report.dart';
import '../../../core/utils/report_age.dart';
import '../domain/match_result.dart';

class MatchAlertScreen extends StatelessWidget {
  const MatchAlertScreen({
    super.key,
    required this.lostReport,
    required this.matchResult,
  });

  final LostReport lostReport;
  final MatchResult matchResult;

  @override
  Widget build(BuildContext context) {
    final foundItem = matchResult.foundItem;
    final location = foundItem.locationName.trim();
    final age = reportAge(foundItem.createdAt);
    final subtitle = location.isEmpty
        ? 'Found · $age'
        : 'Found in $location · $age';
    final imageUrl = foundItem.imageUrl?.trim();
    const placeholder = Center(
      child: Icon(Icons.image, size: 26, color: Color(0xFF999798)),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 22, right: 15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Possible match',
                              style: TextStyle(
                                fontSize: 31,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                                height: 1.2,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'We found an item that may be yours',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w300,
                                color: Color(0xFF999798),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Back',
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 28,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 23, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2DEDE)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: double.infinity,
                              height: 180,
                              color: const Color(0xFFE2DEDE),
                              child: imageUrl == null || imageUrl.isEmpty
                                  ? placeholder
                                  : Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) => placeholder,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            foundItem.title,
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
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w300,
                              color: Color(0xFF999798),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Container(
                            width: 120,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEFD05),
                              border: Border.all(
                                color: const Color(0xFFE2DEDE),
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Possible match',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: Text(
                              'Review the public details. Ownership is confirmed later with staff.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w300,
                                color: Color(0xFF999798),
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 34),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Item details will be available in the next flow.',
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        child: const Text('Review this match'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          side: const BorderSide(width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        child: const Text('Not mine'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2DEDE))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 61,
            child: BottomNavigationBar(
              currentIndex: 2,
              onTap: (_) {},
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 0,
              selectedItemColor: Colors.black,
              unselectedItemColor: const Color(0xFF999798),
              selectedFontSize: 10,
              unselectedFontSize: 10,
              iconSize: 22,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.search),
                  label: 'Search',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications),
                  label: 'Alerts',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
