// lib/features/schedule/presentation/widgets/schedule_calendar.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class ScheduleCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final ValueChanged<DateTime> onDaySelected;

  const ScheduleCalendar({
    super.key,
    required this.focusedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      locale: 'es_ES',
      firstDay: DateTime.now().subtract(const Duration(days: 365)),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: focusedDay,
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13),
        weekendStyle: TextStyle(color: Colors.red[400], fontWeight: FontWeight.bold, fontSize: 13),
        dowTextFormatter: (date, locale) {
          switch (date.weekday) {
            case DateTime.monday: return 'Lun';
            case DateTime.tuesday: return 'Mar';
            case DateTime.wednesday: return 'Mié';
            case DateTime.thursday: return 'Jue';
            case DateTime.friday: return 'Vie';
            case DateTime.saturday: return 'Sáb';
            case DateTime.sunday: return 'Dom';
            default: return '';
          }
        },
      ),
      calendarStyle: CalendarStyle(
        selectedDecoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
        todayDecoration: BoxDecoration(color: Colors.teal[200], shape: BoxShape.circle),
        outsideDaysVisible: false,
        defaultTextStyle: const TextStyle(fontWeight: FontWeight.w500),
        weekendTextStyle: TextStyle(color: Colors.red[300], fontWeight: FontWeight.w500),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
        leftChevronIcon: Icon(Icons.chevron_left, color: Colors.teal),
        rightChevronIcon: Icon(Icons.chevron_right, color: Colors.teal),
      ),
      selectedDayPredicate: (day) => isSameDay(focusedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(this.focusedDay, selectedDay)) {
          onDaySelected(selectedDay);
        }
      },
    );
  }
}