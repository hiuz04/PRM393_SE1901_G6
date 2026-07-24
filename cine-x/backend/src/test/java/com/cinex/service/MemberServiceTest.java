package com.cinex.service;

import com.cinex.exception.BadRequestException;
import com.cinex.domain.ProjectMember;
import com.cinex.domain.ProjectRole;
import com.cinex.repository.ProjectMemberRepository;
import com.cinex.repository.UserRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class MemberServiceTest {
    @Test
    void removeRejectsLastOwner() {
        ProjectMemberRepository members = mock(ProjectMemberRepository.class);
        ProjectMember owner = new ProjectMember();
        owner.setRole(ProjectRole.OWNER);
        when(members.findByProjectIdAndUserId(1L, 2L)).thenReturn(Optional.of(owner));
        when(members.countByProjectIdAndRole(1L, ProjectRole.OWNER)).thenReturn(1L);
        MemberService service = new MemberService(members, mock(UserRepository.class), mock(ProjectAccessService.class));

        assertThatThrownBy(() -> service.remove(1L, 2L))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("OWNER");
    }
}
