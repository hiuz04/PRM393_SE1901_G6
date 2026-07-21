package com.cinex.member.dto;

import com.cinex.member.domain.ProjectRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;

public final class MemberDtos {
    private MemberDtos() {
    }

    public record AddMemberRequest(
            @NotBlank @Email String email,
            @NotNull ProjectRole role
    ) {
    }

    public record UpdateMemberRoleRequest(
            @NotNull ProjectRole role
    ) {
    }

    public record MemberResponse(
            Long userId,
            String email,
            String displayName,
            ProjectRole role,
            Instant joinedAt
    ) {
    }
}
