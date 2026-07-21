package com.cinex.act.controller;

import com.cinex.act.dto.ActDtos.ActRequest;
import com.cinex.act.dto.ActDtos.ActResponse;
import com.cinex.act.dto.ActDtos.ReorderRequest;
import com.cinex.act.service.ActService;
import com.cinex.common.response.ApiResponse;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/projects/{projectId}/acts")
public class ActController {
    private final ActService actService;

    public ActController(ActService actService) {
        this.actService = actService;
    }

    @GetMapping
    ApiResponse<List<ActResponse>> list(@PathVariable Long projectId) {
        return ApiResponse.ok(actService.list(projectId));
    }

    @PostMapping
    ApiResponse<ActResponse> create(@PathVariable Long projectId, @Valid @RequestBody ActRequest request) {
        return ApiResponse.message("Da tao Act", actService.create(projectId, request));
    }

    @GetMapping("/{actId}")
    ApiResponse<ActResponse> get(@PathVariable Long projectId, @PathVariable Long actId) {
        return ApiResponse.ok(actService.get(projectId, actId));
    }

    @PutMapping("/{actId}")
    ApiResponse<ActResponse> update(@PathVariable Long projectId, @PathVariable Long actId,
                                    @Valid @RequestBody ActRequest request) {
        return ApiResponse.message("Da cap nhat Act", actService.update(projectId, actId, request));
    }

    @DeleteMapping("/{actId}")
    ApiResponse<Void> delete(@PathVariable Long projectId, @PathVariable Long actId) {
        actService.delete(projectId, actId);
        return ApiResponse.message("Da xoa Act", null);
    }

    @PutMapping("/reorder")
    ApiResponse<List<ActResponse>> reorder(@PathVariable Long projectId,
                                           @Valid @RequestBody ReorderRequest request) {
        return ApiResponse.message("Da sap xep Act", actService.reorder(projectId, request.items()));
    }
}
