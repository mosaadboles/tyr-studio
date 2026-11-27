import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:screenshot/screenshot.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TyrStudioApp());
}

class TyrStudioApp extends StatelessWidget {
  const TyrStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tyr Studio',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1218),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF5B700),
          secondary: Color(0xFF22C55E),
        ),
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: const PosterEditorScreen(),
      ),
    );
  }
}

enum AspectPreset {
  square('1:1', 1.0),
  portrait('4:5', 4 / 5),
  landscape('16:9', 16 / 9),
  story('9:16', 9 / 16);

  final String label;
  final double ratio;
  const AspectPreset(this.label, this.ratio);
}

enum TemplateStyle {
  breaking('عاجل', Color(0xFFDC2626)),
  report('تقرير', Color(0xFF0284C7)),
  quote('تصريح', Color(0xFFD97706));

  final String label;
  final Color badgeColor;
  const TemplateStyle(this.label, this.badgeColor);
}

class PosterDraft {
  final String id;
  final String headline;
  final String subheadline;
  final String footerRight;
  final String footerLeft;
  final AspectPreset ratio;
  final TemplateStyle style;
  final double fontSize;
  final bool highlightHeadline;
  final bool showLogo;

  PosterDraft({
    required this.id,
    required this.headline,
    required this.subheadline,
    required this.footerRight,
    required this.footerLeft,
    required this.ratio,
    required this.style,
    required this.fontSize,
    required this.highlightHeadline,
    required this.showLogo,
  });
}

class PosterEditorScreen extends StatefulWidget {
  const PosterEditorScreen({super.key});

  @override
  State<PosterEditorScreen> createState() => _PosterEditorScreenState();
}

class _PosterEditorScreenState extends State<PosterEditorScreen> {
  final ScreenshotController _captureController = ScreenshotController();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _headlineCtrl = TextEditingController(
    text: 'متابعة ميدانية لأبرز التطورات والأخبار العاجلة',
  );
  final TextEditingController _subheadlineCtrl = TextEditingController(
    text: 'تغطية مستمرة وتحقق أول بأول عبر منصة تيار',
  );
  final TextEditingController _rightFooterCtrl = TextEditingController(
    text: 'تيار | TYR',
  );
  final TextEditingController _leftFooterCtrl = TextEditingController(
    text: 'TYR NEWS',
  );

  File? _bgImage;
  File? _logoImage;
  String? _customFontName;

  AspectPreset _ratio = AspectPreset.square;
  TemplateStyle _style = TemplateStyle.breaking;
  double _fontSize = 22;
  bool _highlightHeadline = true;
  bool _showLogo = true;
  bool _isSaving = false;

  final List<PosterDraft> _drafts = [];

