package com.cinex.scene.service;

import com.cinex.act.domain.Act;
import com.cinex.act.repository.ActRepository;
import com.cinex.character.domain.StoryCharacter;
import com.cinex.character.repository.StoryCharacterRepository;
import com.cinex.common.exception.BadRequestException;
import com.cinex.common.exception.ConflictException;
import com.cinex.common.exception.NotFoundException;
import com.cinex.location.domain.SettingType;
import com.cinex.location.domain.StoryLocation;
import com.cinex.location.domain.TimeOfDay;
import com.cinex.location.repository.StoryLocationRepository;
import com.cinex.project.domain.Project;
import com.cinex.project.service.ProjectAccessService;
import com.cinex.scene.domain.Scene;
import com.cinex.scene.domain.SceneStatus;
import com.cinex.scene.dto.SceneDtos.ReorderItem;
import com.cinex.scene.dto.SceneDtos.SceneCharacterBrief;
import com.cinex.scene.dto.SceneDtos.SceneRequest;
import com.cinex.scene.dto.SceneDtos.SceneResponse;
import com.cinex.scene.repository.SceneRepository;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SceneService {
    private final SceneRepository sceneRepository;
    private final ActRepository actRepository;
    private final StoryLocationRepository locationRepository;
    private final StoryCharacterRepository characterRepository;
    private final ProjectAccessService accessService;

    public SceneService(SceneRepository sceneRepository, ActRepository actRepository,
                        StoryLocationRepository locationRepository,
                        StoryCharacterRepository characterRepository,
                        ProjectAccessService accessService) {
        this.sceneRepository = sceneRepository;
        this.actRepository = actRepository;
        this.locationRepository = locationRepository;
        this.characterRepository = characterRepository;
        this.accessService = accessService;
    }

    @Transactional(readOnly = true)
    public Page<SceneResponse> list(Long projectId, String search, Long actId, Long locationId,
                                    Long characterId, SettingType settingType, TimeOfDay timeOfDay,
                                    SceneStatus status, Pageable pageable) {
        accessService.requireVisibleProject(projectId);
        return sceneRepository.findAll(filter(projectId, search, actId, locationId, characterId,
                settingType, timeOfDay, status), pageable).map(this::toResponse);
    }

    @Transactional
    public SceneResponse create(Long projectId, SceneRequest request) {
        accessService.requireStructureEditor(projectId);
        Project project = accessService.requireVisibleProject(projectId);
        if (sceneRepository.existsByProjectIdAndSceneNumber(projectId, request.sceneNumber())) {
            throw new ConflictException("sceneNumber da ton tai");
        }
        Scene scene = new Scene();
        scene.setProject(project);
        apply(projectId, scene, request);
        return toResponse(sceneRepository.save(scene));
    }

    @Transactional(readOnly = true)
    public SceneResponse get(Long projectId, Long sceneId) {
        accessService.requireVisibleProject(projectId);
        return toResponse(requireScene(projectId, sceneId));
    }

    @Transactional
    public SceneResponse update(Long projectId, Long sceneId, SceneRequest request) {
        accessService.requireStructureEditor(projectId);
        Scene scene = requireScene(projectId, sceneId);
        if (scene.getSceneNumber() != request.sceneNumber()
                && sceneRepository.existsByProjectIdAndSceneNumber(projectId, request.sceneNumber())) {
            throw new ConflictException("sceneNumber da ton tai");
        }
        apply(projectId, scene, request);
        return toResponse(scene);
    }

    @Transactional
    public void delete(Long projectId, Long sceneId) {
        accessService.requireStructureEditor(projectId);
        sceneRepository.delete(requireScene(projectId, sceneId));
    }

    @Transactional
    public SceneResponse updateStatus(Long projectId, Long sceneId, SceneStatus status) {
        accessService.requireStatusEditor(projectId);
        Scene scene = requireScene(projectId, sceneId);
        scene.setStatus(status);
        return toResponse(scene);
    }

    @Transactional
    public List<SceneResponse> reorder(Long projectId, List<ReorderItem> items) {
        accessService.requireStructureEditor(projectId);
        List<Scene> scenes = sceneRepository.findByProjectIdOrderBySceneNumberAsc(projectId);
        Map<Long, Scene> scenesById = new LinkedHashMap<>();
        Map<Scene, Integer> targetNumbers = new LinkedHashMap<>();
        int maxCurrentNumber = 0;
        for (Scene scene : scenes) {
            scenesById.put(scene.getId(), scene);
            maxCurrentNumber = Math.max(maxCurrentNumber, scene.getSceneNumber());
        }

        Set<Long> sceneIds = new HashSet<>();
        Set<Integer> requestedNumbers = new HashSet<>();
        for (ReorderItem item : items) {
            if (item.sceneNumber() < 1) {
                throw new BadRequestException("sceneNumber phai >= 1");
            }
            if (!sceneIds.add(item.sceneId())) {
                throw new BadRequestException("sceneId bi trung");
            }
            if (!requestedNumbers.add(item.sceneNumber())) {
                throw new BadRequestException("sceneNumber bi trung");
            }
            Scene scene = scenesById.get(item.sceneId());
            if (scene == null) {
                throw new NotFoundException("Khong tim thay Scene");
            }
            targetNumbers.put(scene, item.sceneNumber());
        }

        Set<Integer> finalNumbers = new HashSet<>();
        int maxFinalNumber = 0;
        for (Scene scene : scenes) {
            int finalNumber = targetNumbers.getOrDefault(scene, scene.getSceneNumber());
            maxFinalNumber = Math.max(maxFinalNumber, finalNumber);
            if (!finalNumbers.add(finalNumber)) {
                throw new ConflictException("sceneNumber da ton tai");
            }
        }

        List<Map.Entry<Scene, Integer>> changed = targetNumbers.entrySet().stream()
                .filter(entry -> entry.getKey().getSceneNumber() != entry.getValue())
                .toList();
        int tempNumber = Math.max(maxCurrentNumber, maxFinalNumber) + 1;
        for (Map.Entry<Scene, Integer> entry : changed) {
            entry.getKey().setSceneNumber(tempNumber++);
        }
        if (!changed.isEmpty()) {
            sceneRepository.flush();
        }
        for (Map.Entry<Scene, Integer> entry : changed) {
            entry.getKey().setSceneNumber(entry.getValue());
        }
        if (!changed.isEmpty()) {
            sceneRepository.flush();
        }
        return sceneRepository.findByProjectIdOrderBySceneNumberAsc(projectId).stream().map(this::toResponse).toList();
    }

    private void apply(Long projectId, Scene scene, SceneRequest request) {
        if (request.sceneNumber() < 1) {
            throw new BadRequestException("sceneNumber phai >= 1");
        }
        if (request.status() == null) {
            throw new BadRequestException("Status bat buoc");
        }
        if (request.estimatedMinutes() != null && request.estimatedMinutes() < 1) {
            throw new BadRequestException("estimatedMinutes phai >= 1");
        }
        if (request.actId() == null) {
            throw new BadRequestException("Act bat buoc");
        }
        if (request.locationId() == null) {
            throw new BadRequestException("Location bat buoc");
        }
        Act act = actRepository.findByIdAndProjectId(request.actId(), projectId)
                .orElseThrow(() -> new BadRequestException("Act khong thuoc project"));
        StoryLocation location = locationRepository.findByIdAndProjectId(request.locationId(), projectId)
                .orElseThrow(() -> new BadRequestException("Location khong thuoc project"));
        String summary = request.summary() == null ? "" : request.summary().trim();
        if (summary.isBlank()) {
            throw new BadRequestException("Summary bat buoc");
        }
        scene.setAct(act);
        scene.setLocation(location);
        scene.setSceneNumber(request.sceneNumber());
        scene.setTitle(blankToNull(request.title()));
        scene.setSummary(summary);
        scene.setStatus(request.status());
        scene.setEstimatedMinutes(request.estimatedMinutes());
        scene.setCharacters(resolveCharacters(projectId, request.characterIds()));
    }

    private Set<StoryCharacter> resolveCharacters(Long projectId, List<Long> characterIds) {
        if (characterIds == null || characterIds.isEmpty()) {
            return new LinkedHashSet<>();
        }
        Set<Long> unique = new LinkedHashSet<>(characterIds);
        if (unique.size() != characterIds.size()) {
            throw new BadRequestException("characterIds khong duoc trung");
        }
        List<StoryCharacter> characters = characterRepository.findByIdInAndProjectId(unique, projectId);
        if (characters.size() != unique.size()) {
            throw new BadRequestException("Tat ca Character phai thuoc cung project");
        }
        return new LinkedHashSet<>(characters);
    }

    private Scene requireScene(Long projectId, Long sceneId) {
        return sceneRepository.findByIdAndProjectId(sceneId, projectId)
                .orElseThrow(() -> new NotFoundException("Khong tim thay Scene"));
    }

    private Specification<Scene> filter(Long projectId, String search, Long actId, Long locationId,
                                        Long characterId, SettingType settingType, TimeOfDay timeOfDay,
                                        SceneStatus status) {
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.equal(root.get("project").get("id"), projectId));
            if (search != null && !search.trim().isBlank()) {
                String like = "%" + search.trim().toLowerCase() + "%";
                predicates.add(cb.or(
                        cb.like(cb.lower(root.get("title")), like),
                        cb.like(cb.lower(root.get("summary")), like)
                ));
            }
            if (actId != null) {
                predicates.add(cb.equal(root.get("act").get("id"), actId));
            }
            if (locationId != null) {
                predicates.add(cb.equal(root.get("location").get("id"), locationId));
            }
            if (characterId != null) {
                predicates.add(cb.equal(root.join("characters", JoinType.INNER).get("id"), characterId));
                query.distinct(true);
            }
            if (settingType != null) {
                predicates.add(cb.equal(root.get("location").get("settingType"), settingType));
            }
            if (timeOfDay != null) {
                predicates.add(cb.equal(root.get("location").get("timeOfDay"), timeOfDay));
            }
            if (status != null) {
                predicates.add(cb.equal(root.get("status"), status));
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
    }

    public SceneResponse toResponse(Scene scene) {
        List<SceneCharacterBrief> characters = scene.getCharacters().stream()
                .map(character -> new SceneCharacterBrief(character.getId(), character.getName(),
                        character.getRoleType(), character.getImageUrl()))
                .toList();
        return new SceneResponse(scene.getId(), scene.getProject().getId(), scene.getAct().getId(),
                scene.getAct().getTitle(), scene.getLocation().getId(), scene.getLocation().getName(),
                scene.getLocation().getSettingType(), scene.getLocation().getTimeOfDay(),
                scene.getSceneNumber(), scene.getTitle(), scene.getSummary(), scene.getStatus(),
                scene.getEstimatedMinutes(), characters, scene.getCreatedAt(), scene.getUpdatedAt());
    }

    private String blankToNull(String value) {
        return value == null || value.trim().isBlank() ? null : value.trim();
    }
}
