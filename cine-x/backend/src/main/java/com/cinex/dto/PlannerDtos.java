package com.cinex.dto;

import com.cinex.dto.LocationDtos.LocationResponse;
import com.cinex.dto.SceneDtos.SceneResponse;
import java.util.List;

public final class PlannerDtos {
    private PlannerDtos() {
    }

    public record LocationPlanResponse(
            LocationResponse location,
            int sceneCount,
            int totalEstimatedMinutes,
            List<SceneResponse> scenes
    ) {
    }
}
