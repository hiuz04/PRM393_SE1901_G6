package com.cinex.location.service;

import com.cinex.common.exception.BadRequestException;
import com.cinex.location.domain.StoryLocation;
import com.cinex.location.repository.StoryLocationRepository;
import com.cinex.project.domain.Project;
import com.cinex.project.service.ProjectAccessService;
import com.cinex.scene.repository.SceneRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class LocationServiceTest {
    @Test
    void deleteRejectsLocationUsedByScene() {
        StoryLocationRepository locations = mock(StoryLocationRepository.class);
        SceneRepository scenes = mock(SceneRepository.class);
        ProjectAccessService access = mock(ProjectAccessService.class);
        Project project = new Project();
        project.setId(1L);
        StoryLocation location = new StoryLocation();
        location.setId(2L);
        location.setProject(project);
        when(locations.findByIdAndProjectId(2L, 1L)).thenReturn(Optional.of(location));
        when(scenes.countByLocationId(2L)).thenReturn(1L);

        LocationService service = new LocationService(locations, scenes, access);

        assertThatThrownBy(() -> service.delete(1L, 2L))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("Location");
    }
}
