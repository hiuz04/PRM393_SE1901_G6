package com.cinex.analytics.dto;

import com.cinex.location.domain.SettingType;
import com.cinex.scene.domain.SceneStatus;
import java.util.List;
import java.util.Map;

public final class AnalyticsDtos {
    private AnalyticsDtos() {
    }

    public record SummaryResponse(
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

    public record CharacterFrequencyItem(
            Long characterId,
            String name,
            long sceneCount
    ) {
    }

    public record LocationSettingRatioResponse(
            long intCount,
            long extCount,
            Map<SettingType, Long> values
    ) {
    }

    public record SceneStatusRatioResponse(
            long todo,
            long inProgress,
            long done,
            Map<SceneStatus, Long> values
    ) {
    }

    public record CharacterFrequencyResponse(
            List<CharacterFrequencyItem> items
    ) {
    }
}
