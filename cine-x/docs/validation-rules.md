# Validation Rules

Tài liệu này tổng hợp các loại validate đang có trong project CINE-X. Validate được chia theo nơi thực thi: Flutter UI/local repository, Spring Boot backend service/DTO và database constraint.

## Tổng quan

| Loại validate | Nơi áp dụng | Mục đích |
| --- | --- | --- |
| Required/blank | Form, DTO, service, database `NOT NULL` | Không cho lưu dữ liệu bắt buộc bị rỗng |
| Length/format | Form, DTO | Giới hạn độ dài, email, phone, thời gian, tọa độ |
| Numeric range | Form, DTO, service, database `CHECK` | Số thứ tự, số lượng, số phút phải hợp lệ |
| Enum/value set | Form, DTO enum, database `CHECK` | Chỉ nhận các trạng thái/loại đã định nghĩa |
| Uniqueness | Service, repository, database `UNIQUE` | Chặn trùng email, thứ tự hồi, số cảnh, tên cục bộ |
| Relationship/project ownership | Service, repository, foreign key | Dữ liệu liên kết phải thuộc cùng project |
| Permission/role | Backend `ProjectAccessService`, Flutter `PermissionService` | Chỉ role phù hợp được thao tác |
| Business workflow | Service/repository | Chặn trạng thái, lịch quay, tài nguyên, xóa dữ liệu đang dùng |
| File upload | Backend `StorageService`, Flutter image service | Kiểm tra file ảnh, kích thước, MIME type |
| Sync/local-first | DTO, local database | Kiểm tra batch sync, idempotency, local UUID |

## Backend Validation

### DTO annotation validation

Các request body có `@Valid` ở controller sẽ được validate bằng Jakarta Validation. Khi fail, `GlobalExceptionHandler` trả HTTP 400 với code `VALIDATION_ERROR`.

| Module | DTO | Rule |
| --- | --- | --- |
| Auth | `RegisterRequest` | `displayName`: not blank, max 150; `email`: not blank, email, max 255; `password`: not blank, 8-100; `confirmPassword`: not blank |
| Auth | `LoginRequest` | `email`: not blank, email; `password`: not blank |
| Project | `ProjectRequest` | `title`: not blank, max 200; `genre`: max 100; `description`: max 5000; `posterUrl`: max 500; `status`: enum `ACTIVE`, `ARCHIVED` |
| Act | `ActRequest` | `title`: not blank, max 200; `description`: max 5000; `sequenceOrder`: min 1 |
| Act | `ReorderRequest` | `items`: not empty; mỗi item có `actId >= 1`, `sequenceOrder >= 1` |
| Character | `CharacterRequest` | `name`: not blank, max 150; `roleType`: not null enum `MAIN`, `SUPPORT`, `CROWD`; `description`: max 5000 |
| Location | `LocationRequest` | `name`: not blank, max 200; `settingType`: not null enum `INT`, `EXT`; `timeOfDay`: not null enum `DAY`, `NIGHT`; `notes`: max 5000 |
| Scene | `SceneRequest` | `actId`, `locationId`, `status`: not null; `sceneNumber`: min 1; `title`: max 200; `summary`: not blank, max 10000; `estimatedMinutes`: min 1 nếu có |
| Scene | `StatusUpdateRequest` | `status`: not null enum `TODO`, `IN_PROGRESS`, `DONE` |
| Scene | `ReorderRequest` | `items`: not empty; mỗi item có `sceneId` not null, `sceneNumber >= 1` |
| Member | `AddMemberRequest` | `email`: not blank, email; `role`: not null enum `OWNER`, `SCREENWRITER`, `PRODUCER`, `ASSISTANT_DIRECTOR`, `CREW`, `VIEWER` |
| Member | `UpdateMemberRoleRequest` | `role`: not null |
| Sync | `PushRequest` | `deviceId`, `clientBatchId`: not blank; `operations`: not empty |
| Sync | `PushOperation` | `operationId`, `idempotencyKey`, `entityType`, `entityId`, `operation`: not blank; `payload`: not null |

### Backend service/business validation

