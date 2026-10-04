import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../auth_screen.dart';
import '../services.dart';
import '../theme.dart';
import '../utils.dart';

class AddMosqueScreen extends StatefulWidget {
  final void Function(int tab)? onGoList;
  const AddMosqueScreen({super.key, this.onGoList});

  @override
  State<AddMosqueScreen> createState() => _AddMosqueScreenState();
}

class _AddMosqueScreenState extends State<AddMosqueScreen> {
  final _name = TextEditingController();
  String _type = 'Cami';
  final Set<String> _amenities = {};
  final List<Uint8List> _photos = [];
  bool _busy = false;
  String? _locText;

  @override
  void initState() {
    super.initState();
    _refreshLoc();
  }

  void _refreshLoc() {
    final loc = services.location;
    final p = services.prayer;
    final cnt = p.districtName.isNotEmpty
        ? ' \u00B7 ${capTr(p.districtName)}'
        : '';
    _locText = loc.hasLocation
        ? 'Kay\u0131t konumu: ${loc.userLat.toStringAsFixed(4)}, ${loc.userLng.toStringAsFixed(4)}$cnt'
        : 'Konum bekleniyor…';
  }

  Future<void> _pickPhotos() => _addImages(
    ImagePicker().pickMultiImage(limit: 3 - _photos.length, imageQuality: 70),
  );

  /// Kameradan çekip yükleme.
  Future<void> _capturePhoto() => _addImages(
    ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 70)
        .then((f) => f == null ? <XFile>[] : <XFile>[f]),
  );

  Future<void> _addImages(Future<List<XFile>> future) async {
    final picked = await future;
    for (final f in picked) {
      final bytes = await f.readAsBytes();
      Uint8List? out = bytes;
      try {
        final dec = img.decodeImage(bytes);
        if (dec != null) {
          final scale =
              (480 / (dec.width > dec.height ? dec.width : dec.height)).clamp(
                0.1,
                1.0,
              );
          final resized = img.copyResize(
            dec,
            width: (dec.width * scale).round().clamp(1, 480),
            height: (dec.height * scale).round().clamp(1, 480),
          );
          out = Uint8List.fromList(img.encodeJpg(resized, quality: 72));
        }
      } catch (_) {}
      if (_photos.length >= 3) break;
      setState(() {
        if (out != null) _photos.add(out);
      });
    }
  }

  Future<void> _submit() async {
    final app = services.app;
    final loc = services.location;
    if (!app.isLoggedIn) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AuthScreen(reason: AuthReason.addRequest),
        ),
      );
      if (!mounted) return;
      if (!app.isLoggedIn) return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Mescit ad\u0131 girin');
      return;
    }
    if (!loc.hasLocation) {
      toast(context, 'Kay\u0131t i\u00E7in konumunuz al\u0131nmal\u0131');
      return;
    }
    setState(() => _busy = true);
    final tags = [..._amenities];
    app.addPending(
      name,
      _type,
      tags,
      loc.userLat,
      loc.userLng,
      _photos.map((b) => base64Encode(b)).toList(),
    );
    setState(() {
      _busy = false;
      _name.clear();
      _amenities.clear();
      _photos.clear();
      _type = 'Cami';
    });
    if (mounted) {
      toast(context, 'Kayd\u0131n\u0131z al\u0131nd\u0131');
      if (widget.onGoList != null) {
        widget.onGoList!(2);
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Route olarak açıldığında Material ancestral için Scaffold şart.
    return Scaffold(
      backgroundColor: ctxBodyBg(context),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: services.location,
          builder: (_, _) {
            _refreshLoc();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Text(
                  'Yeni Mescit Ekle',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ctxInk(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ekledi\u011Fin yer incelendikten sonra yay\u0131nlan\u0131r.',
                  style: TextStyle(fontSize: 12, color: ctxInkSoft(context)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  style: TextStyle(fontSize: 14, color: ctxInk(context)),
                  decoration: const InputDecoration(
                    labelText: 'Mescit ad\u0131',
                    hintText: '\u00D6rn. K\u00FClt\u00FCr Mescidi',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  style: TextStyle(fontSize: 14, color: ctxInk(context)),
                  decoration: const InputDecoration(labelText: 'T\u00FCr'),
                  items: const [
                    DropdownMenuItem(value: 'Cami', child: Text('Cami')),
                    DropdownMenuItem(value: 'Mescit', child: Text('Mescit')),
                    DropdownMenuItem(
                      value: 'AVM / Benzinlik Mescidi',
                      child: Text('AVM / Benzinlik Mescidi'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'Cami'),
                ),
                const SizedBox(height: 14),
                Text(
                  'Olanaklar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ctxInk(context),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Abdesthane',
                    'Kad\u0131nlar \u0130\u00E7in',
                    'Engelli Eri\u015Fimi',
                    'Otopark',
                    'Klima',
                  ].map((a) => _amenity(a)).toList(),
                ),
                const SizedBox(height: 14),
                // Panelden fotoğraf anahtarı kapalıysa bu bölüm hiç gösterilmez.
                if (services.app.remote.features.photos) ...[
                  Text(
                    'Foto\u011Fraf',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ctxInk(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickPhotos,
                          child: Container(
                            height: 92,
                            decoration: BoxDecoration(
                              color: ctxGreenLight(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ctxLine(context)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 24,
                                  color: ctxGold(context),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Galeriden Se\u00E7',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ctxInkSoft(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _capturePhoto,
                          child: Container(
                            height: 92,
                            decoration: BoxDecoration(
                              color: ctxGreenLight(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: ctxLine(context)),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.photo_camera_outlined,
                                  size: 24,
                                  color: ctxGold(context),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Foto\u011Fraf \u00C7ek',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ctxInkSoft(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_photos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _photos[i],
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 2,
                            top: 2,
                            child: GestureDetector(
                              onTap: () => setState(() => _photos.removeAt(i)),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: ctxCream(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.my_location, size: 16, color: T.green600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locText ?? '',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: ctxInkSoft(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? 'Kaydediliyor…' : 'Kaydet'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _amenity(String a) {
    final on = _amenities.contains(a);
    return GestureDetector(
      onTap: () => setState(() {
        if (on) {
          _amenities.remove(a);
        } else {
          _amenities.add(a);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? T.green600 : ctxPaper(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? T.green600 : ctxLine(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              on ? Icons.check : Icons.add,
              size: 14,
              color: on ? Colors.white : ctxInkSoft(context),
            ),
            const SizedBox(width: 4),
            Text(
              a,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: on ? Colors.white : ctxInkSoft(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
