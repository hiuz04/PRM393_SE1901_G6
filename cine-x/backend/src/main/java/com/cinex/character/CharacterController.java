package com.cinex.character;

import com.cinex.character.dto.CharacterDtos.CharacterRequest;
import com.cinex.character.dto.CharacterDtos.CharacterResponse;
import com.cinex.common.response.ApiResponse;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/projects/{projectId}/characters")
public class CharacterController {
    private final CharacterService characterService;

    public CharacterController(CharacterService characterService) {
        this.characterService = characterService;
    }

    @GetMapping
    ApiResponse<Page<CharacterResponse>> list(@PathVariable Long projectId,
                                              @RequestParam(required = false) String search,
                                              @RequestParam(required = false) CharacterRoleType roleType,
                                              Pageable pageable) {
        return ApiResponse.ok(characterService.list(projectId, search, roleType, pageable));
    }

    @PostMapping
    ApiResponse<CharacterResponse> create(@PathVariable Long projectId,
                                          @Valid @RequestBody CharacterRequest request) {
        return ApiResponse.message("Da tao Character", characterService.create(projectId, request));
    }

    @GetMapping("/{characterId}")
    ApiResponse<CharacterResponse> get(@PathVariable Long projectId, @PathVariable Long characterId) {
        return ApiResponse.ok(characterService.get(projectId, characterId));
    }

    @PutMapping("/{characterId}")
    ApiResponse<CharacterResponse> update(@PathVariable Long projectId, @PathVariable Long characterId,
                                          @Valid @RequestBody CharacterRequest request) {
        return ApiResponse.message("Da cap nhat Character", characterService.update(projectId, characterId, request));
    }

    @DeleteMapping("/{characterId}")
    ApiResponse<Void> delete(@PathVariable Long projectId, @PathVariable Long characterId) {
        characterService.delete(projectId, characterId);
        return ApiResponse.message("Da xoa Character", null);
    }

    @PostMapping("/{characterId}/image")
    ApiResponse<CharacterResponse> upload(@PathVariable Long projectId, @PathVariable Long characterId,
                                          @RequestParam("file") MultipartFile file) {
        return ApiResponse.message("Da tai anh", characterService.upload(projectId, characterId, file));
    }
}
