// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, depend_on_referenced_packages, unused_field, unnecessary_brace_in_string_interps, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_card_app_passenger/models/journey.dart';
import 'package:smart_card_app_passenger/themes/colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _firstName;
  String? _fullName;
  double? _walletBalance;
  String? _passengerIdMasked;
  String? _passengerId; // Store the actual passengerId
  bool _isLoading = true;
  String? _errorMessage;

  // Add lists for journey and transaction histories
  List<EnhancedJourney> _recentJourneys = [];
  List<Transaction> _recentTransactions = [];
  bool _loadingJourneys = true;
  bool _loadingTransactions = true;

  @override
  void initState() {
    super.initState();
    _fetchPassengerData(); // This will now fetch data and trigger the other fetches once we have passengerId
  }

  Future<void> _fetchPassengerData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'Please sign in to view your profile.';
          _isLoading = false;
        });
        return;
      }

      final doc =
          await FirebaseFirestore.instance
              .collection('passengers')
              .doc(user.uid)
              .get();

      if (!doc.exists) {
        setState(() {
          _errorMessage = 'Passenger profile not found.';
          _isLoading = false;
        });
        return;
      }

      final data = doc.data() ?? {};
      final name = data['name'] as String? ?? '';
      final balance = data['walletBalance'] as num?;
      final passengerId = data['passengerId']?.toString() ?? user.uid;

      // Mask passengerId (show last 5 characters with 5 stars)
      String maskedPid;
      if (passengerId.isNotEmpty) {
        final pidUpper = passengerId.toUpperCase();
        final last5 =
            pidUpper.length > 5
                ? pidUpper.substring(pidUpper.length - 5)
                : pidUpper;
        maskedPid = '********* $last5';
      } else {
        maskedPid = '-----';
      }

      setState(() {
        _fullName = name;
        _firstName = name.isNotEmpty ? name.split(' ').first : 'Passenger';
        _walletBalance = balance?.toDouble() ?? 0.0;
        _passengerIdMasked = maskedPid;
        _passengerId = passengerId; // Store the actual passengerId
        _isLoading = false;
      });

      // Now that we have the passengerId, fetch journey and transaction histories
      _fetchJourneyHistory();
      _fetchTransactionHistory();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Updated method to fetch journey history with route names from routes collection
  Future<void> _fetchJourneyHistory() async {
    // Don't fetch if we don't have passengerId yet
    if (_passengerId == null) return;

    setState(() {
      _loadingJourneys = true;
    });

    try {
      // Get journeys using temporary solution to avoid index issues
      final journeyDocs =
          await FirebaseFirestore.instance
              .collection('journeys')
              .where('passengerId', isEqualTo: _passengerId)
              .limit(10) // Get more to sort in memory
              .get();

      // Create a list to hold our enhanced journeys
      List<EnhancedJourney> enhancedJourneys = [];

      // Process each journey and fetch route info
      for (var doc in journeyDocs.docs) {
        // Create a journey object from Firestore data
        Journey journey = Journey.fromFirestore(doc);

        // Fetch route information
        String routeName = "Unknown Route";
        try {
          final routeDoc =
              await FirebaseFirestore.instance
                  .collection('routes')
                  .doc(journey.routeId)
                  .get();

          if (routeDoc.exists) {
            // Get the route name from the routes collection
            routeName =
                routeDoc.data()?['name'] as String? ??
                routeDoc.data()?['routeName'] as String? ??
                "Route ${journey.routeId}";
          }
        } catch (e) {
          print('Error fetching route info: ${e.toString()}');
        }

        // Create an enhanced journey object with route name
        enhancedJourneys.add(
          EnhancedJourney(journey: journey, routeName: routeName),
        );
      }

      // Sort the journeys by start timestamp (descending)
      enhancedJourneys.sort(
        (a, b) => b.journey.startTimestamp.compareTo(a.journey.startTimestamp),
      );

      // Take only the 5 most recent journeys
      enhancedJourneys = enhancedJourneys.take(5).toList();

      setState(() {
        _recentJourneys = enhancedJourneys;
        _loadingJourneys = false;
      });
    } catch (e) {
      setState(() {
        _loadingJourneys = false;
        _errorMessage = 'Error fetching journeys: ${e.toString()}';
      });
    }
  }

  // Updated method to fetch transaction history using passengerId
  Future<void> _fetchTransactionHistory() async {
    // Don't fetch if we don't have passengerId yet
    if (_passengerId == null) return;

    setState(() {
      _loadingTransactions = true;
    });

    try {
      // Get transactions using temporary solution to avoid index issues
      final transactionDocs =
          await FirebaseFirestore.instance
              .collection('transactions')
              .where('passengerId', isEqualTo: _passengerId)
              .limit(10) // Get more to sort in memory
              .get();

      final transactions =
          transactionDocs.docs.map((doc) {
            return Transaction(
              id: doc.id,
              amount: (doc.data()['amount'] as num?)?.toDouble() ?? 0.0,
              timestamp:
                  (doc.data()['timestamp'] as Timestamp?)?.toDate() ??
                  DateTime.now(),
              type: doc.data()['type']?.toString() ?? 'Unknown',
              description: doc.data()['description']?.toString() ?? '',
              passengerId: doc.data()['passengerId']?.toString() ?? '',
            );
          }).toList();

      // Sort transactions by timestamp
      transactions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _recentTransactions = transactions.take(5).toList();
        _loadingTransactions = false;
      });
    } catch (e) {
      setState(() {
        _loadingTransactions = false;
        _errorMessage = 'Error fetching transactions: ${e.toString()}';
      });
    }
  }

  Future<void> _refreshData() async {
    await _fetchPassengerData(); // This will trigger the other fetches once we have passengerId
  }

  Widget _buildSmartCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: AppColors.primaryDark,
      child: Container(
        width: double.infinity,
        height: 200,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.5),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Smart NFC Card',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'ACTIVE',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _isLoading ? 'Loading...' : (_passengerIdMasked ?? '-----'),
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.white70,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const Spacer(),
            Text(
              'Wallet Balance',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white70),
            ),
            Text(
              _isLoading
                  ? 'Loading...'
                  : (_walletBalance != null
                      ? 'Rs. ${_walletBalance!.toStringAsFixed(2)}'
                      : 'Rs. 0.00'),
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget to display journey history
  Widget _buildJourneyHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Recent Journeys',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_loadingJourneys)
          const Center(
            child: CircularProgressIndicator(color: AppColors.accentGreen),
          )
        else if (_recentJourneys.isEmpty)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No journey history found',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.grey600,
                  ),
                ),
              ),
            ),
          )
        else
          ...(_recentJourneys
              .map((enhancedJourney) => _buildJourneyItem(enhancedJourney))
              .toList()),
      ],
    );
  }

  // Updated journey item to show route name and stopped time
  Widget _buildJourneyItem(EnhancedJourney enhancedJourney) {
    final journey = enhancedJourney.journey;
    final routeName = enhancedJourney.routeName;

    final formattedDate =
        '${journey.startTimestamp.day}/${journey.startTimestamp.month}/${journey.startTimestamp.year}';
    final formattedStartTime =
        '${journey.startTimestamp.hour.toString().padLeft(2, '0')}:${journey.startTimestamp.minute.toString().padLeft(2, '0')}';

    // Format stopped time if available
    String formattedStopTime = 'In progress';
    if (journey.endTimestamp != null) {
      formattedStopTime =
          '${journey.endTimestamp!.hour.toString().padLeft(2, '0')}:${journey.endTimestamp!.minute.toString().padLeft(2, '0')}';
    }

    // Calculate duration if available
    String durationText = '';
    if (journey.duration != null) {
      final hours = journey.duration!.inHours;
      final minutes = journey.duration!.inMinutes % 60;
      if (hours > 0) {
        durationText = '$hours h ${minutes.toString().padLeft(2, '0')} m';
      } else {
        durationText = '${minutes} min';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: AppColors.shadowGreen,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          'Journey on $formattedDate',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryDark,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              routeName,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cost: Rs. ${journey.totalCost.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryDark,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        journey.isCompleted
                            ? Colors.green
                            : Colors.amber,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    journey.isCompleted ? 'Completed' : 'In Progress',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(
          Icons.expand_more,
          size: 24,
          color: AppColors.accentGreen,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Journey times and duration
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Started',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.grey600,
                            ),
                          ),
                          Text(
                            formattedStartTime,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stopped',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.grey600,
                            ),
                          ),
                          Text(
                            formattedStopTime,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color:
                                  journey.isCompleted
                                      ? AppColors.primaryDark
                                      : Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (journey.isCompleted)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Duration',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.grey600,
                              ),
                            ),
                            Text(
                              durationText,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget to display transaction history
  Widget _buildTransactionHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Transaction History',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_loadingTransactions)
          const Center(
            child: CircularProgressIndicator(color: AppColors.accentGreen),
          )
        else if (_recentTransactions.isEmpty)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No transaction history found',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.grey600,
                  ),
                ),
              ),
            ),
          )
        else
          ...(_recentTransactions
              .map((transaction) => _buildTransactionItem(transaction))
              .toList()),
      ],
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final formattedDate =
        '${transaction.timestamp.day}/${transaction.timestamp.month}/${transaction.timestamp.year}';
    final formattedTime =
        '${transaction.timestamp.hour.toString().padLeft(2, '0')}:${transaction.timestamp.minute.toString().padLeft(2, '0')}';

    IconData icon;
    Color color;

    switch (transaction.type.toLowerCase()) {
      case 'topup':
        icon = Icons.add_circle;
        color = Colors.green;
        break;
      case 'credit':
        icon = Icons.payment;
        color = AppColors.primaryDark;
        break;
      case 'debit':
        icon = Icons.remove_circle;
        color = const Color.fromARGB(255, 255, 0, 0);
        break;
      default:
        icon = Icons.swap_horiz;
        color = AppColors.grey600;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                transaction.description.isNotEmpty
                    ? transaction.description
                    : transaction.type.capitalize(),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              'Rs. ${transaction.amount.toStringAsFixed(2)}',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color:
                    transaction.type.toLowerCase() == 'topup' ||
                            transaction.type.toLowerCase() == 'refund'
                        ? Colors.green
                        : Colors.red,
              ),
            ),
          ],
        ),
        subtitle: Text(
          '$formattedDate at $formattedTime',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.grey600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppColors.accentGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _isLoading
                    ? 'Loading...'
                    : 'Welcome, ${_firstName ?? "Passenger"}!',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Manage your Passenger profile',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.grey600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSmartCard(),
            const SizedBox(height: 30),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppColors.accentGreen),
              )
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else ...[
              _buildJourneyHistory(),
              const SizedBox(height: 25),
              _buildTransactionHistory(),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Enhanced Journey class to include route name
class EnhancedJourney {
  final Journey journey;
  final String routeName;

  EnhancedJourney({required this.journey, required this.routeName});
}

// Transaction model class for handling transaction data
class Transaction {
  final String id;
  final double amount;
  final DateTime timestamp;
  final String type;
  final String description;
  final String passengerId;

  Transaction({
    required this.id,
    required this.amount,
    required this.timestamp,
    required this.type,
    required this.description,
    required this.passengerId,
  });
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    return isNotEmpty
        ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}'
        : '';
  }
}
