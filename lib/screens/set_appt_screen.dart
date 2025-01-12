import 'dart:async';

import 'package:appointment_app/data/timeslots_list.dart';
import 'package:appointment_app/gets/get_date.dart';
import 'package:appointment_app/myWidgets/line_widget.dart';
import 'package:appointment_app/styles/app_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import '../gets/get_time.dart';
import '../myWidgets/dropdown_widget.dart';
import '../myWidgets/input_field_widget.dart';
import '../myWidgets/labels_widget.dart';
import '../services/twilio_service.dart';

class SetApptScreen extends StatefulWidget {
  const SetApptScreen({super.key});

  @override
  State<SetApptScreen> createState() => _SetApptScreenState();
}

class _SetApptScreenState extends State<SetApptScreen> {
  late TwilioService twilioService;

  String formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
  var nameInput = TextEditingController();
  var contactInput = TextEditingController();
  var scheduleTreatmentInput = TextEditingController();
  var noteInput = TextEditingController();

  String? selectedDayparts;
  var dayPartsList = ['Morning', 'Afternoon', 'Evening'];
  DateTime? selectedDate;
  Map<String, bool> blockedTimeSlots = {};
  String? selectedTimeSlot;
  final _formKey = GlobalKey<FormState>();

  // Fetch blocked time slots for the current date
  Future<void> fetchBlockedTimeSlots() async {
    DocumentSnapshot snapshot = await FirebaseFirestore.instance
        .collection("Appointments")
        .doc('Blocked Time Slots')
        .get();

    if (snapshot.exists) {
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      setState(() {
        blockedTimeSlots = data[formattedDate] != null
            ? Map<String, bool>.from(data[formattedDate])
            : {};
      });
    }
  }

  // Block the selected time slot in Firestore for the current date
  Future<void> permanentlyBlockTimeSlotInFirestore(String timeSlot) async {
    await FirebaseFirestore.instance
        .collection("Appointments")
        .doc('Blocked Time Slots')
        .set({
      formattedDate: {...blockedTimeSlots, timeSlot: true}
    }, SetOptions(merge: true));

    setState(() {
      blockedTimeSlots[timeSlot] = true;
    });
  }

  // Check if the selected time slot is already booked
  Future<bool> isTimeSlotAlreadyBooked(String timeSlot) async {
    final snapshot = await FirebaseFirestore.instance
        .collection("Appointments")
        .where("Selected Time Slot", isEqualTo: timeSlot)
        .where("Selected Date", isEqualTo: formattedDate)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // Set appointment data in Firestore and block time slot if available
  Future<void> setApptData() async {
    if (_formKey.currentState?.validate() == true) {
      if (contactInput.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact number cannot be empty.')),
        );
        return;
      } else if (selectedDate == null &&
          selectedDayparts == null &&
          selectedTimeSlot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select a Date, Time Slot and Day Part.')),
        );
        return;
      }

      if (selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date.')),
        );
        return;
      }

