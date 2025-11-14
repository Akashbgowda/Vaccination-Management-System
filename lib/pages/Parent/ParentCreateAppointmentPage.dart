import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../utils/vaccination_schedule.dart';

class ParentCreateAppointmentPage extends StatefulWidget {
  const ParentCreateAppointmentPage({super.key});

  @override
  State<ParentCreateAppointmentPage> createState() =>
      _ParentCreateAppointmentPageState();
}

class _ParentCreateAppointmentPageState
    extends State<ParentCreateAppointmentPage> {
  String? _selectedChild;
  String? _selectedDoctor;
  String? _selectedVaccineId;
  String? _selectedVaccineName;
  int? _childAgeMonths;
  List<Map<String, dynamic>> _childData = [];
  List<Map<String, dynamic>> _doctorData = [];
  List<VaccineScheduleItem> _recommendedVaccines = [];
  bool _isLoading = false;

  DateTime? _selectedAppointmentDateTime;
  DateTime? _selectedReminderDateTime;
  String _repeatType = "none"; // none, daily, weekly, hourly

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadData();
  }

  // -------------------- NOTIFICATION SETUP --------------------
  Future<void> _initializeNotifications() async {
    tz_data.initializeTimeZones();

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit);

    await _notificationsPlugin.initialize(initSettings);

    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();
  }

  // -------------------- LOAD CHILDREN & DOCTORS --------------------
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchChildren(),
      _fetchDoctors(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchChildren() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final parentDoc =
        await FirebaseFirestore.instance.collection("parents").doc(uid).get();
    if (!parentDoc.exists) return;

    List<dynamic> childIds = parentDoc.data()?['children'] ?? [];
    _childData = [];

    for (var childId in childIds) {
      var childDoc = await FirebaseFirestore.instance
          .collection('children')
          .doc(childId)
          .get();
      if (childDoc.exists) {
        var data = childDoc.data() as Map<String, dynamic>;
        _childData.add({
          'id': childDoc.id,
          'name': data['name'] ?? 'Unknown',
          'dob': (data['dob'] as Timestamp?)?.toDate(),
        });
      }
    }
    setState(() {});
  }

  Future<void> _fetchDoctors() async {
    final snap = await FirebaseFirestore.instance.collection("doctors").get();
    _doctorData = snap.docs
        .map((d) => {"id": d.id, "name": d.data()["name"] ?? "Unknown Doctor"})
        .toList();
    setState(() {});
  }

  void _onChildSelected(String? childId) {
    setState(() {
      _selectedChild = childId;
      _selectedVaccineId = null;
      _selectedVaccineName = null;
      _recommendedVaccines = [];

      if (childId != null) {
        var child = _childData.firstWhere((c) => c['id'] == childId);
        var dob = child['dob'] as DateTime?;
        if (dob != null) {
          _childAgeMonths = VaccinationSchedule.calculateAgeInMonths(dob);
          _recommendedVaccines =
              VaccinationSchedule.getVaccinationsForAge(_childAgeMonths!);
        }
      }
    });
  }

  Future<bool> _requestExactAlarmPermission() async {
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) return false;

    final bool? granted = await androidPlugin.requestExactAlarmsPermission();
    return granted ?? false;
  }

  // -------------------- SAVE APPOINTMENT --------------------
  Future<void> _saveAppointment() async {
    if (_selectedChild == null ||
        _selectedDoctor == null ||
        _selectedVaccineId == null ||
        _selectedAppointmentDateTime == null ||
        _selectedReminderDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final docRef = FirebaseFirestore.instance.collection("appointments").doc();

    try {
      await docRef.set({
        "uuid": docRef.id,
        "child_id": _selectedChild,
        "doctor_id": _selectedDoctor,
        "parent_id": uid,
        "vaccination_id": _selectedVaccineId,
        "vaccination_name": _selectedVaccineName,
        "date": _selectedAppointmentDateTime!.toIso8601String(),
        "reminder_time": _selectedReminderDateTime!.toIso8601String(),
        "repeat_type": _repeatType,
        "status": "pending_approval",
        "created_at": DateTime.now().toIso8601String(),
        "updated_at": DateTime.now().toIso8601String(),
      });

      // schedule reminder
      await _scheduleReminderNotification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Appointment submitted & reminder scheduled successfully."),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating appointment: $e")),
        );
      }
    }
  }

  // -------------------- NOTIFICATION SCHEDULING --------------------
  Future<void> _scheduleReminderNotification() async {
    final reminderTime = _selectedReminderDateTime!;
    final now = DateTime.now();

    if (reminderTime.isBefore(now)) {
      print("❌ Reminder time is in the past — skipping");
      return;
    }

    final delaySeconds = reminderTime.difference(now).inSeconds;

    print("⏳ Simple timer scheduled for $delaySeconds seconds");

    Future.delayed(Duration(seconds: delaySeconds), () async {
      print("🔔 Triggering scheduled reminder NOW");

      await _notificationsPlugin.show(
        reminderTime.hashCode,
        "Vaccination Reminder",
        "Upcoming: $_selectedVaccineName",
        NotificationDetails(
          android: AndroidNotificationDetails(
            'simple_channel',
            'Simple Notifications',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  // -------------------- UI --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Appointment Request")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -------------------- Child Selection --------------------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("1. Select Child",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedChild,
                            items: _childData
                                .map((c) => DropdownMenuItem<String>(
                                      value: c["id"] as String?,
                                      child: Text(c["name"]),
                                    ))
                                .toList(),
                            onChanged: _onChildSelected,
                            decoration: const InputDecoration(
                              labelText: "Select Child",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // -------------------- Recommended Vaccines --------------------
                  if (_selectedChild != null && _recommendedVaccines.isNotEmpty)
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  "Recommended Vaccinations (Age: $_childAgeMonths months)",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ..._recommendedVaccines.map((vaccine) =>
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.check_circle,
                                          size: 20,
                                          color: Colors.green.shade700),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(vaccine.vaccine,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            if (vaccine.remarks.isNotEmpty)
                                              Text(
                                                vaccine.remarks,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        Colors.grey.shade600),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // -------------------- Vaccine Selector --------------------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("2. Select Vaccine",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: InputDecoration(
                              labelText: "Search and select vaccine",
                              prefixIcon: const Icon(Icons.search),
                              border: const OutlineInputBorder(),
                              suffixIcon: _selectedVaccineId != null
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        setState(() {
                                          _selectedVaccineId = null;
                                          _selectedVaccineName = null;
                                        });
                                      },
                                    )
                                  : null,
                            ),
                            onTap: _showVaccineSelectionDialog,
                            controller:
                                TextEditingController(text: _selectedVaccineName),
                            readOnly: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // -------------------- Doctor Selector --------------------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("3. Select Doctor",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedDoctor,
                            items: _doctorData
                                .map((d) => DropdownMenuItem<String>(
                                      value: d["id"] as String?,
                                      child: Text(d["name"]),
                                    ))
                                .toList(),
                            onChanged: (String? val) =>
                                setState(() => _selectedDoctor = val),
                            decoration: const InputDecoration(
                              labelText: "Select Doctor",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // -------------------- Appointment Date & Time --------------------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("4. Appointment Date & Time",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate:
                                    DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2100),
                              );

                              if (pickedDate == null) return;

                              TimeOfDay? pickedTime = await showTimePicker(
                                context: context,
                                initialTime:
                                    const TimeOfDay(hour: 9, minute: 0),
                              );

                              if (pickedTime == null) return;

                              setState(() {
                                _selectedAppointmentDateTime = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            },
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50)),
                            child: Text(_selectedAppointmentDateTime == null
                                ? "Select Appointment Date & Time"
                                : _selectedAppointmentDateTime.toString()),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // -------------------- Reminder Date & Time --------------------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("5. Reminder Date & Time",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: _selectedAppointmentDateTime ??
                                    DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime(2100),
                              );

                              if (pickedDate == null) return;

                              TimeOfDay? pickedTime = await showTimePicker(
                                context: context,
                                initialTime:
                                    const TimeOfDay(hour: 9, minute: 0),
                              );

                              if (pickedTime == null) return;

                              setState(() {
                                _selectedReminderDateTime = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            },
                            style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50)),
                            child: Text(_selectedReminderDateTime == null
                                ? "Select Reminder Date & Time"
                                : _selectedReminderDateTime.toString()),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // -------------------- Repeat Reminder --------------------
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("6. Repeat Reminder",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _repeatType,
                            items: const [
                              DropdownMenuItem(value: "none", child: Text("No Repeat")),
                              DropdownMenuItem(value: "daily", child: Text("Repeat Daily")),
                              DropdownMenuItem(value: "weekly", child: Text("Repeat Weekly")),
                              DropdownMenuItem(value: "hourly", child: Text("Repeat Hourly")),
                            ],
                            onChanged: (val) => setState(() => _repeatType = val ?? "none"),
                            decoration: const InputDecoration(
                              labelText: "Repeat Type",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  const SizedBox(height: 12),

                  // -------------------- Submit --------------------
                  ElevatedButton(
                    onPressed: _saveAppointment,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.green,
                    ),
                    child: const Text("Submit Appointment Request",
                        style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }

  // -------------------- Vaccine Selection Dialog --------------------
  void _showVaccineSelectionDialog() async {
    final snap =
        await FirebaseFirestore.instance.collection("vaccinations").get();

    final vaccineDocs = snap.docs
        .map((doc) => {
              "id": doc.id,
              "name": doc.data()["name"] ?? "Unknown",
            })
        .toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Vaccine",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: vaccineDocs.length,
                  itemBuilder: (context, index) {
                    final vaccine = vaccineDocs[index];
                    return ListTile(
                      title: Text(vaccine["name"]),
                      onTap: () {
                        setState(() {
                          _selectedVaccineId = vaccine["id"];
                          _selectedVaccineName = vaccine["name"];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
            ],
          ),
        ),
      ),
    );
  }
} // end of _ParentCreateAppointmentPageState

 // end of ParentCreateAppointmentPage widget