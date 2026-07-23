package com.cinex.repository;

import com.cinex.domain.Act;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ActRepository extends JpaRepository<Act, Long> {
    List<Act> findByProjectIdOrderBySequenceOrderAsc(Long projectId);

    Optional<Act> findByIdAndProjectId(Long id, Long projectId);

    boolean existsByProjectIdAndSequenceOrder(Long projectId, int sequenceOrder);

    long countByProjectId(Long projectId);
}