      if (selectedDayparts == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a day part.')),
        );
        return;
      }

      if (selectedTimeSlot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a time slot.')),
        );
        return;
      }

      if (blockedTimeSlots[selectedTimeSlot] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Selected time slot is blocked, please choose another one.')),
        );
        return;
      }

      bool isBooked = await isTimeSlotAlreadyBooked(selectedTimeSlot ?? '');
      if (isBooked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Selected time slot is already booked.')),
        );
        return;
      }

      if (selectedTimeSlot != null) {
        await permanentlyBlockTimeSlotInFirestore(selectedTimeSlot!);
      }

      String userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_user';

      // Check if an appointment with the same contact number and userId already exists
      QuerySnapshot existingAppointments = await FirebaseFirestore.instance
          .collection("Appointments")
          .where("userId", isEqualTo: userId)
          .get();

      // Generate a unique document ID or let Firestore auto-generate it
      final newAppointment = {
        'userId': userId,
        'Patient Name': nameInput.text.trim(),
        'Contact No.': contactInput.text.trim(),
        'Selected Date': formattedDate,
        'Day Part': selectedDayparts.toString(),
        'Selected Time Slot': selectedTimeSlot,
        'Schedule Treatment': scheduleTreatmentInput.text.trim(),
        'Note': noteInput.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Add a new document without overwriting existing ones
      await FirebaseFirestore.instance
          .collection('Appointments')
          .add(newAppointment);

      await twilioService.sendSms(
        toNumber: contactInput.text.trim(),
        name: nameInput.text.trim(),
        date: formattedDate,
        timeSlot: selectedTimeSlot ?? '',
        context: context,
      );

      await twilioService.sendWhatsappMsg(
        toNumber: contactInput.text.trim(),
        name: nameInput.text.trim(),
        date: formattedDate,
        timeSlot: selectedTimeSlot ?? '',
        context: context,
      );

      // Clear input fields and reset state
      nameInput.clear();
      contactInput.clear();
      scheduleTreatmentInput.clear();
      noteInput.clear();
      setState(() {
        selectedDayparts = null;
        selectedTimeSlot = null; // Reset selected time slot
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment set successfully!')),
      );
    }
  }

  // Build time slot buttons and apply blocking/booked logic
  Future<List<Widget>> _buildTimeSlots() async {
    List<Widget> timeSlotAsPerDayparts = [];

    if (selectedDayparts != null && timeSlots.containsKey(selectedDayparts)) {
      for (var timeSlot in timeSlots[selectedDayparts]!) {
        bool isBooked = await isTimeSlotAlreadyBooked(timeSlot);
        bool isBlocked = blockedTimeSlots[timeSlot] ?? false;
        bool isTapped = selectedTimeSlot == timeSlot;

        timeSlotAsPerDayparts.add(
          GetApptTime(
            selectedTime: timeSlot,
            onTimeSelected: (selectedTime) {
              // Set selected time slot without blocking it immediately
              setState(() {
                selectedTimeSlot = selectedTime; // Store selected time slot
              });
            },
            isTimeSlotBooked: isBooked,
            isTimeSlotBlocked: isBlocked,
            isTimeSlotTapped: isTapped,
          ),
        );
      }
    }
    return timeSlotAsPerDayparts;
  }

  @override
  void initState() {
    super.initState();
    fetchBlockedTimeSlots();
    // Initialize Twilio service
    twilioService = TwilioService(
      accountSID: dotenv.env['TWILIO_ACCOUNT_SID'] ?? '',
      authToken: dotenv.env['TWILIO_AUTH_TOKEN'] ?? '',
      smsTwilioNumber: dotenv.env['TWILIO_PHONE_NUMBER'] ?? '',
      whatsappTwilioNumber: dotenv.env['TWILIO_WHATSAPP_NUMBER'] ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Padding(
          padding: const EdgeInsets.only(top: 30, left: 9),
          child: AppBar(
            backgroundColor: AppStyles.bgColor,
            // This Error isn't Resloving Its getting unable to navigate to the HomeScreen
            // leading: IconButton(
            //   icon: const Icon(Icons.arrow_back),
            //   onPressed: ()=>{}, // Navigate back
            // ),
            title: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Set Appointment',
                      style: TextStyle(
                        color: AppStyles.primary,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    Icon(
                      Icons.mic,
                      color: AppStyles.primary,
                      size: 28,
                    )
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                const LineWidget()
              ],
            ),
          ),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LabelsWidget(label: 'Name'),
                const SizedBox(height: 10),
                InputFieldWidget(
                  defaultHintText: 'Enter Name',
                  controller: nameInput,
                  requiredInput: 'Name',
                  hideText: false,
                ),
                const SizedBox(height: 20),
                const LabelsWidget(label: 'Mobile No.'),
                const SizedBox(height: 10),
                InputFieldWidget(
                  defaultHintText: 'Enter Mobile No.',
                  controller: contactInput,
                  requiredInput: 'Contact No.',
                  hideText: false,
                  // onlyInt: FilteringTextInputFormatter.digitsOnly,
                  // keyBoardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const LabelsWidget(label: 'Date : '),
                    Text(
                      DateFormat.yMMMMd().format(DateTime.now()),
                      style: AppStyles.headLineStyle3
                          .copyWith(color: AppStyles.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                GetApptDate(onDateSelected: (date) {
                  setState(() {
                    selectedDate = date;
                    formattedDate = DateFormat('dd-MM-yyyy').format(date);
                  });
                }),
                const SizedBox(height: 10),
                const LabelsWidget(label: 'Day Part'),
                const SizedBox(height: 10),
                DropdownWidget(
                  itemList: dayPartsList,
                  selectedItem: selectedDayparts,
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedDayparts = newValue;
                    });
                    fetchBlockedTimeSlots();
                  },
                  select: 'Morning',
                ),
                const SizedBox(height: 20),
                const LabelsWidget(label: 'Select Time Slot'),
                const SizedBox(height: 10),
                FutureBuilder<List<Widget>>(
                  future: _buildTimeSlots(),
                  builder: (context, snapshot) {
                    if (selectedDayparts == null) {
                      return Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              width: 180,
                              decoration: BoxDecoration(
                                  // color: Colors.grey.withOpacity(0.3),
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Container(
                              height: 40,
                              width: 180,
                              decoration: BoxDecoration(
                                  // color: Colors.grey.withOpacity(0.3),
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ],
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    } else if (snapshot.hasData) {
                      return Wrap(
                        spacing: 5,
                        children: snapshot.data!,
                      );
                    } else {
                      return const Text('Error loading time slots.');
                    }
                  },
                ),
                const SizedBox(height: 20),
                const LabelsWidget(label: 'Schedule Treatment'),
                const SizedBox(height: 10),
                InputFieldWidget(
                  defaultHintText: 'Schedule Treatment',
                  controller: scheduleTreatmentInput,
                  requiredInput: 'Schedule Treatment',
                  hideText: false,
                  keyBoardType: TextInputType.multiline,
                ),
                const SizedBox(height: 20),
                const LabelsWidget(label: 'Note'),
                const SizedBox(height: 10),
                InputFieldWidget(
                  defaultHintText: 'Additional Notes',
                  controller: noteInput,
                  requiredInput: 'Additional Notes',
                  hideText: false,
                  keyBoardType: TextInputType.multiline,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    fixedSize: const Size(250, 50),
                    backgroundColor: AppStyles.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15), // Adjust the radius value as needed
                    ),
                  ),
                  onPressed: setApptData,
                  child: Text(
                    'Set Appointment',
                    style: AppStyles.headLineStyle3.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
