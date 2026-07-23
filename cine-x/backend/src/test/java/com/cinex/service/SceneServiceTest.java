package com.cinex.service;

import com.cinex.domain.Act;
import com.cinex.repository.ActRepository;
import com.cinex.repository.StoryCharacterRepository;
import com.cinex.exception.BadRequestException;
import com.cinex.exception.ConflictException;
import com.cinex.domain.SettingType;
import com.cinex.domain.StoryLocation;
import com.cinex.domain.TimeOfDay;
import com.cinex.repository.StoryLocationRepository;
import com.cinex.domain.Project;
import com.cinex.domain.Scene;
import com.cinex.domain.SceneStatus;
import com.cinex.dto.SceneDtos.ReorderItem;
import com.cinex.dto.SceneDtos.SceneRequest;
import com.cinex.repository.SceneRepository;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.doAnswer;
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

    @Test
    void reorderUsesTemporaryNumbersForSwap() {
        SceneRepository sceneRepository = mock(SceneRepository.class);
        List<Scene> rows = new ArrayList<>(List.of(
                scene(10L, 1),
                scene(11L, 2)
        ));
        when(sceneRepository.findByProjectIdOrderBySceneNumberAsc(1L)).thenAnswer(invocation ->
                rows.stream().sorted(Comparator.comparingInt(Scene::getSceneNumber)).toList());
        List<List<Integer>> flushSnapshots = new ArrayList<>();
        doAnswer(invocation -> {
            flushSnapshots.add(rows.stream().map(Scene::getSceneNumber).toList());
            return null;
        }).when(sceneRepository).flush();

        SceneService service = new SceneService(sceneRepository, mock(ActRepository.class),
                mock(StoryLocationRepository.class), mock(StoryCharacterRepository.class),
                mock(ProjectAccessService.class));

        service.reorder(1L, List.of(new ReorderItem(10L, 2), new ReorderItem(11L, 1)));

        assertThat(flushSnapshots).containsExactly(
                List.of(3, 4),
                List.of(2, 1)
        );
    }

    @Test
    void reorderRejectsNumberUsedByUntouchedScene() {
        SceneRepository sceneRepository = mock(SceneRepository.class);
        when(sceneRepository.findByProjectIdOrderBySceneNumberAsc(1L)).thenReturn(List.of(
                scene(10L, 1),
                scene(11L, 2)
        ));
        SceneService service = new SceneService(sceneRepository, mock(ActRepository.class),
                mock(StoryLocationRepository.class), mock(StoryCharacterRepository.class),
                mock(ProjectAccessService.class));

        assertThatThrownBy(() -> service.reorder(1L, List.of(new ReorderItem(10L, 2))))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("sceneNumber");
    }

    private static Scene scene(Long id, int sceneNumber) {
        Project project = new Project();
        project.setId(1L);
        Act act = new Act();
        act.setId(1L);
        act.setProject(project);
        act.setTitle("Act");
        StoryLocation location = new StoryLocation();
        location.setId(1L);
        location.setProject(project);
        location.setName("Location");
        location.setSettingType(SettingType.INT);
        location.setTimeOfDay(TimeOfDay.DAY);
        Scene scene = new Scene();
        scene.setId(id);
        scene.setProject(project);
        scene.setAct(act);
        scene.setLocation(location);
        scene.setSceneNumber(sceneNumber);
        scene.setSummary("Summary");
        scene.setStatus(SceneStatus.TODO);
        return scene;
    }
}
