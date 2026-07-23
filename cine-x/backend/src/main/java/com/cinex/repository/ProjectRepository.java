package com.cinex.repository;

import com.cinex.domain.Project;
import com.cinex.domain.ProjectStatus;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ProjectRepository extends JpaRepository<Project, Long>, JpaSpecificationExecutor<Project> {
    @Query("""
            select p from Project p
            join ProjectMember pm on pm.project = p
            where pm.user.id = :userId
              and p.deleted = false
              and lower(p.title) like :searchPattern
              and (:status is null or p.status = :status)
            """)
    Page<Project> findVisible(
            @Param("userId") Long userId,
            @Param("searchPattern") String searchPattern,
            @Param("status") ProjectStatus status,
            Pageable pageable
    );

    Optional<Project> findByIdAndDeletedFalse(Long id);
}
