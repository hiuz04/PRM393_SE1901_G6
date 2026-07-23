package com.cinex.member.repository;

import com.cinex.member.domain.ProjectMember;
import com.cinex.member.domain.ProjectMemberId;
import com.cinex.member.domain.ProjectRole;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProjectMemberRepository extends JpaRepository<ProjectMember, ProjectMemberId> {
    Optional<ProjectMember> findByProjectIdAndUserId(Long projectId, Long userId);

    List<ProjectMember> findByProjectIdOrderByJoinedAtAsc(Long projectId);

    long countByProjectIdAndRole(Long projectId, ProjectRole role);

    boolean existsByProjectIdAndUserId(Long projectId, Long userId);
}
