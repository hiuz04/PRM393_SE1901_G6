package com.cinex.analytics;

import com.cinex.act.ActRepository;
import com.cinex.analytics.dto.AnalyticsDtos.CharacterFrequencyItem;
import com.cinex.analytics.dto.AnalyticsDtos.CharacterFrequencyResponse;
import com.cinex.analytics.dto.AnalyticsDtos.LocationSettingRatioResponse;
import com.cinex.analytics.dto.AnalyticsDtos.SceneStatusRatioResponse;
import com.cinex.analytics.dto.AnalyticsDtos.SummaryResponse;
import com.cinex.character.StoryCharacterRepository;
import com.cinex.location.SettingType;
import com.cinex.location.StoryLocationRepository;
import com.cinex.project.ProjectAccessService;
import com.cinex.scene.SceneRepository;
import com.cinex.scene.SceneStatus;
import java.util.Arrays;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AnalyticsService {
    private final ProjectAccessService accessService;
    private final ActRepository actRepository;
    private final StoryCharacterRepository characterRepository;
    private final StoryLocationRepository locationRepository;
    private final SceneRepository sceneRepository;

    public AnalyticsService(ProjectAccessService accessService, ActRepository actRepository,
                            StoryCharacterRepository characterRepository,
                            StoryLocationRepository locationRepository,
                            SceneRepository sceneRepository) {
        this.accessService = accessService;
        this.actRepository = actRepository;
        this.characterRepository = characterRepository;
        this.locationRepository = locationRepository;
        this.sceneRepository = sceneRepository;
    }

    @Transactional(readOnly = true)
    public SummaryResponse summary(Long projectId) {
        accessService.requireVisibleProject(projectId);
        long total = sceneRepository.countByProjectId(projectId);
        long done = sceneRepository.countByProjectIdAndStatus(projectId, SceneStatus.DONE);
        long todo = sceneRepository.countByProjectIdAndStatus(projectId, SceneStatus.TODO);
        long progress = sceneRepository.countByProjectIdAndStatus(projectId, SceneStatus.IN_PROGRESS);
        return new SummaryResponse(
                actRepository.countByProjectId(projectId),
                characterRepository.countByProjectId(projectId),
                locationRepository.countByProjectId(projectId),
                total,
                todo,
                progress,
                done,
                total == 0 ? 0 : done * 100.0 / total
        );
    }

    @Transactional(readOnly = true)
    public CharacterFrequencyResponse characterFrequency(Long projectId) {
        accessService.requireVisibleProject(projectId);
        List<CharacterFrequencyItem> items = sceneRepository.characterFrequency(projectId).stream()
                .map(row -> new CharacterFrequencyItem((Long) row[0], (String) row[1], (Long) row[2]))
                .toList();
        return new CharacterFrequencyResponse(items);
    }

    @Transactional(readOnly = true)
    public LocationSettingRatioResponse locationSettingRatio(Long projectId) {
        accessService.requireVisibleProject(projectId);
        Map<SettingType, Long> values = new EnumMap<>(SettingType.class);
        Arrays.stream(SettingType.values()).forEach(type -> values.put(type, 0L));
        locationRepository.findByProjectIdOrderByNameAsc(projectId)
                .forEach(location -> values.put(location.getSettingType(), values.get(location.getSettingType()) + 1));
        return new LocationSettingRatioResponse(values.get(SettingType.INT), values.get(SettingType.EXT), values);
    }

    @Transactional(readOnly = true)
    public SceneStatusRatioResponse sceneStatusRatio(Long projectId) {
        accessService.requireVisibleProject(projectId);
        Map<SceneStatus, Long> values = new EnumMap<>(SceneStatus.class);
        Arrays.stream(SceneStatus.values()).forEach(status -> values.put(status, sceneRepository.countByProjectIdAndStatus(projectId, status)));
        return new SceneStatusRatioResponse(values.get(SceneStatus.TODO), values.get(SceneStatus.IN_PROGRESS),
                values.get(SceneStatus.DONE), values);
    }
}
