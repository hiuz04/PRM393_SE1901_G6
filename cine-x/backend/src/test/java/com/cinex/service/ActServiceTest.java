package com.cinex.service;

import com.cinex.domain.Act;
import com.cinex.dto.ActDtos.ReorderItem;
import com.cinex.repository.ActRepository;
import com.cinex.exception.ConflictException;
import com.cinex.domain.Project;
import com.cinex.domain.Scene;
import com.cinex.repository.SceneRepository;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ActServiceTest {
    @Test
    void reorderUsesTemporaryOrdersForSwap() {
        ActRepository acts = mock(ActRepository.class);
        List<Act> rows = new ArrayList<>(List.of(
                act(10L, 1),
                act(11L, 2)
        ));
        when(acts.findByProjectIdOrderBySequenceOrderAsc(1L)).thenAnswer(invocation ->
                rows.stream().sorted(Comparator.comparingInt(Act::getSequenceOrder)).toList());
        List<List<Integer>> flushSnapshots = new ArrayList<>();
        doAnswer(invocation -> {
            flushSnapshots.add(rows.stream().map(Act::getSequenceOrder).toList());
            return null;
        }).when(acts).flush();

        ActService service = new ActService(acts, mock(SceneRepository.class), mock(ProjectAccessService.class));

        service.reorder(1L, List.of(new ReorderItem(10L, 2), new ReorderItem(11L, 1)));

        assertThat(flushSnapshots).containsExactly(
                List.of(3, 4),
                List.of(2, 1)
        );
    }

    @Test
    void reorderRejectsOrderUsedByUntouchedAct() {
        ActRepository acts = mock(ActRepository.class);
        when(acts.findByProjectIdOrderBySequenceOrderAsc(1L)).thenReturn(List.of(
                act(10L, 1),
                act(11L, 2)
        ));
        ActService service = new ActService(acts, mock(SceneRepository.class), mock(ProjectAccessService.class));

        assertThatThrownBy(() -> service.reorder(1L, List.of(new ReorderItem(10L, 2))))
                .isInstanceOf(ConflictException.class)
                .hasMessageContaining("sequenceOrder");
    }

    @Test
    void deleteRemovesScenesBeforeAct() {
        ActRepository acts = mock(ActRepository.class);
        SceneRepository scenes = mock(SceneRepository.class);
        Act act = act(10L, 1);
        List<Scene> children = List.of(new Scene(), new Scene());
        when(acts.findByIdAndProjectId(10L, 1L)).thenReturn(java.util.Optional.of(act));
        when(scenes.findByActIdAndProjectIdOrderBySceneNumberAsc(10L, 1L)).thenReturn(children);
        ActService service = new ActService(acts, scenes, mock(ProjectAccessService.class));

        service.delete(1L, 10L);

        verify(scenes).deleteAll(children);
        verify(scenes).flush();
        verify(acts).delete(act);
    }

    private static Act act(Long id, int sequenceOrder) {
        Project project = new Project();
        project.setId(1L);
        Act act = new Act();
        act.setId(id);
        act.setProject(project);
        act.setTitle("Act " + sequenceOrder);
        act.setSequenceOrder(sequenceOrder);
        return act;
    }
}
