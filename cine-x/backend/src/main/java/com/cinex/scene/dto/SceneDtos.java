package com.cinex.scene.dto;

import com.cinex.character.CharacterRoleType;
import com.cinex.location.SettingType;
import com.cinex.location.TimeOfDay;
import com.cinex.scene.SceneStatus;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

public final class SceneDtos {
    private SceneDtos() {
    }

    public record SceneRequest(
            @NotNull Long actId,
            @NotNull Long locationId,
            @Min(1) int sceneNumber,
            @Size(max = 200) String title,
            @NotBlank @Size(max = 10000) String summary,
            @NotNull SceneStatus status,
            @Min(1) Integer estimatedMinutes,
            List<Long> characterIds
    ) {
    }

    public record StatusUpdateRequest(
            @NotNull SceneStatus status
    ) {
    }

    public record ReorderItem(
            @NotNull Long sceneId,
            @Min(1) int sceneNumber
    ) {
    }

    public record ReorderRequest(
            @NotEmpty List<@Valid ReorderItem> items
    ) {
    }

    public record SceneCharacterBrief(
            Long id,
            String name,
            CharacterRoleType roleType,
            String imageUrl
    ) {
    }

    public record SceneResponse(
            Long id,
            Long projectId,
            Long actId,
            String actTitle,
            Long locationId,
            String locationName,
            SettingType settingType,
            TimeOfDay timeOfDay,
            int sceneNumber,
            String title,
            String summary,
            SceneStatus status,
            Integer estimatedMinutes,
            List<SceneCharacterBrief> characters,
            Instant createdAt,
            Instant updatedAt
    ) {
    }
}
