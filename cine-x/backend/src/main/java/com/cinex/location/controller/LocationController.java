package com.cinex.location.controller;

import com.cinex.common.response.ApiResponse;
import com.cinex.location.domain.SettingType;
import com.cinex.location.domain.TimeOfDay;
import com.cinex.location.dto.LocationDtos.LocationRequest;
import com.cinex.location.dto.LocationDtos.LocationResponse;
import com.cinex.location.service.LocationService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/projects/{projectId}/locations")
public class LocationController {
    private final LocationService locationService;

    public LocationController(LocationService locationService) {
        this.locationService = locationService;
    }

    @GetMapping
    ApiResponse<Page<LocationResponse>> list(@PathVariable Long projectId,
                                             @RequestParam(required = false) String search,
                                             @RequestParam(required = false) SettingType settingType,
                                             @RequestParam(required = false) TimeOfDay timeOfDay,
                                             Pageable pageable) {
        return ApiResponse.ok(locationService.list(projectId, search, settingType, timeOfDay, pageable));
    }

    @PostMapping
    ApiResponse<LocationResponse> create(@PathVariable Long projectId,
                                         @Valid @RequestBody LocationRequest request) {
        return ApiResponse.message("Da tao Location", locationService.create(projectId, request));
    }

    @GetMapping("/{locationId}")
    ApiResponse<LocationResponse> get(@PathVariable Long projectId, @PathVariable Long locationId) {
        return ApiResponse.ok(locationService.get(projectId, locationId));
    }

    @PutMapping("/{locationId}")
    ApiResponse<LocationResponse> update(@PathVariable Long projectId, @PathVariable Long locationId,
                                         @Valid @RequestBody LocationRequest request) {
        return ApiResponse.message("Da cap nhat Location", locationService.update(projectId, locationId, request));
    }

    @DeleteMapping("/{locationId}")
    ApiResponse<Void> delete(@PathVariable Long projectId, @PathVariable Long locationId) {
        locationService.delete(projectId, locationId);
        return ApiResponse.message("Da xoa Location", null);
    }
}