| Module | Rule |
| --- | --- |
| Auth | Email được trim/lowercase; email không được trùng; login sai email/password trả lỗi; password phải khớp confirm password, dài ít nhất 8 ký tự và có chữ hoa, chữ thường, chữ số |
| Project | `title` sau trim là bắt buộc; field text rỗng được đưa về `null`; project bị xóa mềm không được xem như project visible |
| Permission | Phải đăng nhập; user phải là member của project; `OWNER` mới xóa/restore project và quản lý member; `OWNER`/`SCREENWRITER` được sửa cấu trúc story; `OWNER`/`SCREENWRITER`/`PRODUCER`/`ASSISTANT_DIRECTOR` được cập nhật scene status |
| Member | Không thêm `OWNER` bằng endpoint add member; email member phải tồn tại; user không được trùng trong project; không được hạ quyền hoặc xóa `OWNER` cuối cùng |
| Act | `sequenceOrder >= 1`; title bắt buộc sau trim; `sequenceOrder` không được trùng trong project; reorder không được trùng `actId` hoặc `sequenceOrder`; act reorder phải thuộc project |
| Character | Name bắt buộc sau trim; role bắt buộc; khi upload ảnh dùng chung rule file upload |
| Location | Name, setting, time of day bắt buộc; không được xóa location đang được scene sử dụng |
| Scene | `sceneNumber >= 1`; status bắt buộc; `estimatedMinutes >= 1` nếu có; act/location bắt buộc và phải thuộc project; summary bắt buộc; `sceneNumber` không được trùng trong project; `characterIds` không được trùng và toàn bộ character phải thuộc cùng project; reorder không được trùng `sceneId` hoặc `sceneNumber` |
| Storage | File ảnh bắt buộc, tối đa 5 MB, chỉ hỗ trợ `image/jpeg`, `image/png`, `image/webp` |
| Security | JWT secret phải dài ít nhất 32 bytes |

### Backend database constraints

Backend PostgreSQL/Flyway đang có các constraint chính:

- `users.email` là `UNIQUE` và `NOT NULL`.
- Các bảng chính dùng `PRIMARY KEY`, `NOT NULL`, foreign key tới project/user/act/location/scene.
- `acts`: `UNIQUE(project_id, sequence_order)` và `CHECK(sequence_order >= 1)`.
- `scenes`: `UNIQUE(project_id, scene_number)`, `CHECK(scene_number >= 1)`, `CHECK(estimated_minutes IS NULL OR estimated_minutes > 0)`.
- `scene_characters`: `PRIMARY KEY(scene_id, character_id)` để chặn gắn trùng nhân vật vào một scene.
- Local-first migration thêm unique index cho `client_uuid` trên các bảng sync.
- `sync_idempotency.idempotency_key` là primary key; `sync_change_log.cursor_value` là unique.

## Frontend Validation

### Shared form validators

File chính: `cine-x/frontend/lib/core/validators/form_validators.dart`.

| Validator | Rule |
| --- | --- |
| `FormValidators.requiredTrimmed` | Chuỗi sau trim không được rỗng |
| `FormValidators.lengthRange` | Chuỗi bắt buộc và nằm trong khoảng min-max ký tự |
| `FormValidators.positiveInt` | Phải parse được số nguyên và lớn hơn 0 |
| `FormValidators.optionalPhone` | Có thể rỗng; nếu nhập phải khớp pattern số điện thoại `+`, số, khoảng trắng, dấu chấm hoặc gạch |
| `FormValidators.optionalLatitude` | Latitude có thể rỗng; nếu nhập phải nhập kèm longitude và nằm trong `-90..90` |
| `FormValidators.optionalLongitude` | Longitude có thể rỗng; nếu nhập phải nhập kèm latitude và nằm trong `-180..180` |
| `FormValidators.timeOrder` | Có thể rỗng cả cặp; nếu nhập phải đủ start/end, đúng `HH:mm`, end sau start |
| `ProjectValidators.title` | Tiêu đề dự án 3-100 ký tự |
| `ProjectValidators.dateRange` | Ngày kết thúc không được trước ngày bắt đầu |
| `ProjectValidators.maxMinutes` | Số phút quay tối đa phải là số nguyên dương |
| `ActValidators` | Title hồi bắt buộc; thứ tự là số nguyên dương |
| `CharacterValidators` | Tên nhân vật 2-80 ký tự; role thuộc `MAIN`, `SUPPORT`, `CROWD` |
| `LocationValidators` | Tên bối cảnh truyện, tên địa điểm quay, địa chỉ là bắt buộc |
| `ResourceValidators` | Tên bắt buộc; type thuộc `PROP`, `COSTUME`, `EQUIPMENT`, `VEHICLE`, `OTHER`; số lượng dương; số lượng cần dùng không vượt tổng số lượng |
| `SceneValidators` | Số cảnh dương; phải có title hoặc summary; setting `INT/EXT`; time of day `DAY/NIGHT`; estimated duration dương; writing status `TODO/IN_PROGRESS/DONE`; production status hợp lệ |
| `ShootingDayValidators` | Số phút tối đa dương; ngày quay không được trước ngày bắt đầu dự án |

### Flutter local auth validation

Khi chạy local/offline repository:

