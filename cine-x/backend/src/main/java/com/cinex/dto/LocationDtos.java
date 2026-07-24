package com.cinex.dto;

import com.cinex.domain.SettingType;
import com.cinex.domain.TimeOfDay;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;

public final class LocationDtos {
    private LocationDtos() {
    }

    public record LocationRequest(
            @NotBlank @Size(max = 200) String name,
            @NotNull SettingType settingType,
            @NotNull TimeOfDay timeOfDay,
            @Size(max = 5000) String notes
    ) {
    }

    public record LocationResponse(
            Long id,
            Long projectId,
            String name,
            SettingType settingType,
            TimeOfDay timeOfDay,
            String notes,
            Instant createdAt,
            Instant updatedAt
    ) {
    }
}
