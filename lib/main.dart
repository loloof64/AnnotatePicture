import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image/image.dart' as img;

void main() => runApp(const MaterialApp(
      title: 'AnnotatePicture',
      debugShowCheckedModeBanner: false,
      home: Editor(),
    ));

class Note {
  Note(this.text, this.pos, this.color, this.size);
  String text;
  Offset pos; // en pixels de l'image
  Color color;
  double size;

  TextPainter painter() => TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
        textDirection: TextDirection.ltr,
      )..layout();
}

const _palette = [
  Colors.black, Colors.white, Colors.red, Colors.orange, Colors.yellow,
  Colors.green, Colors.blue, Colors.purple,
];

class Editor extends StatefulWidget {
  const Editor({super.key});
  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final _zoom = TransformationController();
  ui.Image? _image;
  String? _path;
  final _notes = <Note>[];
  Note? _sel;
  Color _color = Colors.red;
  double _size = 48;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final image = await decodeImageFromList(bytes);
    setState(() {
      _image = image;
      _path = f.path;
      _notes.clear();
      _sel = null;
      _zoom.value = Matrix4.identity();
    });
  }

  Future<Uint8List> _render(bool jpg) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawImage(_image!, Offset.zero, Paint());
    for (final n in _notes) {
      n.painter().paint(c, n.pos);
    }
    final out = await rec.endRecording().toImage(_image!.width, _image!.height);
    if (!jpg) {
      return (await out.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
    }
    final raw = (await out.toByteData())!;
    final im = img.Image.fromBytes(
        width: out.width, height: out.height, bytes: raw.buffer, numChannels: 4);
    return img.encodeJpg(im, quality: 95);
  }

  static bool _isJpg(String p) => RegExp(r'\.jpe?g$', caseSensitive: false).hasMatch(p);

  Future<void> _save() async {
    if (_path == null) return _saveAs();
    await File(_path!).writeAsBytes(await _render(_isJpg(_path!)));
    _toast('Enregistré');
  }

  Future<void> _saveAs() async {
    // ponytail: le format suit l'image d'origine (saveFile exige les octets avant le choix du nom)
    final jpg = _path != null && _isJpg(_path!);
    final dest = await FilePicker.saveFile(
      fileName: _path == null ? 'image.png' : _path!.split(Platform.pathSeparator).last,
      bytes: await _render(jpg),
      type: FileType.custom,
      allowedExtensions: jpg ? ['jpg', 'jpeg'] : ['png'],
    );
    if (dest == null) return;
    setState(() => _path = dest.toFilePath());
    _toast('Enregistré sous $_path');
  }

  Future<void> _pickColor() async {
    var c = _color;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: SingleChildScrollView(
          child: ColorPicker(pickerColor: c, onColorChanged: (v) => c = v, hexInputBar: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('OK')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _color = c;
        _sel?.color = c;
      });
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<String?> _ask(String initial) {
    final ctl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Texte'),
        content: TextField(
            controller: ctl,
            autofocus: true,
            maxLines: null,
            onSubmitted: (v) => Navigator.pop(context, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, ctl.text), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final t = await _ask('');
    if (t == null || t.isEmpty) return;
    final n = Note(t, Offset(_image!.width / 4, _image!.height / 4), _color, _size);
    setState(() {
      _notes.add(n);
      _sel = n;
    });
  }

  Future<void> _edit(Note n) async {
    final t = await _ask(n.text);
    if (t != null && t.isNotEmpty) setState(() => n.text = t);
  }

  void _setScale(double s) => _zoom.value = Matrix4.identity()..scaleByDouble(s, s, 1, 1);

  @override
  Widget build(BuildContext context) {
    final has = _image != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(_path?.split(Platform.pathSeparator).last ?? 'AnnotatePicture'),
        actions: [
          IconButton(tooltip: 'Ouvrir', icon: const Icon(Icons.folder_open), onPressed: _open),
          IconButton(tooltip: 'Enregistrer', icon: const Icon(Icons.save), onPressed: has ? _save : null),
          IconButton(tooltip: 'Enregistrer sous', icon: const Icon(Icons.save_as), onPressed: has ? _saveAs : null),
        ],
      ),
      body: !has
          ? Center(child: FilledButton(onPressed: _open, child: const Text('Ouvrir une image')))
          : Column(children: [
              _toolbar(),
              Expanded(
                child: ClipRect(
                  child: InteractiveViewer(
                    transformationController: _zoom,
                    constrained: false,
                    minScale: 0.05,
                    maxScale: 8,
                    boundaryMargin: const EdgeInsets.all(2000),
                    child: GestureDetector(
                      onTap: () => setState(() => _sel = null),
                      child: SizedBox(
                        width: _image!.width.toDouble(),
                        height: _image!.height.toDouble(),
                        child: Stack(clipBehavior: Clip.none, children: [
                          RawImage(image: _image),
                          for (final n in _notes) _noteWidget(n),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
    );
  }

  Widget _noteWidget(Note n) => Positioned(
        left: n.pos.dx,
        top: n.pos.dy,
        child: GestureDetector(
          onTap: () => setState(() {
            _sel = n;
            _color = n.color;
            _size = n.size;
          }),
          onDoubleTap: () => _edit(n),
          onPanUpdate: (d) => setState(() {
            _sel = n;
            n.pos += d.delta / _zoom.value.getMaxScaleOnAxis();
          }),
          child: Container(
            decoration: BoxDecoration(
              border: n == _sel ? Border.all(color: Colors.blueAccent) : null,
            ),
            child: Text(n.text, style: TextStyle(color: n.color, fontSize: n.size)),
          ),
        ),
      );

  Widget _toolbar() => Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, children: [
          FilledButton.icon(onPressed: _add, icon: const Icon(Icons.text_fields), label: const Text('Texte')),
          IconButton(
            tooltip: 'Couleur libre',
            icon: Icon(Icons.palette, color: _color),
            onPressed: _pickColor,
          ),
          for (final c in _palette)
            GestureDetector(
              onTap: () => setState(() {
                _color = c;
                _sel?.color = c;
              }),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(width: c == _color ? 3 : 1, color: Colors.blueGrey),
                ),
              ),
            ),
          const Text('Taille'),
          SizedBox(
            width: 160,
            child: Slider(
              min: 8,
              max: 300,
              value: _size,
              onChanged: (v) => setState(() {
                _size = v;
                _sel?.size = v;
              }),
            ),
          ),
          IconButton(
            tooltip: 'Supprimer le texte sélectionné',
            icon: const Icon(Icons.delete),
            onPressed: _sel == null
                ? null
                : () => setState(() {
                      _notes.remove(_sel);
                      _sel = null;
                    }),
          ),
          const Text('Zoom'),
          ListenableBuilder(
            listenable: _zoom,
            builder: (_, _) => SizedBox(
              width: 200,
              child: Row(children: [
                Expanded(
                  child: Slider(
                    min: 0.05,
                    max: 8,
                    value: _zoom.value.getMaxScaleOnAxis().clamp(0.05, 8),
                    onChanged: _setScale,
                  ),
                ),
                Text('${(_zoom.value.getMaxScaleOnAxis() * 100).round()}%'),
              ]),
            ),
          ),
        ]),
      );
}
