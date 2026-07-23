package com.cinex.service;

import com.cinex.domain.SystemRole;
import com.cinex.domain.UserAccount;
import io.jsonwebtoken.Claims;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class JwtServiceTest {
    @Test
    void generatedTokenContainsRequiredClaims() {
        JwtService jwtService = new JwtService("TestSecretForCineXJwtThatIsLongEnoughForHS256", 60_000);
        UserAccount user = new UserAccount();
        user.setId(42L);
        user.setEmail("owner@cinex.local");
        user.setSystemRole(SystemRole.USER);

        Claims claims = jwtService.parse(jwtService.generate(user));

        assertThat(claims.getSubject()).isEqualTo("42");
        assertThat(claims.get("email", String.class)).isEqualTo("owner@cinex.local");
        assertThat(claims.get("systemRole", String.class)).isEqualTo("USER");
        assertThat(claims.getExpiration()).isNotNull();
    }
}
