package com.cinex.controller;

import com.cinex.dto.SyncDtos.PullResponse;
import com.cinex.dto.SyncDtos.PushRequest;
import com.cinex.dto.SyncDtos.PushResponse;
import com.cinex.response.ApiResponse;
import com.cinex.service.SyncService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/sync")
public class SyncController {
    private final SyncService syncService;

    public SyncController(SyncService syncService) {
        this.syncService = syncService;
    }

    @PostMapping("/push")
    ApiResponse<PushResponse> push(@Valid @RequestBody PushRequest request) {
        return ApiResponse.ok(syncService.push(request));
    }

    @GetMapping("/pull")
    ApiResponse<PullResponse> pull(@RequestParam(required = false) String cursor) {
        return ApiResponse.ok(syncService.pull(cursor));
    }
}
