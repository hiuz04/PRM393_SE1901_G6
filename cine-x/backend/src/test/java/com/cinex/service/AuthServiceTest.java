package com.cinex.service;

import com.cinex.dto.AuthDtos.RegisterRequest;
import com.cinex.exception.BadRequestException;
import com.cinex.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

class AuthServiceTest {
    @Test
    void registerRejectsWeakPassword() {
        AuthService service = new AuthService(
                mock(UserRepository.class),
                mock(PasswordEncoder.class),
                mock(AuthenticationManager.class),
                mock(JwtService.class)
        );

        RegisterRequest request = new RegisterRequest("Tester", "test@cinex.local", "weakpass", "weakpass");

        assertThatThrownBy(() -> service.register(request))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("Mat khau");
    }

    @Test
    void registerRejectsPasswordMismatch() {
        AuthService service = new AuthService(
                mock(UserRepository.class),
                mock(PasswordEncoder.class),
                mock(AuthenticationManager.class),
                mock(JwtService.class)
        );

        RegisterRequest request = new RegisterRequest("Tester", "test@cinex.local", "CineX123", "CineX999");

        assertThatThrownBy(() -> service.register(request))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("khong khop");
    }
}
