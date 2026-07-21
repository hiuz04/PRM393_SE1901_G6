package com.cinex.auth.controller;

import com.cinex.auth.dto.AuthDtos.AuthResponse;
import com.cinex.auth.dto.AuthDtos.LoginRequest;
import com.cinex.auth.dto.AuthDtos.RegisterRequest;
import com.cinex.auth.dto.AuthDtos.UserResponse;
import com.cinex.auth.service.AuthService;
import com.cinex.common.response.ApiResponse;
import com.cinex.security.domain.AppUserDetails;
import com.cinex.user.repository.UserRepository;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private final AuthService authService;
    private final UserRepository userRepository;

    public AuthController(AuthService authService, UserRepository userRepository) {
        this.authService = authService;
        this.userRepository = userRepository;
    }

    @PostMapping("/register")
    ApiResponse<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ApiResponse.message("Dang ky thanh cong", authService.register(request));
    }

    @PostMapping("/login")
    ApiResponse<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        return ApiResponse.message("Dang nhap thanh cong", authService.login(request));
    }

    @GetMapping("/me")
    ApiResponse<UserResponse> me(@AuthenticationPrincipal AppUserDetails principal) {
        return ApiResponse.ok(authService.me(userRepository.getReferenceById(principal.getId())));
    }
}
