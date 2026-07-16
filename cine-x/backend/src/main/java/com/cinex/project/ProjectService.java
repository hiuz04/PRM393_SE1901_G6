package com.cinex.project;

import com.cinex.common.exception.BadRequestException;
import com.cinex.member.ProjectMember;
import com.cinex.member.ProjectMemberId;
import com.cinex.member.ProjectMemberRepository;
import com.cinex.member.ProjectRole;
import com.cinex.project.dto.ProjectDtos.DashboardResponse;
import com.cinex.project.dto.ProjectDtos.ProjectRequest;
import com.cinex.project.dto.ProjectDtos.ProjectResponse;
import com.cinex.user.UserAccount;
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
    private final com.cinex.act.ActRepository actRepository;
    private final com.cinex.character.StoryCharacterRepository characterRepository;
    private final com.cinex.location.StoryLocationRepository locationRepository;
    private final com.cinex.scene.SceneRepository sceneRepository;

    public ProjectService(
            ProjectRepository projectRepository,
            ProjectMemberRepository memberRepository,
            ProjectAccessService accessService,
            com.cinex.act.ActRepository actRepository,
            com.cinex.character.StoryCharacterRepository characterRepository,
            com.cinex.location.StoryLocationRepository locationRepository,
            com.cinex.scene.SceneRepository sceneRepository
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
        long done = sceneRepository.countByProjectIdAndStatus(projectId, com.cinex.scene.SceneStatus.DONE);
        long todo = sceneRepository.countByProjectIdAndStatus(projectId, com.cinex.scene.SceneStatus.TODO);
        long inProgress = sceneRepository.countByProjectIdAndStatus(projectId, com.cinex.scene.SceneStatus.IN_PROGRESS);
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
        long done = project.getId() == null ? 0 : sceneRepository.countByProjectIdAndStatus(project.getId(), com.cinex.scene.SceneStatus.DONE);
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
