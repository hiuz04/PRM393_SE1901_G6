package com.cinex.service;

import com.cinex.repository.ActRepository;
import com.cinex.repository.StoryCharacterRepository;
import com.cinex.exception.BadRequestException;
import com.cinex.repository.StoryLocationRepository;
import com.cinex.domain.ProjectMember;
import com.cinex.domain.ProjectMemberId;
import com.cinex.domain.ProjectRole;
import com.cinex.repository.ProjectMemberRepository;
import com.cinex.domain.Project;
import com.cinex.domain.ProjectStatus;
import com.cinex.dto.ProjectDtos.DashboardResponse;
import com.cinex.dto.ProjectDtos.ProjectRequest;
import com.cinex.dto.ProjectDtos.ProjectResponse;
import com.cinex.repository.ProjectRepository;
import com.cinex.domain.SceneStatus;
import com.cinex.repository.SceneRepository;
import com.cinex.domain.UserAccount;
import java.util.Locale;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProjectService {
    private final ProjectRepository projectRepository;
    private final ProjectMemberRepository memberRepository;
    private final ProjectAccessService accessService;
    private final ActRepository actRepository;
    private final StoryCharacterRepository characterRepository;
    private final StoryLocationRepository locationRepository;
    private final SceneRepository sceneRepository;

    public ProjectService(
            ProjectRepository projectRepository,
            ProjectMemberRepository memberRepository,
            ProjectAccessService accessService,
            ActRepository actRepository,
            StoryCharacterRepository characterRepository,
            StoryLocationRepository locationRepository,
            SceneRepository sceneRepository
    ) {
        this.projectRepository = projectRepository;
        this.memberRepository = memberRepository;
        this.accessService = accessService;
        this.actRepository = actRepository;
        this.characterRepository = characterRepository;
        this.locationRepository = locationRepository;
        this.sceneRepository = sceneRepository;
    }

    public Page<ProjectResponse> list(String search, ProjectStatus status, Pageable pageable) {
        return projectRepository.findVisible(accessService.currentUser().getId(), searchPattern(search), status, pageable)
                .map(this::toResponse);
    }

    @Transactional
    public ProjectResponse create(ProjectRequest request) {
        UserAccount user = accessService.currentUser();
        Project project = new Project();
        apply(project, request);
        project.setOwner(user);
        Project saved = projectRepository.save(project);

        ProjectMember member = new ProjectMember();
        member.setId(new ProjectMemberId(saved.getId(), user.getId()));
        member.setProject(saved);
        member.setUser(user);
        member.setRole(ProjectRole.OWNER);
        memberRepository.save(member);
        return toResponse(saved);
    }

    public ProjectResponse get(Long projectId) {
        return toResponse(accessService.requireVisibleProject(projectId));
    }

    @Transactional
    public ProjectResponse update(Long projectId, ProjectRequest request) {
        accessService.requireStructureEditor(projectId);
        Project project = accessService.requireVisibleProject(projectId);
        apply(project, request);
        return toResponse(project);
    }

    @Transactional
    public void softDelete(Long projectId) {
        accessService.requireOwner(projectId);
        Project project = accessService.requireVisibleProject(projectId);
        project.setDeleted(true);
    }

    @Transactional
    public ProjectResponse restore(Long projectId) {
        accessService.requireOwner(projectId);
        Project project = accessService.requireProject(projectId);
        project.setDeleted(false);
        return toResponse(project);
    }

    public DashboardResponse dashboard(Long projectId) {
        Project project = accessService.requireVisibleProject(projectId);
        long totalScenes = sceneRepository.countByProjectId(projectId);
        long done = sceneRepository.countByProjectIdAndStatus(projectId, SceneStatus.DONE);
        long todo = sceneRepository.countByProjectIdAndStatus(projectId, SceneStatus.TODO);
        long inProgress = sceneRepository.countByProjectIdAndStatus(projectId, SceneStatus.IN_PROGRESS);
        double progress = totalScenes == 0 ? 0 : done * 100.0 / totalScenes;
        return new DashboardResponse(
                withProgress(project, progress),
                actRepository.countByProjectId(projectId),
                characterRepository.countByProjectId(projectId),
                locationRepository.countByProjectId(projectId),
                totalScenes,
                todo,
                inProgress,
                done,
                progress
        );
    }

    public ProjectResponse toResponse(Project project) {
        long total = project.getId() == null ? 0 : sceneRepository.countByProjectId(project.getId());
        long done = project.getId() == null ? 0 : sceneRepository.countByProjectIdAndStatus(project.getId(), SceneStatus.DONE);
        double progress = total == 0 ? 0 : done * 100.0 / total;
        return withProgress(project, progress);
    }

    private ProjectResponse withProgress(Project project, double progress) {
        return new ProjectResponse(project.getId(), project.getOwner().getId(), project.getTitle(), project.getGenre(),
                project.getDescription(), project.getStartDate(), project.getPosterUrl(), project.getStatus(),
                project.isDeleted(), progress, project.getCreatedAt(), project.getUpdatedAt());
    }

    private void apply(Project project, ProjectRequest request) {
        String title = Optional.ofNullable(request.title()).map(String::trim).orElse("");
        if (title.isBlank()) {
            throw new BadRequestException("Title bat buoc");
        }
        project.setTitle(title);
        project.setGenre(blankToNull(request.genre()));
        project.setDescription(blankToNull(request.description()));
        project.setStartDate(request.startDate());
        project.setPosterUrl(blankToNull(request.posterUrl()));
        if (request.status() != null) {
            project.setStatus(request.status());
        }
    }

    private String blankToNull(String value) {
        if (value == null || value.trim().isBlank()) {
            return null;
        }
        return value.trim();
    }

    private String searchPattern(String value) {
        if (value == null || value.trim().isBlank()) {
            return "%";
        }
        return "%" + value.trim().toLowerCase(Locale.ROOT) + "%";
    }
}
