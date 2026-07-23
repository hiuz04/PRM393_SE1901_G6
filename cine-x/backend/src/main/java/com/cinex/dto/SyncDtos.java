package com.cinex.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.List;
import java.util.Map;

public final class SyncDtos {
    private SyncDtos() {
    }

    public record PushRequest(
            @NotBlank String deviceId,
            @NotBlank String clientBatchId,
            @NotEmpty List<@Valid PushOperation> operations
    ) {
    }

    public record PushOperation(
            @NotBlank String operationId,
            @NotBlank String idempotencyKey,
            @NotBlank String entityType,
            @NotBlank String entityId,
            @NotBlank String operation,
            Long baseVersion,
            @NotNull Map<String, Object> payload
    ) {
    }

    public record PushResponse(
            List<PushResult> results,
            String nextCursor
    ) {
    }

    public record PushResult(
            String operationId,
            String status,
            Long serverVersion,
            Instant serverUpdatedAt,
            String error,
            Map<String, Object> remotePayload,
            List<String> conflictingFields
    ) {
        public static PushResult applied(String operationId, long serverVersion, Instant updatedAt) {
            return new PushResult(operationId, "APPLIED", serverVersion, updatedAt, null, null, List.of());
        }

        public static PushResult rejected(String operationId, String status, String error) {
            return new PushResult(operationId, status, null, null, error, null, List.of());
        }
    }

    public record PullResponse(
            List<PullChange> changes,
            String nextCursor,
            boolean hasMore
    ) {
    }

    public record PullChange(
            String entityType,
            String entityId,
            String operation,
            long serverVersion,
            Instant updatedAt,
            Map<String, Object> payload
    ) {
    }

    public record ProjectManifestItem(
            Long id,
            String clientUuid,
            String title,
            String role,
            long serverVersion,
            Instant updatedAt,
            boolean deleted
    ) {
    }
}
