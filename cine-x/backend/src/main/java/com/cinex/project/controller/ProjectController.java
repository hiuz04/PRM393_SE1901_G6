package com.cinex.project.controller;

import com.cinex.common.response.ApiResponse;
import com.cinex.project.domain.ProjectStatus;
import com.cinex.project.dto.ProjectDtos.DashboardResponse;
import com.cinex.project.dto.ProjectDtos.ProjectRequest;
import com.cinex.project.dto.ProjectDtos.ProjectResponse;
import com.cinex.project.service.ProjectService;
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

@RestController
@RequestMapping("/api/v1/projects")
public class ProjectController {
    private final ProjectService projectService;

    public ProjectController(ProjectService projectService) {
        this.projectService = projectService;
    }

    @GetMapping
    ApiResponse<Page<ProjectResponse>> list(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) ProjectStatus status,
            Pageable pageable
    ) {
        return ApiResponse.ok(projectService.list(search, status, pageable));
    }

    @PostMapping
    ApiResponse<ProjectResponse> create(@Valid @RequestBody ProjectRequest request) {
        return ApiResponse.message("Tao project thanh cong", projectService.create(request));
    }

    @GetMapping("/{projectId}")
    ApiResponse<ProjectResponse> get(@PathVariable Long projectId) {
        return ApiResponse.ok(projectService.get(projectId));
    }

    @PutMapping("/{projectId}")
    ApiResponse<ProjectResponse> update(@PathVariable Long projectId, @Valid @RequestBody ProjectRequest request) {
        return ApiResponse.message("Cap nhat project thanh cong", projectService.update(projectId, request));
    }

    @DeleteMapping("/{projectId}")
    ApiResponse<Void> delete(@PathVariable Long projectId) {
        projectService.softDelete(projectId);
        return ApiResponse.message("Da xoa project", null);
    }

    @PostMapping("/{projectId}/restore")
    ApiResponse<ProjectResponse> restore(@PathVariable Long projectId) {
        return ApiResponse.message("Da khoi phuc project", projectService.restore(projectId));
    }

    @GetMapping("/{projectId}/dashboard")
    ApiResponse<DashboardResponse> dashboard(@PathVariable Long projectId) {
        return ApiResponse.ok(projectService.dashboard(projectId));
    }
}
