// lib/features/schedule/presentation/widgets/schedule_calendar.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/config/clinic_config.dart';
import '../../../../core/constants/app_colors.dart';

class ScheduleCalendar extends StatelessWidget {
  const ScheduleCalendar({
    super.key,
    required this.focusedDay,
    required this.onDaySelected,
    this.permitirPasado = false,
  });

  final DateTime focusedDay;
  final ValueChanged<DateTime> onDaySelected;

  /// Solo la secretaria y la doctora necesitan mirar dias anteriores.
  final bool permitirPasado;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final config = ClinicConfigService.actual;

    // Antes el calendario abria un ano hacia atras y se podia reservar una
    // cita para el mes pasado.
    final primerDia = permitirPasado
        ? DateTime(hoy.year - 1, hoy.month, hoy.day)
        : DateTime(hoy.year, hoy.month, hoy.day);

    return TableCalendar(
      locale: 'es',
      firstDay: primerDia,
      lastDay: hoy.add(const Duration(days: 365)),
      focusedDay: focusedDay.isBefore(primerDia) ? primerDia : focusedDay,
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableGestures: AvailableGestures.horizontalSwipe,
      enabledDayPredicate: (dia) => config.esDiaHabil(dia),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: const TextStyle(
            color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12.5),
        weekendStyle: TextStyle(
            color: AppColors.textMuted.withValues(alpha: 0.8),
            fontWeight: FontWeight.bold,
            fontSize: 12.5),
      ),
      calendarStyle: CalendarStyle(
        selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        todayDecoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
        outsideDaysVisible: false,
        defaultTextStyle: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        weekendTextStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.75)),
        disabledTextStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.38)),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle:
            TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppColors.primary),
        leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.primary),
        rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.primary),
      ),
      selectedDayPredicate: (day) => isSameDay(focusedDay, day),
      onDaySelected: (selectedDay, _) {
        if (!isSameDay(focusedDay, selectedDay)) onDaySelected(selectedDay);
      },
    );
  }
}
