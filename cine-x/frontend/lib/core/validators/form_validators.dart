class FormValidators {
  const FormValidators._();

  static String? requiredTrimmed(String? value, String label) {
    return (value ?? '').trim().isEmpty ? '$label là bắt buộc' : null;
  }

  static String? lengthRange(
    String? value,
    String label, {
    required int min,
    required int max,
  }) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '$label là bắt buộc';
    if (text.length < min || text.length > max) {
      return '$label phải có từ $min-$max ký tự';
    }
    return null;
  }

  static String? positiveInt(String? value, String label) {
    final number = int.tryParse((value ?? '').trim());
    if (number == null || number <= 0) return '$label phải lớn hơn 0';
    return null;
  }

  static String? optionalPhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final valid = RegExp(r'^\+?[0-9][0-9 .-]{7,18}$').hasMatch(text);
    return valid ? null : 'Số điện thoại không hợp lệ';
  }

  static String? optionalLatitude(String? value, String? longitude) {
    final text = (value ?? '').trim();
    final other = (longitude ?? '').trim();
    if (text.isEmpty && other.isEmpty) return null;
    if (text.isEmpty || other.isEmpty) {
      return 'Vĩ độ và kinh độ phải cùng được nhập hoặc cùng để trống';
    }
    final number = double.tryParse(text);
    if (number == null || number < -90 || number > 90) {
      return 'Vĩ độ phải nằm trong khoảng -90 đến 90';
    }
    return null;
  }

  static String? optionalLongitude(String? value, String? latitude) {
    final text = (value ?? '').trim();
    final other = (latitude ?? '').trim();
    if (text.isEmpty && other.isEmpty) return null;
    if (text.isEmpty || other.isEmpty) {
      return 'Vĩ độ và kinh độ phải cùng được nhập hoặc cùng để trống';
    }
    final number = double.tryParse(text);
    if (number == null || number < -180 || number > 180) {
      return 'Kinh độ phải nằm trong khoảng -180 đến 180';
    }
    return null;
  }

  static String? timeOrder(String? start, String? end) {
    final hasStart = (start ?? '').trim().isNotEmpty;
    final hasEnd = (end ?? '').trim().isNotEmpty;
    if (!hasStart && !hasEnd) return null;
    final from = _timeToMinutes(start);
    final to = _timeToMinutes(end);
    if (hasStart != hasEnd) return 'Nhập đủ giờ bắt đầu và kết thúc';
    if (from == null || to == null) return 'Giờ phải theo định dạng HH:mm';
    return to <= from ? 'Giờ kết thúc phải sau giờ bắt đầu' : null;
  }

  static int? _timeToMinutes(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }
}

class ProjectValidators {
  const ProjectValidators._();

  static String? title(String? value) =>
      FormValidators.lengthRange(value, 'Tiêu đề dự án', min: 3, max: 100);

  static String? maxMinutes(String? value) =>
      FormValidators.positiveInt(value, 'Số phút quay tối đa');

  static String? dateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      return 'Ngày kết thúc không được trước ngày bắt đầu';
    }
    return null;
  }
}

class ActValidators {
  const ActValidators._();

  static String? title(String? value) =>
      FormValidators.requiredTrimmed(value, 'Tiêu đề hồi');

  static String? sequenceOrder(String? value) =>
      FormValidators.positiveInt(value, 'Thứ tự');
}

class CharacterValidators {
  const CharacterValidators._();

  static const validRoleTypes = {'MAIN', 'SUPPORT', 'CROWD'};

  static String? name(String? value) =>
      FormValidators.lengthRange(value, 'Tên nhân vật', min: 2, max: 80);

  static String? roleType(String? value) {
    return validRoleTypes.contains(value) ? null : 'Vai trò không hợp lệ';
  }
}

class LocationValidators {
  const LocationValidators._();

  static String? storyLocationName(String? value) =>
      FormValidators.requiredTrimmed(value, 'Tên bối cảnh truyện');

  static String? shootingLocationName(String? value) =>
      FormValidators.requiredTrimmed(value, 'Tên địa điểm quay');

  static String? shootingAddress(String? value) =>
      FormValidators.requiredTrimmed(value, 'Địa chỉ');
}

class ResourceValidators {
  const ResourceValidators._();

  static const validTypes = {'PROP', 'COSTUME', 'EQUIPMENT', 'VEHICLE', 'OTHER'};

  static String? name(String? value) =>
      FormValidators.requiredTrimmed(value, 'Tên tài nguyên');

  static String? type(String? value) {
    return validTypes.contains(value) ? null : 'Loại tài nguyên là bắt buộc';
  }

  static String? quantity(String? value) =>
      FormValidators.positiveInt(value, 'Số lượng');

  static String? requiredQuantity({
    required int requiredQuantity,
    required int totalQuantity,
  }) {
    if (requiredQuantity <= 0) return 'Số lượng cần dùng phải lớn hơn 0';
    if (requiredQuantity > totalQuantity) {
      return 'Số lượng cần dùng không được vượt quá tổng số lượng';
    }
    return null;
  }
}

class SceneValidators {
  const SceneValidators._();

  static const settingTypes = {'INT', 'EXT'};
  static const timeOfDayValues = {'DAY', 'NIGHT'};
  static const writingStatuses = {'TODO', 'IN_PROGRESS', 'DONE'};
  static const productionStatuses = {
    'NOT_READY',
    'READY_FOR_PLANNING',
    'SCHEDULED',
    'SHOOTING',
    'SHOT',
    'CANCELLED',
  };

  static String? sceneNumber(String? value) =>
      FormValidators.positiveInt(value, 'Số cảnh');

  static String? titleOrSummary(String? title, String? summary) {
    final hasTitle = (title ?? '').trim().isNotEmpty;
    final hasSummary = (summary ?? '').trim().isNotEmpty;
    return hasTitle || hasSummary ? null : 'Cần nhập tiêu đề hoặc tóm tắt';
  }

  static String? settingType(String? value) {
    return settingTypes.contains(value) ? null : 'Bối cảnh phải là INT hoặc EXT';
  }

  static String? timeOfDay(String? value) {
    return timeOfDayValues.contains(value) ? null : 'Thời điểm phải là DAY hoặc NIGHT';
  }

  static String? estimatedDuration(String? value) =>
      FormValidators.positiveInt(value, 'Thời lượng ước tính');
}

class ShootingDayValidators {
  const ShootingDayValidators._();

  static String? maxMinutes(String? value) =>
      FormValidators.positiveInt(value, 'Số phút tối đa');

  static String? dateWithinProject(DateTime date, DateTime? projectStartDate) {
    if (projectStartDate != null && date.isBefore(projectStartDate)) {
      return 'Ngày không được trước ngày bắt đầu dự án';
    }
    return null;
  }
}
