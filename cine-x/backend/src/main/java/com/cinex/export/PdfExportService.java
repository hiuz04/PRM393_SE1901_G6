package com.cinex.export;

import com.cinex.act.Act;
import com.cinex.act.ActRepository;
import com.cinex.character.StoryCharacter;
import com.cinex.character.StoryCharacterRepository;
import com.cinex.location.StoryLocation;
import com.cinex.location.StoryLocationRepository;
import com.cinex.project.Project;
import com.cinex.project.ProjectAccessService;
import com.cinex.scene.Scene;
import com.cinex.scene.SceneRepository;
import org.openpdf.text.Document;
import org.openpdf.text.DocumentException;
import org.openpdf.text.Element;
import org.openpdf.text.Font;
import org.openpdf.text.FontFactory;
import org.openpdf.text.Paragraph;
import org.openpdf.text.Phrase;
import org.openpdf.text.pdf.BaseFont;
import org.openpdf.text.pdf.PdfPCell;
import org.openpdf.text.pdf.PdfPTable;
import org.openpdf.text.pdf.PdfWriter;
import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PdfExportService {
    private final ProjectAccessService accessService;
    private final ActRepository actRepository;
    private final StoryCharacterRepository characterRepository;
    private final StoryLocationRepository locationRepository;
    private final SceneRepository sceneRepository;

    public PdfExportService(ProjectAccessService accessService, ActRepository actRepository,
                            StoryCharacterRepository characterRepository,
                            StoryLocationRepository locationRepository,
                            SceneRepository sceneRepository) {
        this.accessService = accessService;
        this.actRepository = actRepository;
        this.characterRepository = characterRepository;
        this.locationRepository = locationRepository;
        this.sceneRepository = sceneRepository;
    }

    @Transactional(readOnly = true)
    public PdfFile exportProject(Long projectId) {
        accessService.requireStatusEditor(projectId);
        Project project = accessService.requireVisibleProject(projectId);
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        Document document = new Document();
        try {
            PdfWriter.getInstance(document, out);
            document.open();
            PdfFonts fonts = fonts();
            document.add(title("CINE-X Project File", fonts.title));
            document.add(text("Project: " + project.getTitle(), fonts.heading));
            document.add(text("Genre: " + safe(project.getGenre()), fonts.body));
            document.add(text("Start date: " + safe(project.getStartDate()), fonts.body));
            document.add(text("Description: " + safe(project.getDescription()), fonts.body));
            addSpacer(document);
            addCharacters(document, fonts, projectId);
            addLocations(document, fonts, projectId);
            addActsAndScenes(document, fonts, projectId);
            addSpacer(document);
            document.add(text("Exported at: " + java.time.Instant.now(), fonts.small));
        } catch (DocumentException | IOException ex) {
            throw new IllegalStateException("Cannot create PDF", ex);
        } finally {
            document.close();
        }
        return new PdfFile(fileName(project.getTitle()) + ".pdf", out.toByteArray());
    }

    private void addCharacters(Document document, PdfFonts fonts, Long projectId) throws DocumentException {
        document.add(text("Characters", fonts.heading));
        PdfPTable table = new PdfPTable(new float[]{2.5f, 1.5f, 4f});
        table.setWidthPercentage(100);
        header(table, fonts, "Name", "Role", "Description");
        for (StoryCharacter character : characterRepository.findByProjectIdOrderByNameAsc(projectId)) {
            row(table, fonts, character.getName(), character.getRoleType().name(), safe(character.getDescription()));
        }
        document.add(table);
        addSpacer(document);
    }

    private void addLocations(Document document, PdfFonts fonts, Long projectId) throws DocumentException {
        document.add(text("Locations", fonts.heading));
        PdfPTable table = new PdfPTable(new float[]{3f, 1f, 1f, 4f});
        table.setWidthPercentage(100);
        header(table, fonts, "Name", "INT/EXT", "Time", "Notes");
        for (StoryLocation location : locationRepository.findByProjectIdOrderByNameAsc(projectId)) {
            row(table, fonts, location.getName(), location.getSettingType().name(), location.getTimeOfDay().name(), safe(location.getNotes()));
        }
        document.add(table);
        addSpacer(document);
    }

    private void addActsAndScenes(Document document, PdfFonts fonts, Long projectId) throws DocumentException {
        document.add(text("Acts and Scenes", fonts.heading));
        List<Scene> scenes = sceneRepository.findByProjectIdOrderBySceneNumberAsc(projectId);
        for (Act act : actRepository.findByProjectIdOrderBySequenceOrderAsc(projectId)) {
            document.add(text(act.getSequenceOrder() + ". " + act.getTitle(), fonts.heading));
            scenes.stream()
                    .filter(scene -> scene.getAct().getId().equals(act.getId()))
                    .forEach(scene -> addScene(document, fonts, scene));
        }
    }

    private void addScene(Document document, PdfFonts fonts, Scene scene) {
        try {
            String characters = scene.getCharacters().stream()
                    .map(StoryCharacter::getName)
                    .collect(Collectors.joining(", "));
            document.add(text("Scene " + scene.getSceneNumber() + ": " + safe(scene.getTitle()), fonts.subheading));
            document.add(text("Location: " + scene.getLocation().getName()
                    + " (" + scene.getLocation().getSettingType() + "/" + scene.getLocation().getTimeOfDay() + ")", fonts.body));
            document.add(text("Characters: " + characters, fonts.body));
            document.add(text("Status: " + scene.getStatus() + " | Minutes: " + safe(scene.getEstimatedMinutes()), fonts.body));
            document.add(text("Summary: " + scene.getSummary(), fonts.body));
            addSpacer(document);
        } catch (DocumentException ex) {
            throw new IllegalStateException(ex);
        }
    }

    private PdfFonts fonts() throws IOException, DocumentException {
        try (InputStream stream = getClass().getResourceAsStream("/fonts/NotoSans-Regular.ttf")) {
            if (stream != null) {
                byte[] fontBytes = stream.readAllBytes();
                BaseFont base = BaseFont.createFont("NotoSans-Regular.ttf", BaseFont.IDENTITY_H,
                        BaseFont.EMBEDDED, true, fontBytes, null);
                return new PdfFonts(
                        new Font(base, 18, Font.BOLD, Color.BLACK),
                        new Font(base, 13, Font.BOLD, Color.BLACK),
                        new Font(base, 11, Font.BOLD, Color.BLACK),
                        new Font(base, 10, Font.NORMAL, Color.BLACK),
                        new Font(base, 8, Font.NORMAL, Color.DARK_GRAY)
                );
            }
        }
        return new PdfFonts(
                FontFactory.getFont(FontFactory.HELVETICA_BOLD, 18),
                FontFactory.getFont(FontFactory.HELVETICA_BOLD, 13),
                FontFactory.getFont(FontFactory.HELVETICA_BOLD, 11),
                FontFactory.getFont(FontFactory.HELVETICA, 10),
                FontFactory.getFont(FontFactory.HELVETICA, 8)
        );
    }

    private Paragraph title(String value, Font font) {
        Paragraph paragraph = new Paragraph(value, font);
        paragraph.setAlignment(Element.ALIGN_CENTER);
        paragraph.setSpacingAfter(12);
        return paragraph;
    }

    private Paragraph text(String value, Font font) {
        Paragraph paragraph = new Paragraph(value, font);
        paragraph.setSpacingAfter(4);
        return paragraph;
    }

    private void addSpacer(Document document) throws DocumentException {
        document.add(new Paragraph(" "));
    }

    private void header(PdfPTable table, PdfFonts fonts, String... values) {
        for (String value : values) {
            PdfPCell cell = new PdfPCell(new Phrase(value, fonts.subheading));
            cell.setBackgroundColor(new Color(232, 235, 240));
            cell.setPadding(6);
            table.addCell(cell);
        }
    }

    private void row(PdfPTable table, PdfFonts fonts, String... values) {
        for (String value : values) {
            PdfPCell cell = new PdfPCell(new Phrase(safe(value), fonts.body));
            cell.setPadding(5);
            table.addCell(cell);
        }
    }

    private String safe(Object value) {
        return value == null ? "" : value.toString();
    }

    private String fileName(String title) {
        String slug = title == null ? "cinex-project" : title.toLowerCase()
                .replaceAll("[^a-z0-9]+", "-")
                .replaceAll("(^-|-$)", "");
        return slug.isBlank() ? "cinex-project" : slug;
    }

    private record PdfFonts(Font title, Font heading, Font subheading, Font body, Font small) {
    }

    public record PdfFile(String filename, byte[] bytes) {
    }
}
