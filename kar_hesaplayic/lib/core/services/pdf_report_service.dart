import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../utils/calculators.dart';
import '../../models/marketplace_model.dart';

/// E-ticaret hesaplama sonucunu profesyonel bir PDF rapora dönüştürüp
/// paylaşım/yazdırma menüsünü açan servis. Tamamen cihaz üzerinde çalışır,
/// herhangi bir sunucuya ihtiyaç duymaz.
class PdfReportService {
  PdfReportService._();
  static final PdfReportService instance = PdfReportService._();

  static const PdfColor _primary = PdfColor.fromInt(0xFF0D9488);
  static const PdfColor _secondary = PdfColor.fromInt(0xFF6366F1);
  static const PdfColor _textMuted = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _border = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor _danger = PdfColor.fromInt(0xFFEF4444);

  Future<void> generateAndShareEcommerceReport({
    required Marketplace marketplace,
    required double buyPrice,
    required double sellPrice,
    required double commissionRatePercent,
    required double shippingCost,
    required double vatRatePercent,
    required EcommerceCalculationResult result,
    String? companyName, // Pro özellik: özel firma adı
  }) async {
    // TÜRKÇE KARAKTER DÜZELTMESİ: `pdf` paketinin varsayılan (dahili) fontu
    // "ı, ş, ğ, İ, Ş, Ğ" gibi Türkçe'ye özgü karakterleri barındırmaz; bu
    // karakterler PDF çıktısında kutu (□) olarak görünür. `printing`
    // paketinin sunduğu `PdfGoogleFonts` (Noto Sans — Google'ın geniş
    // Unicode kapsamlı fontu) tüm Türkçe karakterleri eksiksiz destekler.
    // Fontlar `printing` paketiyle birlikte yerel olarak gelir; ilk kullanımda
    // bir kereliğine yüklenip önbelleğe alınır, ağ bağlantısı gerektirmez.
    final regularFont = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );
    final currency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
    final percent = NumberFormat.decimalPattern('tr_TR');
    final dateStr = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(DateTime.now());
    final isProfit = result.netProfit >= 0;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(companyName, dateStr, marketplace),
              pw.SizedBox(height: 20),
              _buildHeroCard(currency, result, isProfit),
              pw.SizedBox(height: 20),
              _buildInputSummary(
                currency: currency,
                percent: percent,
                buyPrice: buyPrice,
                sellPrice: sellPrice,
                commissionRatePercent: commissionRatePercent,
                shippingCost: shippingCost,
                vatRatePercent: vatRatePercent,
              ),
              pw.SizedBox(height: 20),
              _buildResultBreakdown(currency, percent, result),
              pw.Spacer(),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();

    // Raporu cihazda geçici olarak da saklıyoruz (ör. Pro modda "son raporlar"
    // listesi gibi bir özellik eklemek isterseniz dosya burada hazır olur).
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/kar_raporu_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes);

    // `printing` paketi, iOS/Android'in native paylaşım/yazdırma menüsünü
    // tek çağrıyla açar.
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'kar_hesaplama_raporu.pdf',
    );
  }

  pw.Widget _buildHeader(String? companyName, String dateStr, Marketplace marketplace) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              companyName?.isNotEmpty == true ? companyName! : 'Kâr Hesaplama Raporu',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _primary),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${marketplace.label} • $dateStr',
              style: const pw.TextStyle(fontSize: 10, color: _textMuted),
            ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: pw.BoxDecoration(
            color: _primary,
            borderRadius: pw.BorderRadius.circular(20),
          ),
          child: pw.Text(
            'E-Ticaret & Freelancer Hesaplayıcı',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildHeroCard(
    NumberFormat currency,
    EcommerceCalculationResult result,
    bool isProfit,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: isProfit ? _primary : _danger,
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'NET KÂR',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            currency.format(result.netProfit),
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'ROI: %${result.roiPercent.toStringAsFixed(1)}  •  Kâr Marjı: %${result.profitMarginPercent.toStringAsFixed(1)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInputSummary({
    required NumberFormat currency,
    required NumberFormat percent,
    required double buyPrice,
    required double sellPrice,
    required double commissionRatePercent,
    required double shippingCost,
    required double vatRatePercent,
  }) {
    return _sectionCard(
      title: 'Girdi Özeti',
      rows: [
        _row('Ürün Alış Fiyatı', currency.format(buyPrice)),
        _row('Hedef Satış Fiyatı', currency.format(sellPrice)),
        _row('Komisyon Oranı', '%${percent.format(commissionRatePercent)}'),
        _row('Kargo Ücreti', currency.format(shippingCost)),
        _row('KDV Oranı', '%${percent.format(vatRatePercent)}'),
      ],
    );
  }

  pw.Widget _buildResultBreakdown(
    NumberFormat currency,
    NumberFormat percent,
    EcommerceCalculationResult result,
  ) {
    return _sectionCard(
      title: 'Detaylı Döküm',
      rows: [
        _row('Pazaryeri Kesintisi', currency.format(result.commissionAmount)),
        _row('Net KDV Yükü', currency.format(result.netVatBurden)),
        _row('Toplam Maliyet', currency.format(result.totalCosts)),
        _row(
          'Başabaş Satış Fiyatı',
          result.breakEvenPrice.isFinite ? currency.format(result.breakEvenPrice) : '—',
        ),
      ],
    );
  }

  pw.Widget _sectionCard({required String title, required List<pw.Widget> rows}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _border),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _secondary),
          ),
          pw.SizedBox(height: 10),
          ...rows,
        ],
      ),
    );
  }

  pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: _textMuted)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: _border),
        pw.SizedBox(height: 6),
        pw.Text(
          'Bu rapor, Kâr / Komisyon / Desi Hesaplayıcı uygulaması ile cihaz üzerinde oluşturulmuştur. '
          'Değerler yalnızca bilgilendirme amaçlıdır, resmi mali/vergi danışmanlığı yerine geçmez.',
          style: const pw.TextStyle(fontSize: 8, color: _textMuted),
        ),
      ],
    );
  }
}
