import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/cinex_models.dart';

class PdfExportService {
  const PdfExportService();

  Future<Uint8List> buildProjectPdf({
    required Project project,
    required Dashboard dashboard,
    required List<Act> acts,
    required List<Scene> scenes,
    required List<StoryCharacter> characters,
    required List<StoryLocation> storyLocations,
    required List<ShootingLocation> shootingLocations,
    required List<FilmResource> resources,
    required List<ShootingDay> shootingDays,
  }) async {
    final doc = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final font = pw.Font.ttf(fontData);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              project.title,
              style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(project.description ?? 'Bản xuất dự án ngoại tuyến từ CINE-X'),
          pw.SizedBox(height: 16),
          _metricTable(dashboard),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'Kịch bản'),
          ...acts.map((act) {
            final actScenes = scenes
                .where((scene) => scene.actId == act.id)
                .toList()
              ..sort((a, b) => a.sceneNumber.compareTo(b.sceneNumber));
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${act.sequenceOrder}. ${act.title}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                if (act.description != null) pw.Text(act.description!),
                pw.SizedBox(height: 6),
                ...actScenes.map(
                  (scene) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Text(
                      '${scene.sceneHeading}\n${scene.summary}\nĐịa điểm quay: ${scene.shootingLocationLabel}',
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
              ],
            );
          }),
          pw.Header(level: 1, text: 'Tài nguyên'),
          pw.Text(
            '${characters.length} nhân vật, ${storyLocations.length} bối cảnh truyện, '
            '${shootingLocations.length} địa điểm quay, ${resources.length} tài nguyên.',
          ),
          pw.Header(level: 1, text: 'Lịch quay'),
          ...shootingDays.map(
            (day) => pw.Text(
              '${day.shootingDate.toIso8601String().split('T').first}: '
              '${day.title} (${_shootingDayStatusLabel(day.status)}) - '
              '${day.totalMinutes}/${day.maxMinutes} phút',
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _metricTable(Dashboard dashboard) {
    return pw.TableHelper.fromTextArray(
      headers: const ['Hồi', 'Cảnh', 'Nhân vật', 'Bối cảnh', 'Tài nguyên'],
      data: [
        [
          dashboard.totalActs,
          dashboard.totalScenes,
          dashboard.totalCharacters,
          dashboard.totalLocations,
          dashboard.totalResources,
        ],
      ],
    );
  }

  String _shootingDayStatusLabel(String status) {
    return switch (status) {
      'DRAFT' => 'Nháp',
      'CONFIRMED' => 'Đã xác nhận',
      'IN_PROGRESS' => 'Đang quay',
      'COMPLETED' => 'Hoàn tất',
      'CANCELLED' => 'Đã hủy',
      _ => status,
    };
  }
}
