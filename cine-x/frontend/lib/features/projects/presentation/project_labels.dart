String sceneStatusLabel(String status) {
  return switch (status) {
    'TODO' => 'To do',
    'IN_PROGRESS' => 'In progress',
    'DONE' => 'Done',
    _ => status,
  };
}

String characterRoleLabel(String role) {
  return switch (role) {
    'MAIN' => 'Lead',
    'SUPPORT' => 'Supporting',
    'CROWD' => 'Background',
    _ => role,
  };
}

String settingTypeLabel(String settingType) {
  return switch (settingType) {
    'INT' => 'Interior',
    'EXT' => 'Exterior',
    _ => settingType,
  };
}

String timeOfDayLabel(String timeOfDay) {
  return switch (timeOfDay) {
    'DAY' => 'Day',
    'NIGHT' => 'Night',
    _ => timeOfDay,
  };
}
