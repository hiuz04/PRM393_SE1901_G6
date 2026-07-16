package com.cinex.planner.dto;

import com.cinex.location.dto.LocationDtos.LocationResponse;
import com.cinex.scene.dto.SceneDtos.SceneResponse;
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