- Login báo lỗi nếu email không tồn tại hoặc password sai.
- Register yêu cầu display name không rỗng.
- Email phải có ký tự `@` và không trùng trong local database.
- Password phải có ít nhất 8 ký tự, gồm chữ hoa, chữ thường và số.
- Confirm password phải khớp password.
- Các thao tác cần session sẽ báo lỗi nếu chưa có current user.

### Flutter repository/business validation

File chính: `cine-x/frontend/lib/repositories/cinex_repository.dart`.

| Nhóm | Rule |
| --- | --- |
| Project | Title 3-100 ký tự; date range hợp lệ; max shooting minutes per day dương; phải có quyền tương ứng khi update/delete |
| Act | Title bắt buộc; order dương; order không trùng trong project; act phải thuộc project khi update/delete |
| Character | Tên 2-80 ký tự; role hợp lệ; tên nhân vật không trùng trong project với character chưa archive; character phải thuộc project |
| Story location | Tên bắt buộc; tên bối cảnh truyện không trùng trong project với location chưa archive |
| Shooting location | Tên và địa chỉ bắt buộc; tọa độ phải đi theo cặp và nằm trong range; phone hợp lệ nếu nhập; available time phải đúng thứ tự |
| Resource | Tên bắt buộc; type hợp lệ; quantity total > 0; resource phải active/không archive khi dùng |
| Scene | Số cảnh dương và không trùng; cần chọn hồi và bối cảnh truyện; title hoặc summary bắt buộc; setting/time/status hợp lệ; character/resource không được thêm trùng; các linked entity phải thuộc project; resource required quantity không vượt quantity total |
| Scene workflow | Writing status `DONE` yêu cầu summary; production status `READY_FOR_PLANNING` yêu cầu có planned shooting location; shooting location phải hỗ trợ `INT` hoặc `EXT` theo scene |
| Shooting day | Title bắt buộc; date không trước start date của project; max minutes dương; không sửa ngày quay `COMPLETED` hoặc `CANCELLED` |
| Schedule | Chỉ thêm scene ready và chưa lên lịch; tổng thời lượng không vượt giới hạn ngày quay; tài nguyên trong ngày không vượt tồn kho; planned start/end phải đúng `HH:mm` và end sau start; scene không được lên lịch trùng trong cùng ngày |
| Permission | `PermissionService` chặn thao tác nếu role không có quyền tương ứng |

### Flutter local database constraints

SQLite local schema hỗ trợ thêm các constraint:

- `users.email` unique case-insensitive.
- `project_members.role` check enum role.
- `acts`: `UNIQUE(project_id, sequence_order)`.
- `film_resources.resource_type` check enum resource type.
- `scenes`: check `setting_type`, `time_of_day`, `writing_status`, `production_status`; `UNIQUE(project_id, scene_number)`.
- `scene_characters` và `scene_resources` dùng primary key kép để chặn gắn trùng.
- `shooting_days.status` check enum `DRAFT`, `CONFIRMED`, `IN_PROGRESS`, `COMPLETED`, `CANCELLED`.
- `shooting_day_scenes` có primary key `(shooting_day_id, scene_id)` và unique `(shooting_day_id, sequence_order)`.
- Unique index local cho tên nhân vật active và tên story location active theo project.
- Sync queue có `idempotency_key` unique và operation check enum.

## Error handling

Backend:

- `MethodArgumentNotValidException` -> HTTP 400, code `VALIDATION_ERROR`, có map lỗi theo field.
- `ConstraintViolationException` và `MethodArgumentTypeMismatchException` -> HTTP 400, code `VALIDATION_ERROR`.
- `BadRequestException` -> HTTP 400.
- `ForbiddenException`/Spring `AccessDeniedException` -> HTTP 403.
- `ConflictException` hoặc `DataIntegrityViolationException` -> HTTP 409.
- `NotFoundException` -> HTTP 404.

Frontend:

- Form validate trả message trực tiếp cho field.
- Repository local throw `Exception(message)` để provider/screen hiển thị lỗi.
- API mode nhận lỗi chuẩn từ backend qua `ApiClient`.

## Khi thêm validate mới

- Nếu là rule nhập liệu đơn giản, thêm vào `form_validators.dart` và gắn vào form.
- Nếu rule ảnh hưởng dữ liệu thật, thêm ở backend service hoặc local repository, không chỉ ở UI.
- Nếu rule là bất biến dữ liệu như unique, foreign key, enum quan trọng, thêm cả database constraint.
- Nếu thêm enum mới, cập nhật đồng thời backend enum, Flutter validator/model, SQLite check constraint và tài liệu API/test liên quan.
- Với rule business phức tạp, thêm test ở backend service test hoặc Flutter repository/widget test tương ứng.
