package com.cinex.member;

import com.cinex.common.response.ApiResponse;
import com.cinex.member.dto.MemberDtos.AddMemberRequest;
import com.cinex.member.dto.MemberDtos.MemberResponse;
import com.cinex.member.dto.MemberDtos.UpdateMemberRoleRequest;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/projects/{projectId}/members")
public class MemberController {
    private final MemberService memberService;

    public MemberController(MemberService memberService) {
        this.memberService = memberService;
    }

    @GetMapping
    ApiResponse<List<MemberResponse>> list(@PathVariable Long projectId) {
        return ApiResponse.ok(memberService.list(projectId));
    }

    @PostMapping
    ApiResponse<MemberResponse> add(@PathVariable Long projectId, @Valid @RequestBody AddMemberRequest request) {
        return ApiResponse.message("Da them thanh vien", memberService.add(projectId, request));
    }

    @PutMapping("/{userId}")
    ApiResponse<MemberResponse> update(@PathVariable Long projectId, @PathVariable Long userId,
                                       @Valid @RequestBody UpdateMemberRoleRequest request) {
        return ApiResponse.message("Da cap nhat vai tro", memberService.update(projectId, userId, request));
    }

    @DeleteMapping("/{userId}")
    ApiResponse<Void> remove(@PathVariable Long projectId, @PathVariable Long userId) {
        memberService.remove(projectId, userId);
        return ApiResponse.message("Da xoa thanh vien", null);
    }
}
