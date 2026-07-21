package com.cinex.scene.service;

import com.cinex.act.repository.ActRepository;
import com.cinex.character.repository.StoryCharacterRepository;
import com.cinex.common.exception.BadRequestException;
import com.cinex.location.repository.StoryLocationRepository;
import com.cinex.project.domain.Project;
import com.cinex.project.service.ProjectAccessService;
import com.cinex.scene.domain.SceneStatus;
import com.cinex.scene.dto.SceneDtos.SceneRequest;
import com.cinex.scene.repository.SceneRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class SceneServiceTest {
    @Test
    void createRejectsActFromAnotherProject() {
        SceneRepository sceneRepository = mock(SceneRepository.class);
        ActRepository actRepository = mock(ActRepository.class);
        ProjectAccessService access = mock(ProjectAccessService.class);
        Project project = new Project();
        project.setId(1L);
        when(access.requireVisibleProject(1L)).thenReturn(project);
        when(sceneRepository.existsByProjectIdAndSceneNumber(1L, 1)).thenReturn(false);
        when(actRepository.findByIdAndProjectId(99L, 1L)).thenReturn(Optional.empty());

        SceneService service = new SceneService(sceneRepository, actRepository,
                mock(StoryLocationRepository.class), mock(StoryCharacterRepository.class), access);
        SceneRequest request = new SceneRequest(99L, 10L, 1, "A", "Summary", SceneStatus.TODO, 3, List.of());

        assertThatThrownBy(() -> service.create(1L, request))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("Act");
    }
}
