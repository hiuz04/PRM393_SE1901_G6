package com.cinex.service;

import com.cinex.domain.ProjectRole;
import com.cinex.domain.UserAccount;
import com.cinex.dto.SyncDtos.PullChange;
import com.cinex.dto.SyncDtos.PullResponse;
import com.cinex.dto.SyncDtos.PushOperation;
import com.cinex.dto.SyncDtos.PushRequest;
import com.cinex.dto.SyncDtos.PushResponse;
import com.cinex.dto.SyncDtos.PushResult;
import com.cinex.exception.BadRequestException;
import com.cinex.exception.ForbiddenException;
import com.cinex.exception.NotFoundException;
import com.cinex.repository.UserRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SyncService {
    private static final int PULL_LIMIT = 100;
    private static final int PULL_SCAN_LIMIT = 500;
    private static final TypeReference<Map<String, Object>> MAP_TYPE = new TypeReference<>() {
    };

    private final JdbcTemplate jdbc;
    private final ObjectMapper objectMapper;
    private final ProjectAccessService accessService;
    private final UserRepository userRepository;

    public SyncService(
            JdbcTemplate jdbc,
            ObjectMapper objectMapper,
            ProjectAccessService accessService,
            UserRepository userRepository
    ) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
        this.accessService = accessService;
        this.userRepository = userRepository;
    }

    @Transactional
    public PushResponse push(PushRequest request) {
        UserAccount currentUser = accessService.currentUser();
        BatchContext context = new BatchContext(currentUser.getId());
        List<PushResult> results = new ArrayList<>();
        for (PushOperation operation : request.operations()) {
            PushResult cached = readIdempotentResult(operation.idempotencyKey(), currentUser.getId());
            if (cached != null) {
                results.add(cached);
                continue;
            }
            PushResult result = applyOperation(operation, context);
            writeIdempotentResult(operation, currentUser.getId(), result);
            results.add(result);
        }
        return new PushResponse(results, null);
    }

    @Transactional(readOnly = true)
    public PullResponse pull(String cursor) {
        UserAccount currentUser = accessService.currentUser();
        long afterId = parseCursor(cursor);
        List<Map<String, Object>> rows = jdbc.queryForList(
                """
                SELECT scl.id, scl.cursor_value, scl.entity_type, scl.entity_id,
                       scl.operation, scl.server_version, scl.payload_json,
                       scl.created_at, scl.project_id
                FROM sync_change_log scl
                WHERE scl.id > ?
                ORDER BY scl.id ASC
                LIMIT ?
                """,
                afterId,
                PULL_SCAN_LIMIT
        );
        List<PullChange> changes = new ArrayList<>();
        String nextCursor = cursor;
        boolean hasMore = rows.size() == PULL_SCAN_LIMIT;
        for (Map<String, Object> row : rows) {
            Map<String, Object> payload = readPayload(row.get("payload_json"));
            if (!canReceiveChange(row, payload, currentUser.getId())) {
                nextCursor = row.get("id").toString();
                continue;
            }
            if (changes.size() >= PULL_LIMIT) {
                hasMore = true;
                break;
            }
            UUID entityId = (UUID) row.get("entity_id");
            long serverVersion = number(row.get("server_version")).longValue();
            Instant updatedAt = instant(row.get("created_at"));
            changes.add(new PullChange(
                    row.get("entity_type").toString(),
                    entityId.toString(),
                    row.get("operation").toString(),
                    serverVersion,
                    updatedAt,
                    payload
            ));
            nextCursor = row.get("id").toString();
        }
        return new PullResponse(changes, nextCursor, hasMore);
    }

    private boolean canReceiveChange(Map<String, Object> row, Map<String, Object> payload, Long userId) {
        Long projectId = longObject(row, "project_id");
        if (projectId == null) return false;
        String entityType = row.get("entity_type").toString();
        String operation = row.get("operation").toString();
        if ("PROJECT_MEMBER".equals(entityType)) {
            Long targetUserId = longObject(payload, "user_id", "userId");
            if ("DELETE".equals(operation) && userId.equals(targetUserId)) {
                return true;
            }
        }
        if ("PROJECT".equals(entityType) && "DELETE".equals(operation)) {
            return isProjectMember(projectId, userId);
        }
        return !isProjectDeleted(projectId) && isProjectMember(projectId, userId);
    }

    private PushResult applyOperation(PushOperation operation, BatchContext context) {
        try {
            String entityType = operation.entityType().trim().toUpperCase(Locale.ROOT);
            String action = operation.operation().trim().toUpperCase(Locale.ROOT);
            if (!isSupported(entityType)) {
                return PushResult.rejected(
                        operation.operationId(),
                        "REJECTED",
                        "Server chua ho tro dong bo entity " + entityType
                );
            }
            if ("UPLOAD_FILE".equals(action)) {
                return PushResult.rejected(
                        operation.operationId(),
                        "REJECTED",
                        "Server chua ho tro dong bo file trong API sync"
                );
            }
            UUID clientUuid = UUID.fromString(operation.entityId());
            AppliedEntity applied = switch (action) {
                case "CREATE", "UPDATE" -> upsert(entityType, clientUuid, operation.payload(), operation.baseVersion(), context);
                case "DELETE" -> delete(entityType, clientUuid, operation.payload(), context);
                default -> throw new BadRequestException("Sync operation khong hop le: " + action);
            };
            writeChangeLog(applied.projectId(), entityType, clientUuid, action, applied.serverVersion(), applied.payload());
            return PushResult.applied(
                    operation.operationId(),
                    applied.remoteId(),
                    applied.serverVersion(),
                    applied.updatedAt()
            );
        } catch (BadRequestException | NotFoundException ex) {
            return PushResult.rejected(operation.operationId(), "VALIDATION_ERROR", ex.getMessage());
        } catch (ForbiddenException ex) {
            return PushResult.rejected(operation.operationId(), "UNAUTHORIZED", ex.getMessage());
        } catch (ConflictDetected ex) {
            return new PushResult(
                    operation.operationId(),
                    "CONFLICT",
                    ex.remoteId(),
                    ex.serverVersion(),
                    Instant.now(),
                    ex.getMessage(),
                    ex.remotePayload(),
                    ex.conflictingFields()
            );
        } catch (IllegalArgumentException ex) {
            return PushResult.rejected(operation.operationId(), "VALIDATION_ERROR", ex.getMessage());
        } catch (DataAccessException ex) {
            return PushResult.rejected(operation.operationId(), "DEPENDENCY_ERROR", rootMessage(ex));
        }
    }

    private AppliedEntity upsert(
            String entityType,
            UUID clientUuid,
            Map<String, Object> payload,
            Long baseVersion,
            BatchContext context
    ) {
        return switch (entityType) {
            case "PROJECT" -> upsertProject(clientUuid, payload, baseVersion, context);
            case "PROJECT_MEMBER" -> upsertProjectMember(clientUuid, payload, baseVersion, context);
            case "ACT" -> upsertAct(clientUuid, payload, baseVersion, context);
            case "CHARACTER" -> upsertCharacter(clientUuid, payload, baseVersion, context);
            case "STORY_LOCATION" -> upsertLocation(clientUuid, payload, baseVersion, context);
            case "SCENE" -> upsertScene(clientUuid, payload, baseVersion, context);
            default -> throw new BadRequestException("Entity khong ho tro: " + entityType);
        };
    }

    private AppliedEntity delete(
            String entityType,
            UUID clientUuid,
            Map<String, Object> payload,
            BatchContext context
    ) {
        return switch (entityType) {
            case "PROJECT" -> deleteProject(clientUuid, payload, context);
            case "PROJECT_MEMBER" -> deleteProjectMember(clientUuid, payload, context);
            case "ACT" -> deleteByClientUuid("acts", entityType, clientUuid, context);
            case "CHARACTER" -> deleteCharacter(clientUuid, context);
            case "STORY_LOCATION" -> deleteLocation(clientUuid, context);
            case "SCENE" -> deleteScene(clientUuid, context);
            default -> throw new BadRequestException("Entity khong ho tro: " + entityType);
        };
    }

    private AppliedEntity upsertProject(
            UUID clientUuid,
            Map<String, Object> payload,
            Long baseVersion,
            BatchContext context
    ) {
        Map<String, Object> existing = rowByClientUuid("projects", clientUuid);
        Instant now = Instant.now();
        Long serverId;
        long version;
        if (existing == null) {
            String title = requiredText(payload, "title");
            KeyHolder keyHolder = new GeneratedKeyHolder();
            jdbc.update(connection -> {
                PreparedStatement ps = connection.prepareStatement(
                        """
                        INSERT INTO projects(
                          owner_id, title, genre, description, start_date, poster_url,
                          status, deleted, created_at, updated_at, version,
                          client_uuid, remote_id, server_version, deleted_at
                        )
                        VALUES (?, ?, ?, ?, ?, ?, 'ACTIVE', FALSE, ?, ?, 0, ?, ?, 1, NULL)
                        """,
                        new String[]{"id"}
                );
                ps.setLong(1, context.userId());
                ps.setString(2, title);
                ps.setObject(3, text(payload, "genre"));
                ps.setObject(4, text(payload, "description"));
                ps.setObject(5, sqlDate(payload.get("start_date")));
                ps.setObject(6, text(payload, "poster_url"));
                ps.setTimestamp(7, timestampOrNow(payload.get("created_at"), now));
                ps.setTimestamp(8, timestamp(now));
                ps.setObject(9, clientUuid);
                ps.setString(10, clientUuid.toString());
                return ps;
            }, keyHolder);
            serverId = keyHolderId(keyHolder);
            ensureOwnerMembership(serverId, context.userId(), now);
            version = 1;
        } else {
            serverId = number(existing.get("id")).longValue();
            accessService.requireOwner(serverId);
            assertCurrentVersion(clientUuid, "projects", baseVersion, "PROJECT");
            version = bumpVersion("projects", clientUuid);
            jdbc.update(
                    """
                    UPDATE projects
                    SET title = ?, genre = ?, description = ?, start_date = ?,
                        poster_url = ?, deleted = FALSE, updated_at = ?,
                        remote_id = ?, server_version = ?
                    WHERE client_uuid = ?
                    """,
                    requiredText(payload, "title"),
                    text(payload, "genre"),
                    text(payload, "description"),
                    sqlDate(payload.get("start_date")),
                    text(payload, "poster_url"),
                    timestamp(now),
                    clientUuid.toString(),
                    version,
                    clientUuid
            );
        }
        context.remember("PROJECT", localId(payload), serverId, clientUuid);
        return applied("PROJECT", clientUuid, serverId, version, now);
    }

    private AppliedEntity upsertProjectMember(
            UUID clientUuid,
            Map<String, Object> payload,
            Long baseVersion,
            BatchContext context
    ) {
        Long projectId = resolveProjectId(payload, context);
        accessService.requireOwner(projectId);
        UserAccount targetUser = resolveMemberUser(payload, context.userId());
        ProjectRole role = role(payload);
        if (role == ProjectRole.OWNER && !targetUser.getId().equals(context.userId())) {
            throw new BadRequestException("Khong them OWNER bang dong bo member");
        }
        Map<String, Object> existing = memberByClientUuid(clientUuid);
        if (existing == null) {
            existing = memberByProjectAndUser(projectId, targetUser.getId());
        }
        if (existing != null && baseVersion != null
                && number(existing.get("server_version")).longValue() > baseVersion) {
            throw new ConflictDetected(
                    "Du lieu tren server moi hon ban cuc bo",
                    clientUuid.toString(),
                    number(existing.get("server_version")).longValue(),
                    memberPayload(existing, number(existing.get("server_version")).longValue(), null),
                    List.of()
            );
        }
        Instant now = Instant.now();
        long version;
        if (existing == null) {
            version = 1;
            jdbc.update(
                    """
                    INSERT INTO project_members(
                      project_id, user_id, role, joined_at, client_uuid,
                      server_version, deleted_at, created_at, updated_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?)
                    """,
                    projectId,
                    targetUser.getId(),
                    role.name(),
                    timestamp(now),
                    clientUuid,
                    version,
                    timestamp(now),
                    timestamp(now)
            );
        } else {
            version = number(existing.get("server_version")).longValue() + 1;
            jdbc.update(
                    """
                    UPDATE project_members
                    SET role = ?, client_uuid = ?, server_version = ?,
                        deleted_at = NULL, updated_at = ?
                    WHERE project_id = ? AND user_id = ?
                    """,
                    role.name(),
                    clientUuid,
                    version,
                    timestamp(now),
                    projectId,
                    targetUser.getId()
            );
        }
        context.remember("PROJECT_MEMBER", localId(payload), targetUser.getId(), clientUuid);
        Map<String, Object> saved = memberByProjectAndUser(projectId, targetUser.getId());
        return new AppliedEntity(clientUuid.toString(), version, now, projectId, memberPayload(saved, version, null));
    }

    private AppliedEntity upsertAct(
            UUID clientUuid,
            Map<String, Object> payload,
            Long baseVersion,
            BatchContext context
    ) {
        Long projectId = resolveProjectId(payload, context);
        accessService.requireStructureEditor(projectId);
        Map<String, Object> existing = rowByClientUuid("acts", clientUuid);
        Instant now = Instant.now();
        long version;
        Long serverId;
        if (existing == null) {
            version = 1;
            KeyHolder keyHolder = new GeneratedKeyHolder();
            jdbc.update(connection -> {
                PreparedStatement ps = connection.prepareStatement(
                        """
                        INSERT INTO acts(
                          project_id, title, description, sequence_order,
                          created_at, updated_at, client_uuid, server_version, deleted_at
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)
                        """,
                        new String[]{"id"}
                );
                ps.setLong(1, projectId);
                ps.setString(2, requiredText(payload, "title"));
                ps.setObject(3, text(payload, "description"));
                ps.setInt(4, intValue(payload, "sequence_order", "sequenceOrder", 1));
                ps.setTimestamp(5, timestampOrNow(payload.get("created_at"), now));
                ps.setTimestamp(6, timestamp(now));
                ps.setObject(7, clientUuid);
                ps.setLong(8, version);
                return ps;
            }, keyHolder);
            serverId = keyHolderId(keyHolder);
        } else {
            assertCurrentVersion(clientUuid, "acts", baseVersion, "ACT");
            serverId = number(existing.get("id")).longValue();
            version = bumpVersion("acts", clientUuid);
            jdbc.update(
                    """
                    UPDATE acts
                    SET title = ?, description = ?, sequence_order = ?,
                        updated_at = ?, server_version = ?, deleted_at = NULL
                    WHERE client_uuid = ?
                    """,
                    requiredText(payload, "title"),
                    text(payload, "description"),
                    intValue(payload, "sequence_order", "sequenceOrder", 1),
                    timestamp(now),
                    version,
                    clientUuid
            );
        }
        context.remember("ACT", localId(payload), serverId, clientUuid);
        return applied("ACT", clientUuid, serverId, version, now);
    }

    private AppliedEntity upsertCharacter(
            UUID clientUuid,
            Map<String, Object> payload,
            Long baseVersion,
            BatchContext context
    ) {
        Long projectId = resolveProjectId(payload, context);
        accessService.requireStructureEditor(projectId);
        Map<String, Object> existing = rowByClientUuid("characters", clientUuid);
        Instant now = Instant.now();
        long version;
        Long serverId;
        if (existing == null) {
            version = 1;
            KeyHolder keyHolder = new GeneratedKeyHolder();
            jdbc.update(connection -> {
                PreparedStatement ps = connection.prepareStatement(
                        """
                        INSERT INTO characters(
                          project_id, name, role_type, description, image_url,
                          created_at, updated_at, client_uuid, server_version,
                          deleted_at, image_remote_url, image_checksum
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL)
                        """,
                        new String[]{"id"}
                );
                ps.setLong(1, projectId);
                ps.setString(2, requiredText(payload, "name"));
                ps.setString(3, textOrDefault(payload, "role_type", "roleType", "SUPPORT"));
                ps.setObject(4, text(payload, "psychological_description", "description"));
                ps.setObject(5, text(payload, "image_path", "imageUrl"));
                ps.setTimestamp(6, timestampOrNow(payload.get("created_at"), now));
                ps.setTimestamp(7, timestamp(now));
                ps.setObject(8, clientUuid);
                ps.setLong(9, version);
                return ps;
            }, keyHolder);
            serverId = keyHolderId(keyHolder);
        } else {
            assertCurrentVersion(clientUuid, "characters", baseVersion, "CHARACTER");
            serverId = number(existing.get("id")).longValue();
            version = bumpVersion("characters", clientUuid);
            jdbc.update(
                    """
                    UPDATE characters
                    SET name = ?, role_type = ?, description = ?, image_url = ?,
                        updated_at = ?, server_version = ?, deleted_at = NULL
                    WHERE client_uuid = ?
                    """,
                    requiredText(payload, "name"),
                    textOrDefault(payload, "role_type", "roleType", "SUPPORT"),
                    text(payload, "psychological_description", "description"),
                    text(payload, "image_path", "imageUrl"),
                    timestamp(now),
                    version,
                    clientUuid
            );
        }
        context.remember("CHARACTER", localId(payload), serverId, clientUuid);
        return applied("CHARACTER", clientUuid, serverId, version, now);
    }

    private AppliedEntity upsertLocation(
            UUID clientUuid,
            Map<String, Object> payload,
            Long baseVersion,
            BatchContext context
    ) {
        Long projectId = resolveProjectId(payload, context);
        accessService.requireStructureEditor(projectId);
        Map<String, Object> existing = rowByClientUuid("locations", clientUuid);
        Instant now = Instant.now();
        long version;
        Long serverId;
        if (existing == null) {
            version = 1;
            KeyHolder keyHolder = new GeneratedKeyHolder();
            jdbc.update(connection -> {
                PreparedStatement ps = connection.prepareStatement(
                        """
                        INSERT INTO locations(
                          project_id, name, setting_type, time_of_day, notes,
                          created_at, updated_at, client_uuid, server_version, deleted_at
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
                        """,
                        new String[]{"id"}
                );
                ps.setLong(1, projectId);
                ps.setString(2, requiredText(payload, "name"));
                ps.setString(3, textOrDefault(payload, "setting_type", "settingType", "INT"));
                ps.setString(4, textOrDefault(payload, "time_of_day", "timeOfDay", "DAY"));
                ps.setObject(5, text(payload, "notes", "description"));
                ps.setTimestamp(6, timestampOrNow(payload.get("created_at"), now));
                ps.setTimestamp(7, timestamp(now));
                ps.setObject(8, clientUuid);
                ps.setLong(9, version);
                return ps;
            }, keyHolder);
            serverId = keyHolderId(keyHolder);
        } else {
            assertCurrentVersion(clientUuid, "locations", baseVersion, "STORY_LOCATION");
            serverId = number(existing.get("id")).longValue();
            version = bumpVersion("locations", clientUuid);
            jdbc.update(
                    """
                    UPDATE locations
                    SET name = ?, setting_type = ?, time_of_day = ?, notes = ?,
                        updated_at = ?, server_version = ?, deleted_at = NULL
                    WHERE client_uuid = ?
                    """,
                    requiredText(payload, "name"),
                    textOrDefault(payload, "setting_type", "settingType", "INT"),
                    textOrDefault(payload, "time_of_day", "timeOfDay", "DAY"),
                    text(payload, "notes", "description"),
                    timestamp(now),
                    version,
                    clientUuid
            );
        }
        context.remember("STORY_LOCATION", localId(payload), serverId, clientUuid);
        return applied("STORY_LOCATION", clientUuid, serverId, version, now);
    }

    private AppliedEntity upsertScene(
            UUID clientUuid,
            Map<String, Object> payload,
            Long baseVersion,
            BatchContext context
    ) {
        Long projectId = resolveProjectId(payload, context);
        accessService.requireStructureEditor(projectId);
        Long actId = resolveRelatedId("ACT", "acts", payload, "act_id", "act_client_uuid", context);
        Long locationId = resolveRelatedId("STORY_LOCATION", "locations", payload, "story_location_id", "story_location_client_uuid", context);
        Map<String, Object> existing = rowByClientUuid("scenes", clientUuid);
        Instant now = Instant.now();
        long version;
        Long serverId;
        if (existing == null) {
            version = 1;
            KeyHolder keyHolder = new GeneratedKeyHolder();
            jdbc.update(connection -> {
                PreparedStatement ps = connection.prepareStatement(
                        """
                        INSERT INTO scenes(
                          project_id, act_id, location_id, scene_number, title,
                          summary, status, estimated_minutes, created_at,
                          updated_at, client_uuid, server_version, deleted_at
                        )
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
                        """,
                        new String[]{"id"}
                );
                ps.setLong(1, projectId);
                ps.setLong(2, actId);
                ps.setLong(3, locationId);
                ps.setInt(4, intValue(payload, "scene_number", "sceneNumber", 1));
                ps.setObject(5, text(payload, "title"));
                ps.setString(6, requiredText(payload, "summary"));
                ps.setString(7, textOrDefault(payload, "writing_status", "status", "TODO"));
                ps.setObject(8, intObject(payload, "estimated_duration_minutes", "estimatedMinutes"));
                ps.setTimestamp(9, timestampOrNow(payload.get("created_at"), now));
                ps.setTimestamp(10, timestamp(now));
                ps.setObject(11, clientUuid);
                ps.setLong(12, version);
                return ps;
            }, keyHolder);
            serverId = keyHolderId(keyHolder);
        } else {
            assertCurrentVersion(clientUuid, "scenes", baseVersion, "SCENE");
            serverId = number(existing.get("id")).longValue();
            version = bumpVersion("scenes", clientUuid);
            jdbc.update(
                    """
                    UPDATE scenes
                    SET act_id = ?, location_id = ?, scene_number = ?, title = ?,
                        summary = ?, status = ?, estimated_minutes = ?,
                        updated_at = ?, server_version = ?, deleted_at = NULL
                    WHERE client_uuid = ?
                    """,
                    actId,
                    locationId,
                    intValue(payload, "scene_number", "sceneNumber", 1),
                    text(payload, "title"),
                    requiredText(payload, "summary"),
                    textOrDefault(payload, "writing_status", "status", "TODO"),
                    intObject(payload, "estimated_duration_minutes", "estimatedMinutes"),
                    timestamp(now),
                    version,
                    clientUuid
            );
        }
        syncSceneCharacters(serverId, payload);
        context.remember("SCENE", localId(payload), serverId, clientUuid);
        return applied("SCENE", clientUuid, serverId, version, now);
    }

    private void syncSceneCharacters(Long sceneId, Map<String, Object> payload) {
        Object raw = payload.get("character_client_uuids");
        if (!(raw instanceof List<?> values)) return;
        jdbc.update("DELETE FROM scene_characters WHERE scene_id = ?", sceneId);
        for (Object value : values) {
            if (value == null || value.toString().isBlank()) continue;
            Long characterId = idByClientUuid("characters", UUID.fromString(value.toString()));
            if (characterId == null) continue;
            jdbc.update(
                    "INSERT INTO scene_characters(scene_id, character_id) VALUES (?, ?) ON CONFLICT DO NOTHING",
                    sceneId,
                    characterId
            );
        }
    }

    private AppliedEntity deleteProject(UUID clientUuid, Map<String, Object> payload, BatchContext context) {
        Map<String, Object> existing = rowByClientUuid("projects", clientUuid);
        if (existing == null) {
            Long fallbackId = context.lookupLocal("PROJECT", localId(payload));
            if (fallbackId == null) throw new NotFoundException("Khong tim thay project de xoa");
            existing = rowById("projects", fallbackId);
        }
        Long projectId = number(existing.get("id")).longValue();
        accessService.requireOwner(projectId);
        Instant now = Instant.now();
        long version = number(existing.get("server_version")).longValue() + 1;
        jdbc.update(
                """
                UPDATE projects
                SET deleted = TRUE, deleted_at = ?, updated_at = ?, server_version = ?
                WHERE id = ?
                """,
                timestamp(now),
                timestamp(now),
                version,
                projectId
        );
        Map<String, Object> deletionPayload = payloadFor("PROJECT", projectId);
        return new AppliedEntity(clientUuid.toString(), version, now, projectId, deletionPayload);
    }

    private AppliedEntity deleteProjectMember(UUID clientUuid, Map<String, Object> payload, BatchContext context) {
        Map<String, Object> existing = memberByClientUuid(clientUuid);
        Long projectId = existing == null ? resolveProjectId(payload, context) : number(existing.get("project_id")).longValue();
        accessService.requireOwner(projectId);
        if (existing == null) {
            UserAccount targetUser = resolveMemberUser(payload, context.userId());
            existing = memberByProjectAndUser(projectId, targetUser.getId());
        }
        if (existing == null) {
            throw new NotFoundException("Khong tim thay thanh vien de xoa");
        }
        ProjectRole role = ProjectRole.valueOf(existing.get("role").toString());
        if (role == ProjectRole.OWNER && ownerCount(projectId) <= 1) {
            throw new BadRequestException("Khong the xoa OWNER cuoi cung");
        }
        Instant now = Instant.now();
        long version = number(existing.get("server_version")).longValue() + 1;
        Map<String, Object> deletionPayload = memberPayload(existing, version, now);
        jdbc.update(
                "DELETE FROM project_members WHERE project_id = ? AND user_id = ?",
                existing.get("project_id"),
                existing.get("user_id")
        );
        return new AppliedEntity(clientUuid.toString(), version, now, projectId, deletionPayload);
    }

    private AppliedEntity deleteByClientUuid(String table, String entityType, UUID clientUuid, BatchContext context) {
        Map<String, Object> existing = rowByClientUuid(table, clientUuid);
        if (existing == null) {
            throw new NotFoundException("Khong tim thay " + entityType + " de xoa");
        }
        Long projectId = number(existing.get("project_id")).longValue();
        accessService.requireStructureEditor(projectId);
        Instant now = Instant.now();
        long version = number(existing.get("server_version")).longValue() + 1;
        Map<String, Object> deletionPayload = payloadFor(entityType, number(existing.get("id")).longValue());
        deletionPayload.put("deleted_at", now.toString());
        jdbc.update("DELETE FROM " + table + " WHERE client_uuid = ?", clientUuid);
        return new AppliedEntity(clientUuid.toString(), version, now, projectId, deletionPayload);
    }

    private AppliedEntity deleteCharacter(UUID clientUuid, BatchContext context) {
        Map<String, Object> existing = rowByClientUuid("characters", clientUuid);
        if (existing == null) throw new NotFoundException("Khong tim thay CHARACTER de xoa");
        Long characterId = number(existing.get("id")).longValue();
        jdbc.update("DELETE FROM scene_characters WHERE character_id = ?", characterId);
        return deleteByClientUuid("characters", "CHARACTER", clientUuid, context);
    }

    private AppliedEntity deleteLocation(UUID clientUuid, BatchContext context) {
        Map<String, Object> existing = rowByClientUuid("locations", clientUuid);
        if (existing == null) throw new NotFoundException("Khong tim thay STORY_LOCATION de xoa");
        if (count("SELECT COUNT(*) FROM scenes WHERE location_id = ?", existing.get("id")) > 0) {
            Long projectId = number(existing.get("project_id")).longValue();
            accessService.requireStructureEditor(projectId);
            Instant now = Instant.now();
            long version = number(existing.get("server_version")).longValue() + 1;
            jdbc.update(
                    "UPDATE locations SET deleted_at = ?, updated_at = ?, server_version = ? WHERE client_uuid = ?",
                    timestamp(now),
                    timestamp(now),
                    version,
                    clientUuid
            );
            return new AppliedEntity(clientUuid.toString(), version, now, projectId,
                    payloadFor("STORY_LOCATION", number(existing.get("id")).longValue()));
        }
        return deleteByClientUuid("locations", "STORY_LOCATION", clientUuid, context);
    }

    private AppliedEntity deleteScene(UUID clientUuid, BatchContext context) {
        Map<String, Object> existing = rowByClientUuid("scenes", clientUuid);
        if (existing == null) throw new NotFoundException("Khong tim thay SCENE de xoa");
        Long sceneId = number(existing.get("id")).longValue();
        jdbc.update("DELETE FROM scene_characters WHERE scene_id = ?", sceneId);
        return deleteByClientUuid("scenes", "SCENE", clientUuid, context);
    }

    private AppliedEntity applied(String entityType, UUID clientUuid, Long serverId, long version, Instant updatedAt) {
        Long projectId = "PROJECT".equals(entityType) ? serverId : projectIdFor(entityType, serverId);
        return new AppliedEntity(clientUuid.toString(), version, updatedAt, projectId, payloadFor(entityType, serverId));
    }

    private Map<String, Object> payloadFor(String entityType, Long serverId) {
        Map<String, Object> row = switch (entityType) {
            case "PROJECT" -> rowById("projects", serverId);
            case "PROJECT_MEMBER" -> memberByUserId(serverId);
            case "ACT" -> rowById("acts", serverId);
            case "CHARACTER" -> rowById("characters", serverId);
            case "STORY_LOCATION" -> rowById("locations", serverId);
            case "SCENE" -> rowById("scenes", serverId);
            default -> throw new BadRequestException("Entity khong ho tro: " + entityType);
        };
        Map<String, Object> payload = new LinkedHashMap<>();
        UUID clientUuid = (UUID) row.get("client_uuid");
        payload.put("local_uuid", clientUuid == null ? null : clientUuid.toString());
        payload.put("remote_id", serverId.toString());
        payload.put("server_version", number(row.get("server_version")).longValue());
        payload.put("created_at", valueString(row.get("created_at")));
        payload.put("updated_at", valueString(row.get("updated_at")));
        payload.put("deleted_at", valueString(row.get("deleted_at")));
        switch (entityType) {
            case "PROJECT" -> {
                payload.put("owner_user_id", row.get("owner_id"));
                payload.put("title", row.get("title"));
                payload.put("genre", row.get("genre"));
                payload.put("description", row.get("description"));
                payload.put("start_date", valueString(row.get("start_date")));
                payload.put("poster_url", row.get("poster_url"));
            }
            case "PROJECT_MEMBER" -> {
                payload.put("project_id", row.get("project_id"));
                payload.put("project_client_uuid", valueString(row.get("project_client_uuid")));
                payload.put("user_id", row.get("user_id"));
                payload.put("role", row.get("role"));
                payload.put("email", row.get("email"));
                payload.put("full_name", row.get("display_name"));
                payload.put("joined_at", valueString(row.get("joined_at")));
            }
            case "ACT" -> {
                payload.put("project_id", row.get("project_id"));
                payload.put("project_client_uuid", projectClientUuid(number(row.get("project_id")).longValue()));
                payload.put("title", row.get("title"));
                payload.put("description", row.get("description"));
                payload.put("sequence_order", row.get("sequence_order"));
            }
            case "CHARACTER" -> {
                payload.put("project_id", row.get("project_id"));
                payload.put("project_client_uuid", projectClientUuid(number(row.get("project_id")).longValue()));
                payload.put("name", row.get("name"));
                payload.put("role_type", row.get("role_type"));
                payload.put("psychological_description", row.get("description"));
                payload.put("appearance_description", null);
                payload.put("image_path", row.get("image_url"));
                payload.put("is_archived", row.get("deleted_at") == null ? 0 : 1);
            }
            case "STORY_LOCATION" -> {
                payload.put("project_id", row.get("project_id"));
                payload.put("project_client_uuid", projectClientUuid(number(row.get("project_id")).longValue()));
                payload.put("name", row.get("name"));
                payload.put("description", null);
                payload.put("notes", row.get("notes"));
                payload.put("setting_type", row.get("setting_type"));
                payload.put("time_of_day", row.get("time_of_day"));
                payload.put("is_archived", row.get("deleted_at") == null ? 0 : 1);
            }
            case "SCENE" -> {
                payload.put("project_id", row.get("project_id"));
                payload.put("project_client_uuid", projectClientUuid(number(row.get("project_id")).longValue()));
                payload.put("act_id", row.get("act_id"));
                payload.put("act_client_uuid", clientUuidFor("acts", number(row.get("act_id")).longValue()));
                payload.put("story_location_id", row.get("location_id"));
                payload.put("story_location_client_uuid", clientUuidFor("locations", number(row.get("location_id")).longValue()));
                payload.put("scene_number", row.get("scene_number"));
                payload.put("title", row.get("title"));
                payload.put("summary", row.get("summary"));
                payload.put("setting_type", locationValue(number(row.get("location_id")).longValue(), "setting_type"));
                payload.put("time_of_day", locationValue(number(row.get("location_id")).longValue(), "time_of_day"));
                payload.put("estimated_duration_minutes", row.get("estimated_minutes"));
                payload.put("priority", 3);
                payload.put("writing_status", row.get("status"));
                payload.put("production_status", "NOT_READY");
                payload.put("character_client_uuids", sceneCharacterClientUuids(serverId));
            }
            default -> {
            }
        }
        return payload;
    }

    private void assertCurrentVersion(UUID clientUuid, String table, Long baseVersion, String entityType) {
        if (baseVersion == null) return;
        Map<String, Object> existing = rowByClientUuid(table, clientUuid);
        if (existing != null && number(existing.get("server_version")).longValue() > baseVersion) {
            throwConflict(clientUuid, entityType, existing);
        }
    }

    private void throwConflict(UUID clientUuid, String entityType, Map<String, Object> row) {
        Long id = number(row.get("id")).longValue();
        throw new ConflictDetected(
                "Du lieu tren server moi hon ban cuc bo",
                clientUuid.toString(),
                number(row.get("server_version")).longValue(),
                payloadFor(entityType, id),
                List.of()
        );
    }

    private long bumpVersion(String table, UUID clientUuid) {
        Long current = jdbc.queryForObject(
                "SELECT server_version FROM " + table + " WHERE client_uuid = ?",
                Long.class,
                clientUuid
        );
        return current == null ? 1 : current + 1;
    }

    private void writeChangeLog(
            Long projectId,
            String entityType,
            UUID entityId,
            String operation,
            long serverVersion,
            Map<String, Object> payload
    ) {
        KeyHolder keyHolder = new GeneratedKeyHolder();
        String temporaryCursor = UUID.randomUUID().toString();
        String payloadJson = writeJson(payload);
        jdbc.update(connection -> {
            PreparedStatement ps = connection.prepareStatement(
                    """
                    INSERT INTO sync_change_log(
                      cursor_value, project_id, entity_type, entity_id,
                      operation, server_version, payload_json, created_at
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    new String[]{"id"}
            );
            ps.setString(1, temporaryCursor);
            ps.setObject(2, projectId);
            ps.setString(3, entityType);
            ps.setObject(4, entityId);
            ps.setString(5, operation);
            ps.setLong(6, serverVersion);
            ps.setString(7, payloadJson);
            ps.setTimestamp(8, timestamp(Instant.now()));
            return ps;
        }, keyHolder);
        Long id = keyHolderId(keyHolder);
        jdbc.update("UPDATE sync_change_log SET cursor_value = ? WHERE id = ?", id.toString(), id);
    }

    private PushResult readIdempotentResult(String idempotencyKey, Long userId) {
        try {
            String json = jdbc.queryForObject(
                    "SELECT response_json FROM sync_idempotency WHERE idempotency_key = ? AND user_id = ?",
                    String.class,
                    UUID.fromString(idempotencyKey),
                    userId
            );
            if (json == null || json.isBlank()) return null;
            return objectMapper.readValue(json, PushResult.class);
        } catch (EmptyResultDataAccessException ex) {
            return null;
        } catch (JsonProcessingException ex) {
            throw new BadRequestException("Khong doc duoc ket qua idempotency");
        }
    }

    private void writeIdempotentResult(PushOperation operation, Long userId, PushResult result) {
        jdbc.update(
                """
                INSERT INTO sync_idempotency(
                  idempotency_key, user_id, entity_type, entity_id,
                  operation, status, response_json, created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                UUID.fromString(operation.idempotencyKey()),
                userId,
                operation.entityType(),
                UUID.fromString(operation.entityId()),
                operation.operation(),
                result.status(),
                writeJson(result),
                timestamp(Instant.now())
        );
    }

    private Long resolveProjectId(Map<String, Object> payload, BatchContext context) {
        Long localProjectId = longObject(payload, "project_id", "projectId");
        if (localProjectId != null) {
            Long mapped = context.lookupLocal("PROJECT", localProjectId);
            if (mapped != null) return mapped;
        }
        UUID projectUuid = uuidObject(payload, "project_client_uuid", "projectLocalUuid");
        if (projectUuid != null) {
            Long id = idByClientUuid("projects", projectUuid);
            if (id != null) return id;
        }
        if (localProjectId != null && existsProjectForCurrentUser(localProjectId)) {
            return localProjectId;
        }
        throw new BadRequestException("Khong resolve duoc project server cho dong bo");
    }

    private Long resolveRelatedId(
            String entityType,
            String table,
            Map<String, Object> payload,
            String localIdKey,
            String uuidKey,
            BatchContext context
    ) {
        Long localId = longObject(payload, localIdKey);
        if (localId != null) {
            Long mapped = context.lookupLocal(entityType, localId);
            if (mapped != null) return mapped;
        }
        UUID uuid = uuidObject(payload, uuidKey);
        if (uuid != null) {
            Long serverId = idByClientUuid(table, uuid);
            if (serverId != null) return serverId;
        }
        if (localId != null && rowById(table, localId) != null) {
            return localId;
        }
        throw new BadRequestException("Thieu dependency " + entityType + " de dong bo");
    }

    private UserAccount resolveMemberUser(Map<String, Object> payload, Long fallbackUserId) {
        String email = text(payload, "email");
        if (email != null) {
            return userRepository.findByEmailIgnoreCase(email)
                    .orElseThrow(() -> new NotFoundException("Khong tim thay email thanh vien tren server"));
        }
        Long userId = longObject(payload, "user_id", "userId");
        if (userId == null) userId = fallbackUserId;
        final Long resolvedUserId = userId;
        return userRepository.findById(resolvedUserId)
                .orElseThrow(() -> new NotFoundException("Khong tim thay user tren server"));
    }

    private void ensureOwnerMembership(Long projectId, Long userId, Instant now) {
        if (memberByProjectAndUser(projectId, userId) != null) return;
        jdbc.update(
                """
                INSERT INTO project_members(project_id, user_id, role, joined_at, server_version, created_at, updated_at)
                VALUES (?, ?, 'OWNER', ?, 0, ?, ?)
                """,
                projectId,
                userId,
                timestamp(now),
                timestamp(now),
                timestamp(now)
        );
    }

    private boolean existsProjectForCurrentUser(Long projectId) {
        return count(
                "SELECT COUNT(*) FROM project_members WHERE project_id = ? AND user_id = ?",
                projectId,
                accessService.currentUser().getId()
        ) > 0;
    }

    private boolean isProjectMember(Long projectId, Long userId) {
        return count(
                "SELECT COUNT(*) FROM project_members WHERE project_id = ? AND user_id = ? AND deleted_at IS NULL",
                projectId,
                userId
        ) > 0;
    }

    private boolean isProjectDeleted(Long projectId) {
        return count(
                "SELECT COUNT(*) FROM projects WHERE id = ? AND deleted = TRUE",
                projectId
        ) > 0;
    }

    private long ownerCount(Long projectId) {
        return count(
                "SELECT COUNT(*) FROM project_members WHERE project_id = ? AND role = 'OWNER'",
                projectId
        );
    }

    private boolean isSupported(String entityType) {
        return switch (entityType) {
            case "PROJECT", "PROJECT_MEMBER", "ACT", "CHARACTER", "STORY_LOCATION", "SCENE" -> true;
            default -> false;
        };
    }

    private Map<String, Object> rowByClientUuid(String table, UUID clientUuid) {
        try {
            return jdbc.queryForMap("SELECT * FROM " + table + " WHERE client_uuid = ?", clientUuid);
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private Map<String, Object> rowById(String table, Long id) {
        try {
            return jdbc.queryForMap("SELECT * FROM " + table + " WHERE id = ?", id);
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private Map<String, Object> memberByClientUuid(UUID clientUuid) {
        try {
            return jdbc.queryForMap(
                    """
                    SELECT pm.*, p.client_uuid AS project_client_uuid,
                           u.email, u.display_name
                    FROM project_members pm
                    JOIN projects p ON p.id = pm.project_id
                    JOIN users u ON u.id = pm.user_id
                    WHERE pm.client_uuid = ?
                    """,
                    clientUuid
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private Map<String, Object> memberByProjectAndUser(Long projectId, Long userId) {
        try {
            return jdbc.queryForMap(
                    """
                    SELECT pm.*, p.client_uuid AS project_client_uuid,
                           u.email, u.display_name
                    FROM project_members pm
                    JOIN projects p ON p.id = pm.project_id
                    JOIN users u ON u.id = pm.user_id
                    WHERE pm.project_id = ? AND pm.user_id = ?
                    """,
                    projectId,
                    userId
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private Map<String, Object> memberByUserId(Long userId) {
        try {
            return jdbc.queryForMap(
                    """
                    SELECT pm.*, p.client_uuid AS project_client_uuid,
                           u.email, u.display_name
                    FROM project_members pm
                    JOIN projects p ON p.id = pm.project_id
                    JOIN users u ON u.id = pm.user_id
                    WHERE pm.user_id = ?
                    ORDER BY pm.updated_at DESC
                    LIMIT 1
                    """,
                    userId
            );
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private Long idByClientUuid(String table, UUID clientUuid) {
        try {
            return jdbc.queryForObject("SELECT id FROM " + table + " WHERE client_uuid = ?", Long.class, clientUuid);
        } catch (EmptyResultDataAccessException ex) {
            return null;
        }
    }

    private Long projectIdFor(String entityType, Long serverId) {
        if ("PROJECT_MEMBER".equals(entityType)) {
            Map<String, Object> row = memberByUserId(serverId);
            return row == null ? null : number(row.get("project_id")).longValue();
        }
        String table = switch (entityType) {
            case "ACT" -> "acts";
            case "CHARACTER" -> "characters";
            case "STORY_LOCATION" -> "locations";
            case "SCENE" -> "scenes";
            default -> throw new BadRequestException("Entity khong ho tro: " + entityType);
        };
        return jdbc.queryForObject("SELECT project_id FROM " + table + " WHERE id = ?", Long.class, serverId);
    }

    private String projectClientUuid(Long projectId) {
        return valueString(jdbc.queryForObject("SELECT client_uuid FROM projects WHERE id = ?", Object.class, projectId));
    }

    private String clientUuidFor(String table, Long id) {
        return valueString(jdbc.queryForObject("SELECT client_uuid FROM " + table + " WHERE id = ?", Object.class, id));
    }

    private Object locationValue(Long locationId, String column) {
        return jdbc.queryForObject("SELECT " + column + " FROM locations WHERE id = ?", Object.class, locationId);
    }

    private List<String> sceneCharacterClientUuids(Long sceneId) {
        return jdbc.queryForList(
                """
                SELECT c.client_uuid
                FROM scene_characters sc
                JOIN characters c ON c.id = sc.character_id
                WHERE sc.scene_id = ?
                ORDER BY c.name ASC
                """,
                Object.class,
                sceneId
        ).stream().map(this::valueString).toList();
    }

    private long count(String sql, Object... args) {
        Long count = jdbc.queryForObject(sql, Long.class, args);
        return count == null ? 0 : count;
    }

    private Map<String, Object> memberPayload(Map<String, Object> row, long version, Instant deletedAt) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("local_uuid", valueString(row.get("client_uuid")));
        payload.put("remote_id", valueString(row.get("client_uuid")));
        payload.put("project_id", row.get("project_id"));
        payload.put("project_client_uuid", valueString(row.get("project_client_uuid")));
        payload.put("user_id", row.get("user_id"));
        payload.put("role", row.get("role"));
        payload.put("email", row.get("email"));
        payload.put("full_name", row.get("display_name"));
        payload.put("joined_at", valueString(row.get("joined_at")));
        payload.put("server_version", version);
        payload.put("deleted_at", deletedAt == null ? null : deletedAt.toString());
        payload.put("updated_at", deletedAt == null ? valueString(row.get("updated_at")) : deletedAt.toString());
        return payload;
    }

    private Map<String, Object> readPayload(Object json) {
        if (json == null || json.toString().isBlank()) return Map.of();
        try {
            return objectMapper.readValue(json.toString(), MAP_TYPE);
        } catch (JsonProcessingException ex) {
            throw new BadRequestException("Khong doc duoc payload dong bo");
        }
    }

    private String writeJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException ex) {
            throw new BadRequestException("Khong ghi duoc payload dong bo");
        }
    }

    private Long keyHolderId(KeyHolder keyHolder) {
        Map<String, Object> keys = keyHolder.getKeys();
        if (keys != null) {
            Object id = keys.getOrDefault("id", keys.get("ID"));
            if (id != null) {
                if (id instanceof Number number) return number.longValue();
                return Long.parseLong(id.toString());
            }
            if (keys.size() == 1) {
                Object onlyValue = keys.values().iterator().next();
                if (onlyValue instanceof Number number) return number.longValue();
                if (onlyValue != null) return Long.parseLong(onlyValue.toString());
            }
        }
        Number key = keyHolder.getKey();
        if (key == null) {
            throw new BadRequestException("Khong lay duoc id server sau khi dong bo");
        }
        return key.longValue();
    }

    private ProjectRole role(Map<String, Object> payload) {
        String role = textOrDefault(payload, "role", "role", "VIEWER");
        try {
            return ProjectRole.valueOf(role);
        } catch (IllegalArgumentException ex) {
            throw new BadRequestException("Vai tro thanh vien khong hop le");
        }
    }

    private Long localId(Map<String, Object> payload) {
        return longObject(payload, "id");
    }

    private Number number(Object value) {
        if (value instanceof Number number) return number;
        if (value == null) return 0;
        return Long.parseLong(value.toString());
    }

    private Integer intObject(Map<String, Object> payload, String primary, String fallback) {
        Long value = longObject(payload, primary, fallback);
        return value == null ? null : value.intValue();
    }

    private int intValue(Map<String, Object> payload, String primary, String fallback, int defaultValue) {
        Long value = longObject(payload, primary, fallback);
        return value == null ? defaultValue : value.intValue();
    }

    private Long longObject(Map<String, Object> payload, String... keys) {
        for (String key : keys) {
            Object value = payload.get(key);
            if (value == null || value.toString().isBlank()) continue;
            if (value instanceof Number number) return number.longValue();
            return Long.parseLong(value.toString());
        }
        return null;
    }

    private UUID uuidObject(Map<String, Object> payload, String... keys) {
        for (String key : keys) {
            Object value = payload.get(key);
            if (value == null || value.toString().isBlank()) continue;
            return UUID.fromString(value.toString());
        }
        return null;
    }

    private String requiredText(Map<String, Object> payload, String key) {
        String value = text(payload, key);
        if (value == null) throw new BadRequestException(key + " bat buoc");
        return value;
    }

    private String textOrDefault(Map<String, Object> payload, String primary, String fallback, String defaultValue) {
        String value = text(payload, primary, fallback);
        return value == null ? defaultValue : value;
    }

    private String text(Map<String, Object> payload, String... keys) {
        for (String key : keys) {
            Object value = payload.get(key);
            if (value == null) continue;
            String text = value.toString().trim();
            if (!text.isBlank()) return text;
        }
        return null;
    }

    private Date sqlDate(Object value) {
        if (value == null || value.toString().isBlank()) return null;
        String text = value.toString();
        return Date.valueOf(LocalDate.parse(text.length() > 10 ? text.substring(0, 10) : text));
    }

    private Timestamp timestamp(Instant value) {
        return Timestamp.from(value);
    }

    private Timestamp timestampOrNow(Object value, Instant fallback) {
        if (value == null || value.toString().isBlank()) return timestamp(fallback);
        return timestamp(instant(value));
    }

    private Instant instant(Object value) {
        if (value instanceof Timestamp timestamp) return timestamp.toInstant();
        if (value instanceof java.util.Date date) return date.toInstant();
        String text = value.toString().trim();
        if (text.isBlank()) {
            throw new BadRequestException("Timestamp khong hop le");
        }
        try {
            return Instant.parse(text);
        } catch (RuntimeException ignored) {
            // Fall through to other timestamp shapes used by mobile clients.
        }
        try {
            return OffsetDateTime.parse(text).toInstant();
        } catch (RuntimeException ignored) {
            // Fall through to SQL timestamp parsing.
        }
        try {
            return Timestamp.valueOf(text.replace('T', ' ')).toInstant();
        } catch (RuntimeException ex) {
            throw new BadRequestException("Timestamp khong hop le: " + text);
        }
    }

    private String valueString(Object value) {
        if (value == null) return null;
        if (value instanceof Timestamp timestamp) return timestamp.toInstant().toString();
        if (value instanceof java.sql.Date date) return date.toLocalDate().toString();
        return value.toString();
    }

    private long parseCursor(String cursor) {
        if (cursor == null || cursor.isBlank()) return 0;
        try {
            return Long.parseLong(cursor);
        } catch (NumberFormatException ex) {
            return 0;
        }
    }

    private String rootMessage(Throwable ex) {
        Throwable current = ex;
        while (current.getCause() != null) {
            current = current.getCause();
        }
        return current.getMessage() == null ? ex.getMessage() : current.getMessage();
    }

    private record AppliedEntity(
            String remoteId,
            long serverVersion,
            Instant updatedAt,
            Long projectId,
            Map<String, Object> payload
    ) {
    }

    private static final class BatchContext {
        private final Long userId;
        private final Map<String, Long> localIds = new HashMap<>();

        private BatchContext(Long userId) {
            this.userId = userId;
        }

        Long userId() {
            return userId;
        }

        void remember(String entityType, Long localId, Long serverId, UUID clientUuid) {
            if (localId != null) {
                localIds.put(entityType + ":" + localId, serverId);
            }
            localIds.put(entityType + ":" + clientUuid, serverId);
        }

        Long lookupLocal(String entityType, Long localId) {
            return localId == null ? null : localIds.get(entityType + ":" + localId);
        }
    }

    private static final class ConflictDetected extends RuntimeException {
        private final String remoteId;
        private final long serverVersion;
        private final Map<String, Object> remotePayload;
        private final List<String> conflictingFields;

        private ConflictDetected(
                String message,
                String remoteId,
                long serverVersion,
                Map<String, Object> remotePayload,
                List<String> conflictingFields
        ) {
            super(message);
            this.remoteId = remoteId;
            this.serverVersion = serverVersion;
            this.remotePayload = remotePayload;
            this.conflictingFields = conflictingFields;
        }

        String remoteId() {
            return remoteId;
        }

        long serverVersion() {
            return serverVersion;
        }

        Map<String, Object> remotePayload() {
            return remotePayload;
        }

        List<String> conflictingFields() {
            return conflictingFields;
        }
    }
}
