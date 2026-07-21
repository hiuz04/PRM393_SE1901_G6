package com.cinex.scene.repository;

import com.cinex.scene.domain.Scene;
import com.cinex.scene.domain.SceneStatus;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SceneRepository extends JpaRepository<Scene, Long>, JpaSpecificationExecutor<Scene> {
    @EntityGraph(attributePaths = {"act", "location", "characters"})
    Optional<Scene> findByIdAndProjectId(Long id, Long projectId);

    List<Scene> findByProjectIdOrderBySceneNumberAsc(Long projectId);

    boolean existsByProjectIdAndSceneNumber(Long projectId, int sceneNumber);

    long countByProjectId(Long projectId);

    long countByProjectIdAndStatus(Long projectId, SceneStatus status);

    long countByActId(Long actId);

    long countByLocationId(Long locationId);

    @Query("""
            select c.id, c.name, count(s.id)
            from Scene s join s.characters c
            where s.project.id = :projectId
            group by c.id, c.name
            order by count(s.id) desc, c.name asc
            """)
    List<Object[]> characterFrequency(@Param("projectId") Long projectId);

    @EntityGraph(attributePaths = {"act", "location", "characters"})
    List<Scene> findByLocationIdInOrderBySceneNumberAsc(Collection<Long> locationIds);
}
