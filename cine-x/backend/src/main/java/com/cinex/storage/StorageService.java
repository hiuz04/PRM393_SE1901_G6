package com.cinex.storage;

import com.cinex.common.exception.BadRequestException;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class StorageService {
    private static final long MAX_BYTES = 5L * 1024 * 1024;
    private static final Map<String, String> EXTENSIONS = Map.of(
            "image/jpeg", ".jpg",
            "image/png", ".png",
            "image/webp", ".webp"
    );

    private final Path uploadDir;

    public StorageService(@Value("${app.upload-dir}") String uploadDir) {
        this.uploadDir = Path.of(uploadDir).toAbsolutePath().normalize();
    }

    public String storeImage(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BadRequestException("File anh bat buoc");
        }
        if (file.getSize() > MAX_BYTES) {
            throw new BadRequestException("Anh vuot qua gioi han 5MB");
        }
        String type = file.getContentType();
        if (!Set.copyOf(EXTENSIONS.keySet()).contains(type)) {
            throw new BadRequestException("Chi ho tro image/jpeg, image/png, image/webp");
        }
        try {
            Files.createDirectories(uploadDir);
            String filename = UUID.randomUUID() + EXTENSIONS.get(type);
            Path target = uploadDir.resolve(filename).normalize();
            Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
            return "/uploads/" + filename;
        } catch (IOException ex) {
            throw new BadRequestException("Khong the luu anh");
        }
    }

    public Path getUploadDir() {
        return uploadDir;
    }
}
