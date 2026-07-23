package com.cinex.service;

import com.cinex.exception.BadRequestException;
import com.cinex.exception.ConflictException;
import com.cinex.exception.NotFoundException;
import com.cinex.domain.ProjectMember;
import com.cinex.domain.ProjectMemberId;
import com.cinex.domain.ProjectRole;
import com.cinex.dto.MemberDtos.AddMemberRequest;
import com.cinex.dto.MemberDtos.MemberResponse;
import com.cinex.dto.MemberDtos.UpdateMemberRoleRequest;
import com.cinex.repository.ProjectMemberRepository;
import com.cinex.domain.Project;
import com.cinex.domain.UserAccount;
import com.cinex.repository.UserRepository;
import java.time.Instant;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MemberService {
    private final ProjectMemberRepository memberRepository;
    private final UserRepository userRepository;
    private final ProjectAccessService accessService;

    public MemberService(ProjectMemberRepository memberRepository, UserRepository userRepository,
                         ProjectAccessService accessService) {
        this.memberRepository = memberRepository;
        this.userRepository = userRepository;
        this.accessService = accessService;
    }

    public List<MemberResponse> list(Long projectId) {
        accessService.requireVisibleProject(projectId);
        return memberRepository.findByProjectIdOrderByJoinedAtAsc(projectId).stream().map(this::toResponse).toList();
    }

    @Transactional
    public MemberResponse add(Long projectId, AddMemberRequest request) {
        accessService.requireOwner(projectId);
        Project project = accessService.requireVisibleProject(projectId);
        if (request.role() == ProjectRole.OWNER) {
            throw new BadRequestException("Khong them OWNER bang endpoint nay");
        }
        String email = request.email().trim().toLowerCase();
        UserAccount user = userRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new NotFoundException("Khong tim thay email thanh vien"));
        if (memberRepository.existsByProjectIdAndUserId(projectId, user.getId())) {
            throw new ConflictException("Nguoi dung da la thanh vien");
        }
        ProjectMember member = new ProjectMember();
        member.setId(new ProjectMemberId(projectId, user.getId()));
        member.setProject(project);
        member.setUser(user);
        member.setRole(request.role());
        member.setJoinedAt(Instant.now());
        return toResponse(memberRepository.save(member));
    }

    @Transactional
    public MemberResponse update(Long projectId, Long userId, UpdateMemberRoleRequest request) {
        accessService.requireOwner(projectId);
        ProjectMember member = memberRepository.findByProjectIdAndUserId(projectId, userId)
                .orElseThrow(() -> new NotFoundException("Khong tim thay thanh vien"));
        if (member.getRole() == ProjectRole.OWNER && request.role() != ProjectRole.OWNER
                && memberRepository.countByProjectIdAndRole(projectId, ProjectRole.OWNER) <= 1) {
            throw new BadRequestException("Khong the ha quyen OWNER cuoi cung");
        }
        member.setRole(request.role());
        return toResponse(member);
    }

    @Transactional
    public void remove(Long projectId, Long userId) {
        accessService.requireOwner(projectId);
        ProjectMember member = memberRepository.findByProjectIdAndUserId(projectId, userId)
                .orElseThrow(() -> new NotFoundException("Khong tim thay thanh vien"));
        if (member.getRole() == ProjectRole.OWNER
                && memberRepository.countByProjectIdAndRole(projectId, ProjectRole.OWNER) <= 1) {
            throw new BadRequestException("Khong the xoa OWNER cuoi cung");
        }
        memberRepository.delete(member);
    }

    private MemberResponse toResponse(ProjectMember member) {
        return new MemberResponse(member.getUser().getId(), member.getUser().getEmail(),
                member.getUser().getDisplayName(), member.getRole(), member.getJoinedAt());
    }
}
