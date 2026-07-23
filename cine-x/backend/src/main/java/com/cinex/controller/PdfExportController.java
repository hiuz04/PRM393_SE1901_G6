package com.cinex.controller;

import com.cinex.service.PdfExportService;
import com.cinex.service.PdfExportService.PdfFile;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/projects/{projectId}/export")
public class PdfExportController {
    private final PdfExportService exportService;

    public PdfExportController(PdfExportService exportService) {
        this.exportService = exportService;
    }

    @GetMapping("/pdf")
    ResponseEntity<byte[]> pdf(@PathVariable Long projectId) {
        PdfFile file = exportService.exportProject(projectId);
        return ResponseEntity.ok()
                .contentType(MediaType.APPLICATION_PDF)
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment().filename(file.filename()).build().toString())
                .body(file.bytes());
    }
}
