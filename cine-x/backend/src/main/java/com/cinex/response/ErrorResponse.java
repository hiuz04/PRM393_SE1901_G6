package com.cinex.response;

import java.time.Instant;
import java.util.Map;

public record ErrorResponse(
        boolean success,
        int status,
        String code,
        String message,
        Map<String, String> errors,
        Instant timestamp
) {
    public static ErrorResponse of(int status, String code, String message, Map<String, String> errors) {
        return new ErrorResponse(false, status, code, message, errors, Instant.now());
    }
}
