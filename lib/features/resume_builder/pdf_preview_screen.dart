import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/storage_service.dart';
import '../../core/utils/responsive_utils.dart';


class PdfPreviewScreen extends StatefulWidget {
  final String resumeId;
  final String title;

  const PdfPreviewScreen({
    super.key, 
    required this.resumeId,
    this.title = 'Resume Preview',
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  String? _localFilePath;
  bool _isLoading = true;
  String? _errorMessage;
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final dir = await getTemporaryDirectory();
      final path = "${dir.path}/resume_${widget.resumeId}.pdf";
      
      final dio = Dio();
      final storage = StorageService();
      final token = await storage.getToken();
      
      final response = await dio.get(
        ApiConstants.resumeTailorPdf(widget.resumeId),
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );

      final file = File(path);
      await file.writeAsBytes(response.data);

      if (mounted) {
        setState(() {
          _localFilePath = path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to load PDF preview. Make sure LaTeX is installed on the server.\nError: $e";
        });
      }
    }
  }

  Future<void> _sharePdf() async {
    if (_localFilePath == null) return;
    
    try {
      // Provide haptic feedback for a premium feel
      HapticFeedback.mediumImpact();
      
      final file = XFile(_localFilePath!);
      await Share.shareXFiles(
        [file],
        text: 'My Tailored Resume - ${widget.title}',
        subject: 'Tailored Resume PDF',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sharing PDF: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: context.adaptiveTextSize(18),
        )),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: context.adaptiveIconSize(20)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_localFilePath != null)
            IconButton(
              icon: Icon(Icons.share_rounded, color: Colors.white, size: context.adaptiveIconSize(20)),
              onPressed: _sharePdf,
              tooltip: 'Download or Share PDF',
            ).animate().fadeIn().scale(),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: context.adaptiveSpacing(24)),
            Text(
              "Compiling LaTeX to PDF...",
              style: GoogleFonts.inter(
                color: Colors.white70, 
                fontSize: context.adaptiveTextSize(14),
              ),
            ).animate().fadeIn().scale(),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.adaptiveSpacing(24)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: context.adaptiveIconSize(64)),
              SizedBox(height: context.adaptiveSpacing(16)),
              Text(
                "Compilation Failed",
                style: GoogleFonts.inter(
                  color: Colors.white, 
                  fontSize: context.adaptiveTextSize(20), 
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: context.adaptiveSpacing(8)),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white60, 
                  fontSize: context.adaptiveTextSize(14),
                ),
              ),
              SizedBox(height: context.adaptiveSpacing(24)),
              ElevatedButton(
                onPressed: _downloadPdf,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.adaptiveSpacing(24), 
                    vertical: context.adaptiveSpacing(12),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  "Try Again", 
                  style: TextStyle(fontSize: context.adaptiveTextSize(14)),
                ),
              ),
            ],
          ),
        ).animate().shake(),
      );
    }

    return CenteredContent(
      maxWidth: 1000,
      child: Stack(
        children: [
          PDFView(
            filePath: _localFilePath,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: false,
            pageFling: true,
            pageSnap: true,
            defaultPage: _currentPage,
            fitPolicy: FitPolicy.BOTH,
            preventLinkNavigation: false,
            onRender: (pages) {
              setState(() {
                _totalPages = pages!;
                _isReady = true;
              });
            },
            onError: (error) {
              setState(() {
                _errorMessage = error.toString();
              });
            },
            onPageError: (page, error) {
              setState(() {
                _errorMessage = error.toString();
              });
            },
            onViewCreated: (PDFViewController pdfViewController) {
              // Can be used to control the viewer later
            },
            onPageChanged: (int? page, int? total) {
              setState(() {
                _currentPage = page!;
              });
            },
          ),
          if (!_isReady)
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          
          // Page indicator overlay
          Positioned(
            bottom: context.adaptiveSpacing(24),
            right: context.adaptiveSpacing(24),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.adaptiveSpacing(12), 
                vertical: context.adaptiveSpacing(6),
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white10),
              ),
              child: Text(
                "${_currentPage + 1} / $_totalPages",
                style: GoogleFonts.inter(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold,
                  fontSize: context.adaptiveTextSize(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
