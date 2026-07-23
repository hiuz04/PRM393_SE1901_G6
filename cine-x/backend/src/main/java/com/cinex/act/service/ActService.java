package com.cinex.act.service;

import com.cinex.act.domain.Act;
import com.cinex.act.dto.ActDtos.ActRequest;
import com.cinex.act.dto.ActDtos.ActResponse;
import com.cinex.act.dto.ActDtos.ReorderItem;
import com.cinex.act.repository.ActRepository;
import com.cinex.common.exception.BadRequestException;
import com.cinex.common.exception.ConflictException;
import com.cinex.common.exception.NotFoundException;
import com.cinex.project.domain.Project;
import com.cinex.project.service.ProjectAccessService;
import com.cinex.scene.repository.SceneRepository;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ActService {
    private final ActRepository actRepository;
    private final SceneRepository sceneRepository;
    private final ProjectAccessService accessService;

    public ActService(ActRepository actRepository, SceneRepository sceneRepository,
                      ProjectAccessService accessService) {
        this.actRepository = actRepository;
        this.sceneRepository = sceneRepository;
        this.accessService = accessService;
    }

    public List<ActResponse> list(Long projectId) {
        accessService.requireVisibleProject(projectId);
        return actRepository.findByProjectIdOrderBySequenceOrderAsc(projectId).stream().map(this::toResponse).toList();
    }

    @Transactional
    public ActResponse create(Long projectId, ActRequest request) {
        accessService.requireStructureEditor(projectId);
        Project project = accessService.requireVisibleProject(projectId);
        if (actRepository.existsByProjectIdAndSequenceOrder(projectId, request.sequenceOrder())) {
            throw new ConflictException("sequenceOrder da ton tai");
        }
        Act act = new Act();
        act.setProject(project);
        apply(act, request);
        return toResponse(actRepository.save(act));
    }

    public ActResponse get(Long projectId, Long actId) {
        accessService.requireVisibleProject(projectId);
        return toResponse(requireAct(projectId, actId));
    }

    @Transactional
    public ActResponse update(Long projectId, Long actId, ActRequest request) {
        accessService.requireStructureEditor(projectId);
        Act act = requireAct(projectId, actId);
        if (act.getSequenceOrder() != request.sequenceOrder()
                && actRepository.existsByProjectIdAndSequenceOrder(projectId, request.sequenceOrder())) {
            throw new ConflictException("sequenceOrder da ton tai");
        }
        apply(act, request);
        return toResponse(act);
    }

    @Transactional
    public void delete(Long projectId, Long actId) {
        accessService.requireStructureEditor(projectId);
        Act act = requireAct(projectId, actId);
        List<com.cinex.scene.domain.Scene> scenes =
                sceneRepository.findByActIdAndProjectIdOrderBySceneNumberAsc(actId, projectId);
        if (!scenes.isEmpty()) {
            sceneRepository.deleteAll(scenes);
            sceneRepository.flush();
        }
        actRepository.delete(act);
    }

    @Transactional
    public List<ActResponse> reorder(Long projectId, List<ReorderItem> items) {
        accessService.requireStructureEditor(projectId);
        List<Act> acts = actRepository.findByProjectIdOrderBySequenceOrderAsc(projectId);
        Map<Long, Act> actsById = new LinkedHashMap<>();
        Map<Act, Integer> targetOrders = new LinkedHashMap<>();
        int maxCurrentOrder = 0;
        for (Act act : acts) {
            actsById.put(act.getId(), act);
            maxCurrentOrder = Math.max(maxCurrentOrder, act.getSequenceOrder());
        }

        Set<Long> actIds = new HashSet<>();
        Set<Integer> requestedOrders = new HashSet<>();
        for (ReorderItem item : items) {
            if (item.sequenceOrder() < 1) {
                throw new BadRequestException("sequenceOrder phai >= 1");
            }
            if (!actIds.add(item.actId())) {
                throw new BadRequestException("actId bi trung");
            }
            if (!requestedOrders.add(item.sequenceOrder())) {
                throw new BadRequestException("sequenceOrder bi trung");
            }
            Act act = actsById.get(item.actId());
            if (act == null) {
                throw new NotFoundException("Khong tim thay Act");
            }
            targetOrders.put(act, item.sequenceOrder());
        }

        Set<Integer> finalOrders = new HashSet<>();
        int maxFinalOrder = 0;
        for (Act act : acts) {
            int finalOrder = targetOrders.getOrDefault(act, act.getSequenceOrder());
            maxFinalOrder = Math.max(maxFinalOrder, finalOrder);
            if (!finalOrders.add(finalOrder)) {
                throw new ConflictException("sequenceOrder da ton tai");
            }
        }

        List<Map.Entry<Act, Integer>> changed = targetOrders.entrySet().stream()
                .filter(entry -> entry.getKey().getSequenceOrder() != entry.getValue())
                .toList();
        int tempOrder = Math.max(maxCurrentOrder, maxFinalOrder) + 1;
        for (Map.Entry<Act, Integer> entry : changed) {
            entry.getKey().setSequenceOrder(tempOrder++);
        }
        if (!changed.isEmpty()) {
            actRepository.flush();
        }
        for (Map.Entry<Act, Integer> entry : changed) {
            entry.getKey().setSequenceOrder(entry.getValue());
        }
        if (!changed.isEmpty()) {
            actRepository.flush();
        }
        return actRepository.findByProjectIdOrderBySequenceOrderAsc(projectId).stream().map(this::toResponse).toList();
    }

    private Act requireAct(Long projectId, Long actId) {
        return actRepository.findByIdAndProjectId(actId, projectId)
                .orElseThrow(() -> new NotFoundException("Khong tim thay Act"));
    }

    private void apply(Act act, ActRequest request) {
        if (request.sequenceOrder() < 1) {
            throw new BadRequestException("sequenceOrder phai >= 1");
        }
        String title = request.title() == null ? "" : request.title().trim();
        if (title.isBlank()) {
            throw new BadRequestException("Title bat buoc");
        }
        act.setTitle(title);
        act.setDescription(blankToNull(request.description()));
        act.setSequenceOrder(request.sequenceOrder());
    }

    private ActResponse toResponse(Act act) {
        return new ActResponse(act.getId(), act.getProject().getId(), act.getTitle(), act.getDescription(),
                act.getSequenceOrder(), act.getCreatedAt(), act.getUpdatedAt());
    }

    private String blankToNull(String value) {
        return value == null || value.trim().isBlank() ? null : value.trim();
    }
}
