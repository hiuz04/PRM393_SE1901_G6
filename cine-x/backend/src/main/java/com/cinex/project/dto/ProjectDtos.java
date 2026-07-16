package com.cinex.project.dto;

import com.cinex.project.ProjectStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalDate;

public final class ProjectDtos {
    private ProjectDtos() {
    }

    public record ProjectRequest(
            @NotBlank @Size(max = 200) String title,
            @Size(max = 100) String genre,
            @Size(max = 5000) String description,
            LocalDate startDate,
            @Size(max = 500) String posterUrl,
            ProjectStatus status
    ) {
    }

    public record ProjectResponse(
            Long id,
            Long ownerId,
            String title,
            String genre,
            String description,
            LocalDate startDate,
            String posterUrl,
            ProjectStatus status,
            boolean deleted,
            double progressPercent,
            Instant createdAt,
            Instant updatedAt
    ) {
    }

    public record DashboardResponse(
            ProjectResponse project,
            long totalActs,
            long totalCharacters,
            long totalLocations,
            long totalScenes,
            long todoScenes,
            long inProgressScenes,
            long doneScenes,
            double progressPercent
    ) {
    }
}
