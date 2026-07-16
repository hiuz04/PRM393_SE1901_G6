package com.cinex.act.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

public final class ActDtos {
    private ActDtos() {
    }

    public record ActRequest(
            @NotBlank @Size(max = 200) String title,
            @Size(max = 5000) String description,
            @Min(1) int sequenceOrder
    ) {
    }

    public record ActResponse(
            Long id,
            Long projectId,
            String title,
            String description,
            int sequenceOrder,
            Instant createdAt,
            Instant updatedAt
    ) {
    }

    public record ReorderItem(
            @Min(1) long actId,
            @Min(1) int sequenceOrder
    ) {
    }

    public record ReorderRequest(
            @NotEmpty List<@Valid ReorderItem> items
    ) {
    }
}
