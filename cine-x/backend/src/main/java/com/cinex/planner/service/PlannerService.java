package com.cinex.planner.service;

import com.cinex.location.domain.StoryLocation;
import com.cinex.location.repository.StoryLocationRepository;
import com.cinex.location.service.LocationService;
import com.cinex.planner.dto.PlannerDtos.LocationPlanResponse;
import com.cinex.project.service.ProjectAccessService;
import com.cinex.scene.domain.Scene;
import com.cinex.scene.repository.SceneRepository;
import com.cinex.scene.service.SceneService;
import java.util.Comparator;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PlannerService {
    private final ProjectAccessService accessService;
    private final StoryLocationRepository locationRepository;
    private final SceneRepository sceneRepository;
    private final LocationService locationService;
    private final SceneService sceneService;

    public PlannerService(ProjectAccessService accessService, StoryLocationRepository locationRepository,
                          SceneRepository sceneRepository, LocationService locationService,
                          SceneService sceneService) {
        this.accessService = accessService;
        this.locationRepository = locationRepository;
        this.sceneRepository = sceneRepository;
        this.locationService = locationService;
        this.sceneService = sceneService;
    }

    @Transactional(readOnly = true)
    public List<LocationPlanResponse> byLocation(Long projectId) {
        accessService.requireVisibleProject(projectId);
        List<StoryLocation> locations = locationRepository.findByProjectIdOrderByNameAsc(projectId);
        return locations.stream().map(location -> {
            List<Scene> scenes = sceneRepository.findByLocationIdInOrderBySceneNumberAsc(List.of(location.getId()))
                    .stream()
                    .filter(scene -> scene.getProject().getId().equals(projectId))
                    .sorted(Comparator.comparingInt(Scene::getSceneNumber))
                    .toList();
            int minutes = scenes.stream().map(Scene::getEstimatedMinutes)
                    .filter(value -> value != null)
                    .mapToInt(Integer::intValue)
                    .sum();
            return new LocationPlanResponse(
                    locationService.toResponse(location),
                    scenes.size(),
                    minutes,
                    scenes.stream().map(sceneService::toResponse).toList()
            );
        }).toList();
    }
}
