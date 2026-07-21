package com.cinex.character.repository;

import com.cinex.character.domain.CharacterRoleType;
import com.cinex.character.domain.StoryCharacter;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface StoryCharacterRepository extends JpaRepository<StoryCharacter, Long> {
    Optional<StoryCharacter> findByIdAndProjectId(Long id, Long projectId);

    List<StoryCharacter> findByIdInAndProjectId(Collection<Long> ids, Long projectId);

    List<StoryCharacter> findByProjectIdOrderByNameAsc(Long projectId);

    @Query("""
            select c from StoryCharacter c
            where c.project.id = :projectId
              and lower(c.name) like :searchPattern
              and (:roleType is null or c.roleType = :roleType)
            """)
    Page<StoryCharacter> search(@Param("projectId") Long projectId, @Param("searchPattern") String searchPattern,
                                @Param("roleType") CharacterRoleType roleType, Pageable pageable);

    @Modifying
    @Query(value = "DELETE FROM scene_characters WHERE character_id = :characterId", nativeQuery = true)
    void deleteSceneLinks(@Param("characterId") Long characterId);

    long countByProjectId(Long projectId);
}
