package com.cinex.auth;

import com.cinex.auth.dto.AuthDtos.AuthResponse;
import com.cinex.auth.dto.AuthDtos.LoginRequest;
import com.cinex.auth.dto.AuthDtos.RegisterRequest;
import com.cinex.auth.dto.AuthDtos.UserResponse;
import com.cinex.common.exception.BadRequestException;
import com.cinex.common.exception.ConflictException;
import com.cinex.common.exception.NotFoundException;
import com.cinex.security.JwtService;
import com.cinex.user.SystemRole;
import com.cinex.user.UserAccount;
import com.cinex.user.UserRepository;
import java.util.regex.Pattern;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
    private static final Pattern UPPER = Pattern.compile(".*[A-Z].*");
    private static final Pattern LOWER = Pattern.compile(".*[a-z].*");
    private static final Pattern DIGIT = Pattern.compile(".*\\d.*");

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthenticationManager authenticationManager;
    private final JwtService jwtService;

    public AuthService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            AuthenticationManager authenticationManager,
            JwtService jwtService
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.authenticationManager = authenticationManager;
        this.jwtService = jwtService;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        validatePassword(request.password(), request.confirmPassword());
        String email = request.email().trim().toLowerCase();
        if (userRepository.existsByEmailIgnoreCase(email)) {
            throw new ConflictException("Email da ton tai");
        }
        UserAccount user = new UserAccount();
        user.setDisplayName(request.displayName().trim());
        user.setEmail(email);
        user.setPasswordHash(passwordEncoder.encode(request.password()));
        user.setSystemRole(SystemRole.USER);
        user.setEnabled(true);
        UserAccount saved = userRepository.save(user);
        return token(saved);
    }

    public AuthResponse login(LoginRequest request) {
        try {
            authenticationManager.authenticate(new UsernamePasswordAuthenticationToken(
                    request.email().trim().toLowerCase(), request.password()));
        } catch (BadCredentialsException ex) {
            throw new BadRequestException("Email hoac mat khau khong dung");
        }
        UserAccount user = userRepository.findByEmailIgnoreCase(request.email().trim().toLowerCase())
                .orElseThrow(() -> new NotFoundException("Khong tim thay nguoi dung"));
        return token(user);
    }

    public UserResponse me(UserAccount user) {
        return toUser(user);
    }

    private AuthResponse token(UserAccount user) {
        return new AuthResponse(jwtService.generate(user), "Bearer", jwtService.getExpirationMs(), toUser(user));
    }

    private UserResponse toUser(UserAccount user) {
        return new UserResponse(user.getId(), user.getEmail(), user.getDisplayName(),
                user.getSystemRole(), user.getCreatedAt());
    }

    private void validatePassword(String password, String confirmPassword) {
        if (!password.equals(confirmPassword)) {
            throw new BadRequestException("Mat khau xac nhan khong khop");
        }
        if (password.length() < 8 || !UPPER.matcher(password).matches()
                || !LOWER.matcher(password).matches() || !DIGIT.matcher(password).matches()) {
            throw new BadRequestException("Mat khau phai co it nhat 8 ky tu, chu hoa, chu thuong va chu so");
        }
    }
}
