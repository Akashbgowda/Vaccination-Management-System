import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../utils/logoutuser.dart';
import '../../utils/vaccination_schedule.dart';
import '../../components/CustomBottomNav.dart';
import 'ParentCreateAppointmentPage.dart';
import 'ParentReportPage.dart';

class ParentHomePage extends StatelessWidget {
  const ParentHomePage({super.key});

  Future<void> _debugInstantNotification() async {
    final plugin = FlutterLocalNotificationsPlugin();

    await plugin.show(
      1111,
      "Instant Test",
      "This should appear immediately.",
      NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_channel',
          'Instant Notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

Future<void> _debugTestNotification() async {
  // initialize timezone database before creating TZDateTime
  tz_data.initializeTimeZones();

  final flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Request exact alarm permission (Android 12+)
  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    await androidPlugin.requestExactAlarmsPermission();
  }

  // Schedule a notification 5 seconds from now
  final scheduledTime =
      DateTime.now().add(const Duration(seconds: 5));
  final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);

  await flutterLocalNotificationsPlugin.zonedSchedule(
    987654321, // random id
    "Test Notification",
    "If you see this, notifications work!",
    tzTime,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

  Future<void> _launchGoogleMaps(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final geoUri = Uri.parse('geo:0,0?q=$encodedQuery');
    final comGoogleUri = Uri.parse('comgooglemaps://?q=$encodedQuery');
    final appleMapsUri = Uri.parse('http://maps.apple.com/?q=$encodedQuery');
    final googleMapsWebUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encodedQuery',
    );

    try {
      print('Attempting to open maps for query: $query');

      // Try platform-specific native intents/schemes first
      if (Platform.isAndroid) {
        try {
          if (await canLaunchUrl(geoUri)) {
            final ok = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
            if (ok) return;
          }
        } catch (_) {}
        try {
          if (await canLaunchUrl(comGoogleUri)) {
            final ok = await launchUrl(comGoogleUri, mode: LaunchMode.externalApplication);
            if (ok) return;
          }
        } catch (_) {}
      }

      if (Platform.isIOS) {
        try {
          if (await canLaunchUrl(appleMapsUri)) {
            final ok = await launchUrl(appleMapsUri, mode: LaunchMode.externalApplication);
            if (ok) return;
          }
        } catch (_) {}
        try {
          if (await canLaunchUrl(comGoogleUri)) {
            final ok = await launchUrl(comGoogleUri, mode: LaunchMode.externalApplication);
            if (ok) return;
          }
        } catch (_) {}
      }

      // Fallback: try opening the Google Maps web URL directly.
      // Use launchUrl directly (don't rely only on canLaunchUrl for https).
      try {
        final launched = await launchUrl(googleMapsWebUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      } catch (e) {
        print('Direct web launch failed: $e');
      }

      // As a last attempt try opening in-app web view (if supported)
      try {
        final launchedInApp = await launchUrl(googleMapsWebUri, mode: LaunchMode.inAppWebView);
        if (launchedInApp) return;
      } catch (e) {
        print('In-app web launch failed: $e');
      }

      // If we reach here nothing worked
      print('Could not launch any map for query: $query');
    } catch (e) {
      print('Unexpected error launching maps: $e');
    }
  }

  void _showServicesDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Medical Services',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Find nearby medical facilities and services',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              _ServiceButton(
                icon: Icons.local_hospital,
                title: 'Emergency Care',
                subtitle: 'Find nearby emergency rooms',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _launchGoogleMaps('emergency care near me');
                },
              ),
              const SizedBox(height: 12),
              _ServiceButton(
                icon: Icons.vaccines,
                title: 'Vaccination Centers',
                subtitle: 'Find nearby vaccination centers',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _launchGoogleMaps('vaccination center near me');
                },
              ),
              const SizedBox(height: 12),
              _ServiceButton(
                icon: Icons.healing,
                title: 'Hospitals',
                subtitle: 'Find nearby hospitals',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _launchGoogleMaps('hospital near me');
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Updated: Passes a callback to trigger navigation safely after dialog closes
  void _showGenerateReportDialog(BuildContext context) {
    print('📋 Opening child selection dialog...');
    _fetchChildrenForReport().then((children) {
      print('👥 Found ${children.length} children');

      if (children.isEmpty) {
        print('⚠️ No children found');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No children found")),
        );
        return;
      }

      print('✅ Showing child selection dialog');

      showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Generate Report"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: children.length,
              itemBuilder: (context, index) {
                final child = children[index];
                return ListTile(
                  title: Text(child['name']),
                  subtitle: Text(
                    "Age: ${child['age']} years | Gender: ${child['gender']}",
                  ),
                  onTap: () {
                    print('👤 Selected child: ${child['name']}');
                    Navigator.of(dialogContext).pop(child); // Pop and return child data
                  },
                );
              },
            ),
          ),
        ),
      ).then((selectedChild) {
        // This callback runs in the mounted parent context
        if (selectedChild != null) {
          _generateReport(context, selectedChild);
        }
      });
    });
  }

  Future<List<Map<String, dynamic>>> _fetchChildrenForReport() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot parentDoc = await FirebaseFirestore.instance
        .collection('parents')
        .doc(uid)
        .get();
    if (!parentDoc.exists) return [];

    List<dynamic> childIds = parentDoc['children'] ?? [];
    List<Map<String, dynamic>> children = [];

    for (var childId in childIds) {
      var childDoc = await FirebaseFirestore.instance
          .collection('children')
          .doc(childId)
          .get();
      if (!childDoc.exists) continue;
      var childData = childDoc.data() as Map<String, dynamic>;
      children.add(childData);
    }

    return children;
  }

  Future<void> _generatePDF(
    Map<String, dynamic> child,
    int ageInMonths,
    List<VaccineScheduleItem> recommended,
    List<Map<String, dynamic>> completedAppointments,
    List<Map<String, dynamic>> pendingAppointments,
  ) async {
    print('📥 Starting PDF generation for ${child['name']}...');
    print('📊 Report data:');
    print('  - Completed vaccinations: ${completedAppointments.length}');
    print('  - Pending appointments: ${pendingAppointments.length}');
    print('  - Recommended vaccines: ${recommended.length}');

    final pdf = pw.Document();
    print('✅ PDF document created');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                'Vaccination Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Header(
              level: 1,
              child: pw.Text(
                'Child Information',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.purple700,
                ),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Name', child['name'] ?? 'N/A'),
                  _buildInfoRow(
                    'Age',
                    '${ageInMonths} months (${(ageInMonths / 12).toStringAsFixed(1)} years)',
                  ),
                  _buildInfoRow('Gender', child['gender'] ?? 'N/A'),
                  _buildInfoRow(
                    'Allergies',
                    (child['allergies'] as List?)?.join(', ') ?? 'None',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Header(
              level: 1,
              child: pw.Text(
                'Vaccinations Completed (${completedAppointments.length})',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green700,
                ),
              ),
            ),
            if (completedAppointments.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  'No vaccinations given yet',
                  style: pw.TextStyle(color: PdfColors.grey700),
                ),
              )
            else
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: completedAppointments.map((appt) {
                  final doctorDetails = appt['doctor_details'];
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      color: PdfColors.grey100,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          appt['vaccination_name'] ?? 'Unknown',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Provided by: Dr. ${doctorDetails?['name'] ?? 'Unknown'}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          'Date: ${appt['service_provided_at']?.toString().split(' ')[0] ?? appt['updated_at']?.toString().split(' ')[0] ?? 'N/A'}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                        if (doctorDetails?['specialization'] != null)
                          pw.Text(
                            'Specialization: ${doctorDetails['specialization']}',
                            style: pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey700,
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            pw.SizedBox(height: 20),
            pw.Header(
              level: 1,
              child: pw.Text(
                'Upcoming Appointments (${pendingAppointments.length})',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            ),
            if (pendingAppointments.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  'No upcoming appointments',
                  style: pw.TextStyle(color: PdfColors.grey700),
                ),
              )
            else
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: pendingAppointments.map((appt) {
                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      color: PdfColors.blue100,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          appt['vaccination_name'] ?? 'Unknown',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Status: ${appt['status']}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        pw.Text(
                          'Scheduled: ${appt['date']?.toString().split(' ')[0] ?? 'N/A'}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            pw.SizedBox(height: 20),
            pw.Header(
              level: 1,
              child: pw.Text(
                'Recommended Vaccinations for Age',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange700,
                ),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                color: PdfColors.orange50,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: recommended.take(10).map((vaccine) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 8),
                    child: pw.Row(
                      children: [
                        pw.Text('• ', style: pw.TextStyle(fontSize: 16)),
                        pw.Expanded(
                          child: pw.Text(
                            vaccine.vaccine,
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            pw.Spacer(),
            pw.Divider(),
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(
                'Generated on ${DateTime.now().toString().split('.')[0]}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
          ];
        },
      ),
    );

    print('✅ PDF content generated');
    // Show PDF preview and allow printing/sharing
    print('📤 Opening PDF viewer...');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
    print('✅ PDF generation complete and viewer closed');
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

  // No change: context used is always safe here due to above fix
  Future<void> _generateReport(
    BuildContext context,
    Map<String, dynamic> child,
  ) async {
    print('🟡 _generateReport called for child: ${child['name']}');
    // Step 1: Calculate age
    DateTime? dob;
    if (child['dob'] != null && child['dob'] is Timestamp) {
      dob = (child['dob'] as Timestamp).toDate();
    }
    int ageInMonths = dob != null ? VaccinationSchedule.calculateAgeInMonths(dob) : 0;
    print('🟡 Calculated ageInMonths: $ageInMonths');

    // Step 2: Fetch appointments
    var appointmentsSnap = await FirebaseFirestore.instance
        .collection('appointments')
        .where('child_id', isEqualTo: child['uuid'])
        .get();
    List<Map<String, dynamic>> appointments =
        appointmentsSnap.docs.map((doc) => doc.data()).toList();
    print('🟡 Appointments fetched: ${appointments.length}');

    // Step 3: Process appointments
    List<Map<String, dynamic>> completedAppointments = [];
    List<Map<String, dynamic>> pendingAppointments = [];

    for (var appt in appointments) {
      if (appt['status'] == 'completed') {
        Map<String, dynamic>? doctorDetails;
        if (appt['service_provided_by'] != null) {
          var docSnap = await FirebaseFirestore.instance
              .collection('doctors')
              .doc(appt['service_provided_by'])
              .get();
          doctorDetails = docSnap.data();
        }
        completedAppointments.add({...appt, 'doctor_details': doctorDetails});
      } else {
        pendingAppointments.add(appt);
      }
    }
    print('🟡 Completed: ${completedAppointments.length}, Pending: ${pendingAppointments.length}');

    // Step 4: Recommended vaccines
    List<VaccineScheduleItem> recommended =
        VaccinationSchedule.getVaccinationsForAge(ageInMonths);
    print('🟡 Recommended vaccines: ${recommended.length}');

    // Step 5: Safe navigation using parent's context
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParentReportPage(
          child: child,
          ageInMonths: ageInMonths,
          recommended: recommended,
          completedAppointments: completedAppointments,
          pendingAppointments: pendingAppointments,
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchChildrenWithAppointments() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot parentDoc = await FirebaseFirestore.instance
        .collection('parents')
        .doc(uid)
        .get();
    if (!parentDoc.exists) return [];

    List<dynamic> childIds = parentDoc['children'] ?? [];
    List<Map<String, dynamic>> children = [];

    for (var childId in childIds) {
      var childDoc = await FirebaseFirestore.instance
          .collection('children')
          .doc(childId)
          .get();
      if (!childDoc.exists) continue;
      var childData = childDoc.data() as Map<String, dynamic>;

      var appointmentsSnap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('child_id', isEqualTo: childId)
          .get();
      var appointments = appointmentsSnap.docs
          .map((doc) => doc.data())
          .toList();

      children.add({'child': childData, 'appointments': appointments});
    }

    return children;
  }

  @override
  Widget build(BuildContext context) {
    void _onNavTap(int index) {
      switch (index) {
        case 0:
          Navigator.pushReplacementNamed(context, "/parent_home");
          break;
        case 1:
          Navigator.pushReplacementNamed(context, "/chat");
          break;
        case 2:
          Navigator.pushReplacementNamed(context, "/parent_settings");
          break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Parent Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logoutUser(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ParentCreateAppointmentPage(),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle),
                    label: const Text("Create Appointment"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showServicesDialog(context),
                    icon: const Icon(Icons.medical_services),
                    label: const Text("Services"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showGenerateReportDialog(context),
                    icon: const Icon(Icons.description),
                    label: const Text("Report"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Padding(
          //   padding: const EdgeInsets.all(12.0),
          //   child: ElevatedButton.icon(
          //     onPressed: () {
          //       print("🔔 Triggering test notification...");
          //       _debugTestNotification();
          //     },
          //     icon: const Icon(Icons.notifications_active),
          //     label: const Text("Test Notification (Debug)"),
          //     style: ElevatedButton.styleFrom(
          //       minimumSize: const Size(double.infinity, 50),
          //       backgroundColor: Colors.orange,
          //       foregroundColor: Colors.white,
          //     ),
          //   ),
          // ),
          // Padding(
          //   padding: const EdgeInsets.symmetric(horizontal: 12.0),
          //   child: ElevatedButton(
          //     onPressed: _debugInstantNotification,
          //     child: const Text("Instant Notification Test"),
          //     style: ElevatedButton.styleFrom(
          //       minimumSize: const Size(double.infinity, 44),
          //       backgroundColor: Colors.orangeAccent,
          //       foregroundColor: Colors.white,
          //     ),
          //   ),
          // ),
          Expanded(
            child: FutureBuilder(
              future: _fetchChildrenWithAppointments(),
              builder:
                  (
                    context,
                    AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
                  ) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    var children = snapshot.data!;
                    if (children.isEmpty) {
                      return const Center(
                        child: Text("No children found. Add a child first."),
                      );
                    }
                    return ListView.builder(
                      itemCount: children.length,
                      itemBuilder: (context, index) {
                        var child = children[index]['child'];
                        var appointments =
                            children[index]['appointments'] as List;
                        return Card(
                          margin: const EdgeInsets.all(10),
                          child: ExpansionTile(
                            title: Text(child['name'] ?? 'No Name'),
                            subtitle: Text(
                              "Age: ${(child['age']?.toString() ?? '-')}"
                              " | Gender: ${(child['gender'] ?? '-')}",
                            ),
                            children: [
                              if (appointments.isEmpty)
                                const ListTile(
                                  title: Text("No appointments found."),
                                ),
                              ...appointments.map(
                                (appt) => ListTile(
                                  title: Text(
                                    "Status: ${appt['status'] ?? ''}",
                                  ),
                                  subtitle: Text(
                                    "Date: ${appt['date']?.toString() ?? ''}",
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(onTap: _onNavTap, role: "parent"),
    );
  }
}

class _ServiceButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ServiceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
