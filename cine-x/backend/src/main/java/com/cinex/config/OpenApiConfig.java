package com.cinex.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {
    @Bean
    OpenAPI cineXOpenApi() {
        return new OpenAPI().info(new Info()
                .title("CINE-X API")
                .version("v1")
                .description("Screenplay idea, scene and production planning API."));
    }
}
