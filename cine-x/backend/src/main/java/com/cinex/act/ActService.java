package com.cinex.act;

import com.cinex.act.dto.ActDtos.ActRequest;
import com.cinex.act.dto.ActDtos.ActResponse;
import com.cinex.act.dto.ActDtos.ReorderItem;
import com.cinex.common.exception.BadRequestException;
import com.cinex.common.exception.ConflictException;
import com.cinex.common.exception.NotFoundException;
import com.cinex.project.Project;
import com.cinex.project.ProjectAccessService;
import com.cinex.scene.SceneRepository;
import java.util.HashSet;
import java.util.List;
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
        if (sceneRepository.countByActId(actId) > 0) {
            throw new BadRequestException("Khong the xoa Act dang co Scene");
        }
        actRepository.delete(act);
    }

    @Transactional
    public List<ActResponse> reorder(Long projectId, List<ReorderItem> items) {
        accessService.requireStructureEditor(projectId);
        Set<Integer> orders = new HashSet<>();
        for (ReorderItem item : items) {
            if (!orders.add(item.sequenceOrder())) {
                throw new BadRequestException("sequenceOrder bi trung");
            }
        }
        for (ReorderItem item : items) {
            Act act = requireAct(projectId, item.actId());
            act.setSequenceOrder(item.sequenceOrder());
        }
        return list(projectId);
    }

    private Act requireAct(Long projectId, Long actId) {
        return actRepository.findByIdAndProjectId(actId, projectId)
                .orElseThrow(() -> new NotFoundException("Khong tim thay Act"));
    }

    private void apply(Act act, ActRequest request) {
        if (request.sequenceOrder() < 1) {
            throw new BadRequestException("sequenceOrder phai >= 1");
        }
        act.setTitle(request.title().trim());
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
