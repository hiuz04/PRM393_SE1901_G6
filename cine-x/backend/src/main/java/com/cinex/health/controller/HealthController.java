package com.cinex.health.controller;

import com.cinex.common.response.ApiResponse;
import java.time.Instant;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/health")
public class HealthController {
    private final String applicationName;

    public HealthController(@Value("${spring.application.name:cine-x-backend}") String applicationName) {
        this.applicationName = applicationName;
    }

    @GetMapping
    ApiResponse<HealthResponse> health() {
        return ApiResponse.ok(new HealthResponse("UP", applicationName, Instant.now()));
    }

    public record HealthResponse(
            String status,
            String service,
            Instant checkedAt
    ) {
    }
}
