package com.cinex.location.service;

import com.cinex.common.exception.BadRequestException;
import com.cinex.common.exception.NotFoundException;
import com.cinex.location.domain.SettingType;
import com.cinex.location.domain.StoryLocation;
import com.cinex.location.domain.TimeOfDay;
import com.cinex.location.dto.LocationDtos.LocationRequest;
import com.cinex.location.dto.LocationDtos.LocationResponse;
import com.cinex.location.repository.StoryLocationRepository;
import com.cinex.project.domain.Project;
import com.cinex.project.service.ProjectAccessService;
import com.cinex.scene.repository.SceneRepository;
import java.util.Locale;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class LocationService {
    private final StoryLocationRepository locationRepository;
    private final SceneRepository sceneRepository;
    private final ProjectAccessService accessService;

    public LocationService(StoryLocationRepository locationRepository, SceneRepository sceneRepository,
                           ProjectAccessService accessService) {
        this.locationRepository = locationRepository;
        this.sceneRepository = sceneRepository;
        this.accessService = accessService;
    }

    public Page<LocationResponse> list(Long projectId, String search, SettingType settingType,
                                       TimeOfDay timeOfDay, Pageable pageable) {
        accessService.requireVisibleProject(projectId);
        return locationRepository.search(projectId, searchPattern(search), settingType, timeOfDay, pageable)
                .map(this::toResponse);
    }

    @Transactional
    public LocationResponse create(Long projectId, LocationRequest request) {
        accessService.requireStructureEditor(projectId);
        Project project = accessService.requireVisibleProject(projectId);
        StoryLocation location = new StoryLocation();
        location.setProject(project);
        apply(location, request);
        return toResponse(locationRepository.save(location));
    }

    public LocationResponse get(Long projectId, Long locationId) {
        accessService.requireVisibleProject(projectId);
        return toResponse(require(projectId, locationId));
    }

    @Transactional
    public LocationResponse update(Long projectId, Long locationId, LocationRequest request) {
        accessService.requireStructureEditor(projectId);
        StoryLocation location = require(projectId, locationId);
        apply(location, request);
        return toResponse(location);
    }

    @Transactional
    public void delete(Long projectId, Long locationId) {
        accessService.requireStructureEditor(projectId);
        StoryLocation location = require(projectId, locationId);
        if (sceneRepository.countByLocationId(locationId) > 0) {
            throw new BadRequestException("Khong the xoa Location dang duoc Scene su dung");
        }
        locationRepository.delete(location);
    }

    public LocationResponse toResponse(StoryLocation location) {
        return new LocationResponse(location.getId(), location.getProject().getId(), location.getName(),
                location.getSettingType(), location.getTimeOfDay(), location.getNotes(),
                location.getCreatedAt(), location.getUpdatedAt());
    }

    private StoryLocation require(Long projectId, Long locationId) {
        return locationRepository.findByIdAndProjectId(locationId, projectId)
                .orElseThrow(() -> new NotFoundException("Khong tim thay Location"));
    }

    private void apply(StoryLocation location, LocationRequest request) {
        location.setName(request.name().trim());
        location.setSettingType(request.settingType());
        location.setTimeOfDay(request.timeOfDay());
        location.setNotes(blankToNull(request.notes()));
    }

    private String blankToNull(String value) {
        return value == null || value.trim().isBlank() ? null : value.trim();
    }

    private String searchPattern(String value) {
        if (value == null || value.trim().isBlank()) {
            return "%";
        }
        return "%" + value.trim().toLowerCase(Locale.ROOT) + "%";
    }
}
