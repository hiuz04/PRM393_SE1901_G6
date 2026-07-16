package com.cinex.character.dto;

import com.cinex.character.CharacterRoleType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;

public final class CharacterDtos {
    private CharacterDtos() {
    }

    public record CharacterRequest(
            @NotBlank @Size(max = 150) String name,
            @NotNull CharacterRoleType roleType,
            @Size(max = 5000) String description
    ) {
    }

    public record CharacterResponse(
            Long id,
            Long projectId,
            String name,
            CharacterRoleType roleType,
            String description,
            String imageUrl,
            Instant createdAt,
            Instant updatedAt
    ) {
    }
}
