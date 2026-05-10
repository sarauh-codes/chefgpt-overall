import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import '../theme/app_theme.dart';

class RecipePrintPreviewScreen extends StatelessWidget {
  final pw.Document doc;
  final String recipeName;

  const RecipePrintPreviewScreen({
    super.key,
    required this.doc,
    required this.recipeName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Print Preview: $recipeName', style: const TextStyle(color: Colors.white)),
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: AppColors.surface,
      body: PdfPreview(
        build: (format) => doc.save(),
        allowPrinting: true,
        allowSharing: true,
        canChangePageFormat: true,
        canChangeOrientation: true,
        initialPageFormat: PdfPageFormat.a4,
        pdfFileName: '${recipeName.replaceAll(' ', '_')}.pdf',
        loadingWidget: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      ),
    );
  }
}
