import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DatePickerEditText extends StatefulWidget {

  final Function(DateTime) onDateSelected;

  DatePickerEditText({required this.onDateSelected});

  @override
  _DatePickerEditTextState createState() => _DatePickerEditTextState();
}

class _DatePickerEditTextState extends State<DatePickerEditText> {
  TextEditingController _dateController = TextEditingController();

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2025),
    );
    if (picked != null) {
      setState(() {
        // Use DateFormat to format the date as you need
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
        widget.onDateSelected(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextField(
        controller: _dateController,
        decoration: InputDecoration(hintText: 'Select a date'),
        readOnly: true, // To prevent manual editing
        onTap: () => _selectDate(context), // Open date picker on tap
      ),
    );
  }
}