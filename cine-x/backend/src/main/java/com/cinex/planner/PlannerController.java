package com.cinex.planner;

import com.cinex.common.response.ApiResponse;
import com.cinex.planner.dto.PlannerDtos.LocationPlanResponse;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/projects/{projectId}/planner")
public class PlannerController {
    private final PlannerService plannerService;

    public PlannerController(PlannerService plannerService) {
        this.plannerService = plannerService;
    }

    @GetMapping("/by-location")
    ApiResponse<List<LocationPlanResponse>> byLocation(@PathVariable Long projectId) {
        return ApiResponse.ok(plannerService.byLocation(projectId));
    }
}
