String sceneStatusLabel(String status) {
  return switch (status) {
    'TODO' => 'Cần viết',
    'IN_PROGRESS' => 'Đang viết',
    'DONE' => 'Hoàn tất',
    _ => status,
  };
}

String productionStatusLabel(String status) {
  return switch (status) {
    'NOT_READY' => 'Chưa sẵn sàng',
    'READY_FOR_PLANNING' => 'Sẵn sàng lên lịch',
    'SCHEDULED' => 'Đã lên lịch',
    'SHOOTING' => 'Đang quay',
    'SHOT' => 'Đã quay',
    'CANCELLED' => 'Đã hủy',
    _ => status,
  };
}

String characterRoleLabel(String role) {
  return switch (role) {
    'MAIN' => 'Vai chính',
    'SUPPORT' => 'Vai phụ',
    'CROWD' => 'Quần chúng',
    _ => role,
  };
}

String projectRoleLabel(String role) {
  return switch (role) {
    'OWNER' => 'Chủ dự án',
    'SCREENWRITER' => 'Biên kịch',
    'PRODUCER' => 'Nhà sản xuất',
    'ASSISTANT_DIRECTOR' => 'Trợ lý đạo diễn',
    'CREW' => 'Đoàn phim',
    'VIEWER' => 'Chỉ xem',
    _ => role,
  };
}

String settingTypeLabel(String settingType) {
  return switch (settingType) {
    'INT' => 'Nội cảnh',
    'EXT' => 'Ngoại cảnh',
    _ => settingType,
  };
}

String timeOfDayLabel(String timeOfDay) {
  return switch (timeOfDay) {
    'DAY' => 'Ngày',
    'NIGHT' => 'Đêm',
    _ => timeOfDay,
  };
}

String resourceTypeLabel(String type) {
  return switch (type) {
    'PROP' => 'Đạo cụ',
    'COSTUME' => 'Trang phục',
    'EQUIPMENT' => 'Thiết bị',
    'VEHICLE' => 'Phương tiện',
    'OTHER' => 'Khác',
    _ => type,
  };
}

String shootingDayStatusLabel(String status) {
  return switch (status) {
    'DRAFT' => 'Nháp',
    'CONFIRMED' => 'Đã xác nhận',
    'IN_PROGRESS' => 'Đang quay',
    'COMPLETED' => 'Hoàn tất',
    'CANCELLED' => 'Đã hủy',
    _ => status,
  };
}

String projectStatusLabel(String status) {
  return switch (status) {
    'ACTIVE' => 'Đang hoạt động',
    'ARCHIVED' => 'Đã lưu trữ',
    _ => status,
  };
}

String resourceStatusLabel(String status) {
  return switch (status) {
    'AVAILABLE' => 'Sẵn sàng',
    'RESERVED' => 'Đã giữ',
    'IN_USE' => 'Đang dùng',
    'DAMAGED' => 'Hỏng',
    'UNAVAILABLE' => 'Không khả dụng',
    _ => status,
  };
}
