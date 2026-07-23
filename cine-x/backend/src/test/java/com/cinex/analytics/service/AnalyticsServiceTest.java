package com.cinex.analytics.service;

import com.cinex.act.repository.ActRepository;
import com.cinex.character.repository.StoryCharacterRepository;
import com.cinex.location.repository.StoryLocationRepository;
import com.cinex.project.service.ProjectAccessService;
import com.cinex.scene.domain.SceneStatus;
import com.cinex.scene.repository.SceneRepository;
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
}
