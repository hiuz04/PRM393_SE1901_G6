package com.cinex.controller;

import com.cinex.dto.AnalyticsDtos.CharacterFrequencyResponse;
import com.cinex.dto.AnalyticsDtos.LocationSettingRatioResponse;
import com.cinex.dto.AnalyticsDtos.SceneStatusRatioResponse;
import com.cinex.dto.AnalyticsDtos.SummaryResponse;
import com.cinex.service.AnalyticsService;
import com.cinex.response.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/projects/{projectId}/analytics")
public class AnalyticsController {
    private final AnalyticsService analyticsService;

    public AnalyticsController(AnalyticsService analyticsService) {
        this.analyticsService = analyticsService;
    }

    @GetMapping("/summary")
    ApiResponse<SummaryResponse> summary(@PathVariable Long projectId) {
        return ApiResponse.ok(analyticsService.summary(projectId));
    }

    @GetMapping("/character-frequency")
    ApiResponse<CharacterFrequencyResponse> characterFrequency(@PathVariable Long projectId) {
        return ApiResponse.ok(analyticsService.characterFrequency(projectId));
    }

    @GetMapping("/location-setting-ratio")
    ApiResponse<LocationSettingRatioResponse> locationSettingRatio(@PathVariable Long projectId) {
        return ApiResponse.ok(analyticsService.locationSettingRatio(projectId));
    }

    @GetMapping("/scene-status-ratio")
    ApiResponse<SceneStatusRatioResponse> sceneStatusRatio(@PathVariable Long projectId) {
        return ApiResponse.ok(analyticsService.sceneStatusRatio(projectId));
    }
}
