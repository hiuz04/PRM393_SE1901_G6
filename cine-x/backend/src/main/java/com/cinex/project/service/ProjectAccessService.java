package com.cinex.project.service;

import com.cinex.common.exception.ForbiddenException;
import com.cinex.common.exception.NotFoundException;
import com.cinex.member.domain.ProjectMember;
import com.cinex.member.domain.ProjectRole;
import com.cinex.member.repository.ProjectMemberRepository;
import com.cinex.project.domain.Project;
import com.cinex.project.repository.ProjectRepository;
import com.cinex.security.domain.AppUserDetails;
import com.cinex.user.domain.UserAccount;
import com.cinex.user.repository.UserRepository;
import java.util.Arrays;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

@Service
public class ProjectAccessService {
    private final UserRepository userRepository;
    private final ProjectRepository projectRepository;
    private final ProjectMemberRepository memberRepository;

    public ProjectAccessService(
            UserRepository userRepository,
            ProjectRepository projectRepository,
            ProjectMemberRepository memberRepository
    ) {
        this.userRepository = userRepository;
        this.projectRepository = projectRepository;
        this.memberRepository = memberRepository;
    }

    public UserAccount currentUser() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof AppUserDetails details)) {
            throw new ForbiddenException("Can dang nhap");
        }
        return userRepository.findById(details.getId())
                .orElseThrow(() -> new NotFoundException("Khong tim thay nguoi dung"));
    }

    public Project requireProject(Long projectId) {
        return projectRepository.findById(projectId)
                .orElseThrow(() -> new NotFoundException("Khong tim thay project"));
    }

    public Project requireVisibleProject(Long projectId) {
        Project project = requireProject(projectId);
        requireMember(projectId);
        if (project.isDeleted()) {
            throw new NotFoundException("Project da bi xoa");
        }
        return project;
    }

    public ProjectMember requireMember(Long projectId) {
        Long userId = currentUser().getId();
        return memberRepository.findByProjectIdAndUserId(projectId, userId)
                .orElseThrow(() -> new ForbiddenException("Ban khong thuoc project nay"));
    }

    public ProjectRole currentRole(Long projectId) {
        return requireMember(projectId).getRole();
    }

    public void requireOwner(Long projectId) {
        requireRoles(projectId, ProjectRole.OWNER);
    }

    public void requireStructureEditor(Long projectId) {
        requireRoles(projectId, ProjectRole.OWNER, ProjectRole.SCREENWRITER);
    }

    public void requireStatusEditor(Long projectId) {
        requireRoles(projectId, ProjectRole.OWNER, ProjectRole.SCREENWRITER,
                ProjectRole.PRODUCER, ProjectRole.ASSISTANT_DIRECTOR);
    }

    public void requireRoles(Long projectId, ProjectRole... roles) {
        ProjectRole current = currentRole(projectId);
        if (Arrays.stream(roles).noneMatch(role -> role == current)) {
            throw new ForbiddenException("Vai tro khong du quyen");
        }
    }
}
