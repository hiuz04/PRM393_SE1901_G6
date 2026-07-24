package com.cinex.repository;

import com.cinex.domain.SettingType;
import com.cinex.domain.StoryLocation;
import com.cinex.domain.TimeOfDay;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface StoryLocationRepository extends JpaRepository<StoryLocation, Long> {
    Optional<StoryLocation> findByIdAndProjectId(Long id, Long projectId);

    List<StoryLocation> findByProjectIdOrderByNameAsc(Long projectId);

    @Query("""
            select l from StoryLocation l
            where l.project.id = :projectId
              and lower(l.name) like :searchPattern
              and (:settingType is null or l.settingType = :settingType)
              and (:timeOfDay is null or l.timeOfDay = :timeOfDay)
            """)
    Page<StoryLocation> search(@Param("projectId") Long projectId, @Param("searchPattern") String searchPattern,
                               @Param("settingType") SettingType settingType,
                               @Param("timeOfDay") TimeOfDay timeOfDay,
                               Pageable pageable);

    long countByProjectId(Long projectId);
}
