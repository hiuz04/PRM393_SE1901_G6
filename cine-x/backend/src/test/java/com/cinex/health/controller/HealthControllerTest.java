package com.cinex.health.controller;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class HealthControllerTest {
    @Test
    void healthReturnsBackendStatus() {
        HealthController controller = new HealthController("cine-x-test");

        var response = controller.health();

        assertThat(response.success()).isTrue();
        assertThat(response.data().status()).isEqualTo("UP");
        assertThat(response.data().service()).isEqualTo("cine-x-test");
        assertThat(response.data().checkedAt()).isNotNull();
    }
}
