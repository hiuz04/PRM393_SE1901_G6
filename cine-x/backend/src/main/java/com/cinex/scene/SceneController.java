package com.cinex.scene;

import com.cinex.common.response.ApiResponse;
import com.cinex.location.SettingType;
import com.cinex.location.TimeOfDay;
import com.cinex.scene.dto.SceneDtos.ReorderRequest;
import com.cinex.scene.dto.SceneDtos.SceneRequest;
import com.cinex.scene.dto.SceneDtos.SceneResponse;
import com.cinex.scene.dto.SceneDtos.StatusUpdateRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/projects/{projectId}/scenes")
public class SceneController {
    private final SceneService sceneService;

    public SceneController(SceneService sceneService) {
        this.sceneService = sceneService;
    }

    @GetMapping
    ApiResponse<Page<SceneResponse>> list(
            @PathVariable Long projectId,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) Long actId,
            @RequestParam(required = false) Long locationId,
            @RequestParam(required = false) Long characterId,
            @RequestParam(required = false) SettingType settingType,
            @RequestParam(required = false) TimeOfDay timeOfDay,
            @RequestParam(required = false) SceneStatus status,
            @PageableDefault(sort = "sceneNumber") Pageable pageable
    ) {
        return ApiResponse.ok(sceneService.list(projectId, search, actId, locationId, characterId,
                settingType, timeOfDay, status, pageable));
    }

    @PostMapping
    ApiResponse<SceneResponse> create(@PathVariable Long projectId, @Valid @RequestBody SceneRequest request) {
        return ApiResponse.message("Da tao Scene", sceneService.create(projectId, request));
    }

    @GetMapping("/{sceneId}")
    ApiResponse<SceneResponse> get(@PathVariable Long projectId, @PathVariable Long sceneId) {
        return ApiResponse.ok(sceneService.get(projectId, sceneId));
    }

    @PutMapping("/{sceneId}")
    ApiResponse<SceneResponse> update(@PathVariable Long projectId, @PathVariable Long sceneId,
                                      @Valid @RequestBody SceneRequest request) {
        return ApiResponse.message("Da cap nhat Scene", sceneService.update(projectId, sceneId, request));
    }

    @DeleteMapping("/{sceneId}")
    ApiResponse<Void> delete(@PathVariable Long projectId, @PathVariable Long sceneId) {
        sceneService.delete(projectId, sceneId);
        return ApiResponse.message("Da xoa Scene", null);
    }

    @PatchMapping("/{sceneId}/status")
    ApiResponse<SceneResponse> status(@PathVariable Long projectId, @PathVariable Long sceneId,
                                      @Valid @RequestBody StatusUpdateRequest request) {
        return ApiResponse.message("Da cap nhat status", sceneService.updateStatus(projectId, sceneId, request.status()));
    }

    @PutMapping("/reorder")
    ApiResponse<List<SceneResponse>> reorder(@PathVariable Long projectId,
                                             @Valid @RequestBody ReorderRequest request) {
        return ApiResponse.message("Da sap xep Scene", sceneService.reorder(projectId, request.items()));
    }
}
