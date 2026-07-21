package com.cinex.character.service;

import com.cinex.character.domain.CharacterRoleType;
import com.cinex.character.domain.StoryCharacter;
import com.cinex.character.dto.CharacterDtos.CharacterRequest;
import com.cinex.character.dto.CharacterDtos.CharacterResponse;
import com.cinex.character.repository.StoryCharacterRepository;
import com.cinex.common.exception.NotFoundException;
import com.cinex.project.domain.Project;
import com.cinex.project.service.ProjectAccessService;
import com.cinex.storage.service.StorageService;
import java.util.Locale;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class CharacterService {
    private final StoryCharacterRepository characterRepository;
    private final ProjectAccessService accessService;
    private final StorageService storageService;

    public CharacterService(StoryCharacterRepository characterRepository, ProjectAccessService accessService,
                            StorageService storageService) {
        this.characterRepository = characterRepository;
        this.accessService = accessService;
        this.storageService = storageService;
    }

    public Page<CharacterResponse> list(Long projectId, String search, CharacterRoleType roleType, Pageable pageable) {
        accessService.requireVisibleProject(projectId);
        return characterRepository.search(projectId, searchPattern(search), roleType, pageable).map(this::toResponse);
    }

    @Transactional
    public CharacterResponse create(Long projectId, CharacterRequest request) {
        accessService.requireStructureEditor(projectId);
        Project project = accessService.requireVisibleProject(projectId);
        StoryCharacter character = new StoryCharacter();
        character.setProject(project);
        apply(character, request);
        return toResponse(characterRepository.save(character));
    }

    public CharacterResponse get(Long projectId, Long characterId) {
        accessService.requireVisibleProject(projectId);
        return toResponse(require(projectId, characterId));
    }

    @Transactional
    public CharacterResponse update(Long projectId, Long characterId, CharacterRequest request) {
        accessService.requireStructureEditor(projectId);
        StoryCharacter character = require(projectId, characterId);
        apply(character, request);
        return toResponse(character);
    }

    @Transactional
    public void delete(Long projectId, Long characterId) {
        accessService.requireStructureEditor(projectId);
        StoryCharacter character = require(projectId, characterId);
        characterRepository.deleteSceneLinks(characterId);
        characterRepository.delete(character);
    }

    @Transactional
    public CharacterResponse upload(Long projectId, Long characterId, MultipartFile file) {
        accessService.requireStructureEditor(projectId);
        StoryCharacter character = require(projectId, characterId);
        character.setImageUrl(storageService.storeImage(file));
        return toResponse(character);
    }

    public CharacterResponse toResponse(StoryCharacter character) {
        return new CharacterResponse(character.getId(), character.getProject().getId(), character.getName(),
                character.getRoleType(), character.getDescription(), character.getImageUrl(),
                character.getCreatedAt(), character.getUpdatedAt());
    }

    private StoryCharacter require(Long projectId, Long characterId) {
        return characterRepository.findByIdAndProjectId(characterId, projectId)
                .orElseThrow(() -> new NotFoundException("Khong tim thay Character"));
    }

    private void apply(StoryCharacter character, CharacterRequest request) {
        character.setName(request.name().trim());
        character.setRoleType(request.roleType());
        character.setDescription(blankToNull(request.description()));
    }

    private String blankToNull(String value) {
        return value == null || value.trim().isBlank() ? null : value.trim();
    }

    private String searchPattern(String value) {
        if (value == null || value.trim().isBlank()) {
            return "%";
        }
        return "%" + value.trim().toLowerCase(Locale.ROOT) + "%";
    }
}
