package com.cinex.service;

import com.cinex.repository.ActRepository;
import com.cinex.repository.StoryCharacterRepository;
import com.cinex.domain.SettingType;
import com.cinex.repository.StoryLocationRepository;
import com.cinex.domain.SceneStatus;
import com.cinex.repository.SceneRepository;
import java.util.List;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class AnalyticsServiceTest {
    @Test
    void summaryProgressIsZeroWhenThereAreNoScenes() {
        ProjectAccessService access = mock(ProjectAccessService.class);
        SceneRepository scenes = mock(SceneRepository.class);
        AnalyticsService service = new AnalyticsService(access, mock(ActRepository.class),
                mock(StoryCharacterRepository.class), mock(StoryLocationRepository.class), scenes);

        var summary = service.summary(1L);

        assertThat(summary.totalScenes()).isZero();
        assertThat(summary.progressPercent()).isZero();
    }

    @Test
    void summaryProgressUsesDoneSceneRatio() {
        ProjectAccessService access = mock(ProjectAccessService.class);
        SceneRepository scenes = mock(SceneRepository.class);
        when(scenes.countByProjectId(1L)).thenReturn(4L);
        when(scenes.countByProjectIdAndStatus(1L, SceneStatus.DONE)).thenReturn(3L);
        AnalyticsService service = new AnalyticsService(access, mock(ActRepository.class),
                mock(StoryCharacterRepository.class), mock(StoryLocationRepository.class), scenes);

        var summary = service.summary(1L);

        assertThat(summary.progressPercent()).isEqualTo(75.0);
    }

    @Test
    void locationSettingRatioCountsScenesByLocationSetting() {
        ProjectAccessService access = mock(ProjectAccessService.class);
        SceneRepository scenes = mock(SceneRepository.class);
        when(scenes.locationSettingFrequency(1L)).thenReturn(List.of(
                new Object[]{SettingType.INT, 3L},
                new Object[]{SettingType.EXT, 1L}
        ));
        AnalyticsService service = new AnalyticsService(access, mock(ActRepository.class),
                mock(StoryCharacterRepository.class), mock(StoryLocationRepository.class), scenes);

        var ratio = service.locationSettingRatio(1L);

        assertThat(ratio.intCount()).isEqualTo(3L);
        assertThat(ratio.extCount()).isEqualTo(1L);
    }
}