  @override
  void dispose() {
    _headlineCtrl.dispose();
    _subheadlineCtrl.dispose();
    _rightFooterCtrl.dispose();
    _leftFooterCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBackground() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _bgImage = File(picked.path));
    }
  }

  Future<void> _pickLogo() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _logoImage = File(picked.path);
        _showLogo = true;
      });
    }
  }

  Future<void> _pickFont() async {
    final FilePickerResult? res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ttf'],
    );
    if (res != null && res.files.single.path != null) {
      final File file = File(res.files.single.path!);
      final String fontFamily = 'TyrFont_${DateTime.now().millisecondsSinceEpoch}';
      final ByteData data = await file.readAsBytes().then(
        (b) => ByteData.view(b.buffer),
      );
      final FontLoader loader = FontLoader(fontFamily)
        ..addFont(Future.value(data));
      await loader.load();

      setState(() => _customFontName = fontFamily);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحميل الخط: ${p.basename(file.path)}')),
        );
      }
    }
  }

  Future<void> _exportPoster() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final Uint8List? bytes = await _captureController.capture(pixelRatio: 3.0);
      if (bytes != null) {
        await Gal.putImageBytes(
          bytes,
          name: 'tyr_poster_${DateTime.now().millisecondsSinceEpoch}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ المنشور في المعرض بدقة عالية')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الحفظ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _saveDraft() {
    setState(() {
      _drafts.insert(
        0,
        PosterDraft(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          headline: _headlineCtrl.text.trim(),
          subheadline: _subheadlineCtrl.text.trim(),
          footerRight: _rightFooterCtrl.text.trim(),
          footerLeft: _leftFooterCtrl.text.trim(),
          ratio: _ratio,
          style: _style,
          fontSize: _fontSize,
          highlightHeadline: _highlightHeadline,
          showLogo: _showLogo,
        ),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ المسودة')),
    );
  }

  void _loadDraft(PosterDraft d) {
    setState(() {
      _headlineCtrl.text = d.headline;
      _subheadlineCtrl.text = d.subheadline;
      _rightFooterCtrl.text = d.footerRight;
      _leftFooterCtrl.text = d.footerLeft;
      _ratio = d.ratio;
      _style = d.style;
      _fontSize = d.fontSize;
      _highlightHeadline = d.highlightHeadline;
      _showLogo = d.showLogo;
    });
    Navigator.pop(context);
  }

  void _showDraftsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181C26),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'المسودات المحفوظة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (_drafts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('لا توجد مسودات حتى الآن'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _drafts.length,
                  itemBuilder: (_, i) {
                    final item = _drafts[i];
                    return ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(
                        item.headline.isEmpty ? 'مسودة بدون عنوان' : item.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${item.style.label} • ${item.ratio.label}'),
                      onTap: () => _loadDraft(item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A22),
        title: const Text(
          'تيار | Tyr Studio',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: 'المسودات',
            icon: const Icon(Icons.folder_copy_outlined),
            onPressed: _showDraftsModal,
          ),
          IconButton(
            tooltip: 'حفظ مسودة',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _saveDraft,
          ),
          IconButton(
            tooltip: 'تصدير المنشور',
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_for_offline_outlined),
            onPressed: _exportPoster,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: AspectRatio(
                  aspectRatio: _ratio.ratio,
                  child: Screenshot(
                    controller: _captureController,
                    child: _buildCanvas(),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF161A22),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: TemplateStyle.values.map((t) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text(t.label),
                              selected: _style == t,
                              onSelected: (_) => setState(() => _style = t),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: AspectPreset.values.map((r) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text('مقاس ${r.label}'),
                              selected: _ratio == r,
                              onSelected: (_) => setState(() => _ratio = r),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _headlineCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'العنوان الرئيسي',
                        filled: true,
                        fillColor: Color(0xFF202633),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _subheadlineCtrl,
                      decoration: const InputDecoration(
                        labelText: 'العنوان الفرعي',
                        filled: true,
                        fillColor: Color(0xFF202633),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _rightFooterCtrl,
                            decoration: const InputDecoration(
                              labelText: 'الجهة / الشريط السفلي',
                              filled: true,
                              fillColor: Color(0xFF202633),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _leftFooterCtrl,
                            decoration: const InputDecoration(
                              labelText: 'الوسم / الرابط',
                              filled: true,
                              fillColor: Color(0xFF202633),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('حجم الخط:'),
                        Expanded(
                          child: Slider(
                            value: _fontSize,
                            min: 15,
                            max: 36,
                            onChanged: (v) => setState(() => _fontSize = v),
                          ),
                        ),
                        Text(_fontSize.toStringAsFixed(0)),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('تمييز العنوان'),
                          selected: _highlightHeadline,
                          onSelected: (v) =>
                              setState(() => _highlightHeadline = v),
                        ),
                        FilterChip(
                          label: const Text('إظهار الشعار'),
                          selected: _showLogo,
                          onSelected: (v) => setState(() => _showLogo = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickBackground,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('صورة الخلفية'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickLogo,
                          icon: const Icon(Icons.verified_outlined),
                          label: const Text('شعار المنصة'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _pickFont,
                          icon: const Icon(Icons.font_download_outlined),
                          label: const Text('خط TTF'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    final TextStyle headlineStyle = TextStyle(
      fontFamily: _customFontName,
      fontSize: _fontSize,
      fontWeight: FontWeight.w800,
      color: _highlightHeadline ? const Color(0xFF111827) : Colors.white,
      height: 1.35,
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_bgImage != null)
                  Image.file(_bgImage!, fit: BoxFit.cover)
                else
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.photo_library_outlined,
                        size: 44,
                        color: Colors.white30,
                      ),
                    ),
                  ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _style.badgeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _style.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (_showLogo)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _logoImage != null
                          ? Image.file(
                              _logoImage!,
                              width: 34,
                              height: 34,
                              fit: BoxFit.contain,
                            )
                          : const Text(
                              'TYR',
                              style: TextStyle(
                                color: Color(0xFFF5B700),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              color: const Color(0xFF0B0F17),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_headlineCtrl.text.trim().isNotEmpty)
                        Container(
                          padding: _highlightHeadline
                              ? const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                )
                              : EdgeInsets.zero,
                          decoration: _highlightHeadline
                              ? BoxDecoration(
                                  color: const Color(0xFFFACC15),
                                  borderRadius: BorderRadius.circular(4),
                                )
                              : null,
                          child: Text(
                            _headlineCtrl.text.trim(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: headlineStyle,
                          ),
                        ),
                      if (_subheadlineCtrl.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          _subheadlineCtrl.text.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: _customFontName,
                            color: Colors.white70,
                            fontSize: (_fontSize * 0.62).clamp(12, 20),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.white12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _rightFooterCtrl.text.trim(),
                          style: const TextStyle(
                            color: Color(0xFFFACC15),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          _leftFooterCtrl.text.trim(),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
