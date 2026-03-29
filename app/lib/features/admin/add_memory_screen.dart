import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart' if (kIsWeb) 'dart:html';

import '../../core/constants.dart';
import '../../core/theme.dart';

class AddMemoryScreen extends ConsumerStatefulWidget {
  const AddMemoryScreen({super.key});

  @override
  ConsumerState<AddMemoryScreen> createState() => _AddMemoryScreenState();
}

class _AddMemoryScreenState extends ConsumerState<AddMemoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
        title: const Text('Add Memory'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.book_outlined), text: 'Journal'),
            Tab(icon: Icon(Icons.question_answer_outlined), text: 'Q&A'),
            Tab(icon: Icon(Icons.photo_outlined), text: 'Photo'),
            Tab(icon: Icon(Icons.mic_outlined), text: 'Voice'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _JournalTab(),
          _QATab(),
          _PhotoTab(),
          _VoiceTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Journal Tab
// ---------------------------------------------------------------------------
class _JournalTab extends ConsumerStatefulWidget {
  const _JournalTab();

  @override
  ConsumerState<_JournalTab> createState() => _JournalTabState();
}

class _JournalTabState extends ConsumerState<_JournalTab> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  final _dateController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _contentController.dispose();
    _dateController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable(FunctionNames.addMemory);
      await callable.call({
        'type': MemoryType.journal,
        'content': _contentController.text.trim(),
        'metadata': {
          'date': _dateController.text.trim(),
          'tags': _tagsController.text.trim(),
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journal entry saved.')),
        );
        _formKey.currentState!.reset();
        _contentController.clear();
        _dateController.clear();
        _tagsController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              icon: Icons.book_outlined,
              title: 'Journal Entry',
              subtitle: 'Add a memory, story, or reflection from Kevin\'s life.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Date (optional)',
                hintText: 'e.g. Summer 1995, Christmas 2010',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Memory / Story',
                hintText:
                    'Write the journal entry, memory, or story in first person...',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 160),
                  child: Icon(Icons.edit_note_outlined),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter content.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags (optional)',
                hintText: 'e.g. family, fishing, advice',
                prefixIcon: Icon(Icons.tag_outlined),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save Journal Entry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Q&A Tab
// ---------------------------------------------------------------------------
class _QATab extends ConsumerStatefulWidget {
  const _QATab();

  @override
  ConsumerState<_QATab> createState() => _QATabState();
}

class _QATabState extends ConsumerState<_QATab> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable(FunctionNames.addMemory);
      await callable.call({
        'type': MemoryType.qa,
        'content': _answerController.text.trim(),
        'metadata': {
          'question': _questionController.text.trim(),
          'answer': _answerController.text.trim(),
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Q&A pair saved.')),
        );
        _questionController.clear();
        _answerController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              icon: Icons.question_answer_outlined,
              title: 'Q&A Pair',
              subtitle:
                  'Add a question Kevin might be asked, and his answer. These will be retrieved to ground his responses.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _questionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'e.g. What was your favorite thing about fishing?',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: Icon(Icons.help_outline_rounded),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter a question.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _answerController,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Kevin\'s Answer',
                hintText: 'Write Kevin\'s answer in first person...',
                alignLabelWithHint: true,
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 120),
                  child: Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter an answer.' : null,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save Q&A Pair'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Photo Tab
// ---------------------------------------------------------------------------
class _PhotoTab extends ConsumerStatefulWidget {
  const _PhotoTab();

  @override
  ConsumerState<_PhotoTab> createState() => _PhotoTabState();
}

class _PhotoTabState extends ConsumerState<_PhotoTab> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();
  final _dateController = TextEditingController();
  XFile? _pickedFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _captionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _pickedFile = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a photo.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      // Upload photo to Storage
      final bytes = await _pickedFile!.readAsBytes();
      final ext = _pickedFile!.name.split('.').last;
      final fileName =
          'photos/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = FirebaseStorage.instance.ref(fileName);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/$ext'));
      final downloadUrl = await ref.getDownloadURL();

      // Save memory record
      final callable = FirebaseFunctions.instance
          .httpsCallable(FunctionNames.addMemory);
      await callable.call({
        'type': MemoryType.photo,
        'content': _captionController.text.trim(),
        'metadata': {
          'caption': _captionController.text.trim(),
          'date': _dateController.text.trim(),
          'photoUrl': downloadUrl,
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo memory saved.')),
        );
        setState(() => _pickedFile = null);
        _captionController.clear();
        _dateController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(
              icon: Icons.photo_outlined,
              title: 'Photo Memory',
              subtitle: 'Upload a photo with a caption Kevin would say about it.',
            ),
            const SizedBox(height: 24),

            // Photo picker
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.creamDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _pickedFile != null
                        ? AppTheme.amber
                        : AppTheme.navyDeep.withOpacity(0.2),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                ),
                child: _pickedFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: kIsWeb
                            ? Image.network(_pickedFile!.path, fit: BoxFit.cover)
                            : Image.file(File(_pickedFile!.path),
                                fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 48, color: AppTheme.textLight),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to select a photo',
                            style: TextStyle(color: AppTheme.textLight),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Date (optional)',
                hintText: 'e.g. July 4th, 2008',
                prefixIcon: Icon(Icons.calendar_today_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _captionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Caption / Kevin\'s memory',
                hintText: 'Write what Kevin would say about this photo...',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Please enter a caption.' : null,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_outlined),
              label: const Text('Upload Photo Memory'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Voice Tab
// ---------------------------------------------------------------------------
class _VoiceTab extends ConsumerStatefulWidget {
  const _VoiceTab();

  @override
  ConsumerState<_VoiceTab> createState() => _VoiceTabState();
}

class _VoiceTabState extends ConsumerState<_VoiceTab> {
  final _labelController = TextEditingController();
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordedPath;
  bool _isLoading = false;

  @override
  void dispose() {
    _labelController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordedPath = path;
      });
    } else {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission required.')),
          );
        }
        return;
      }
      final config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        bitRate: 128000,
      );
      // For simplicity use a temp path (works on mobile; web uses blob)
      final path = kIsWeb ? '' : '/tmp/kevin_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(config, path: path);
      setState(() {
        _isRecording = true;
        _recordedPath = null;
      });
    }
  }

  Future<void> _upload() async {
    if (_recordedPath == null && !kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record audio first.')),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final fileName =
          'voices/${DateTime.now().millisecondsSinceEpoch}.m4a';
      final storageRef = FirebaseStorage.instance.ref(fileName);

      if (!kIsWeb && _recordedPath != null) {
        await storageRef.putFile(
          File(_recordedPath!),
          SettableMetadata(contentType: 'audio/mp4'),
        );
      }
      final downloadUrl = await storageRef.getDownloadURL();

      final callable = FirebaseFunctions.instance
          .httpsCallable(FunctionNames.addMemory);
      await callable.call({
        'type': MemoryType.voice,
        'content': _labelController.text.trim(),
        'metadata': {
          'label': _labelController.text.trim(),
          'audioUrl': downloadUrl,
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice clip saved.')),
        );
        setState(() => _recordedPath = null);
        _labelController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            icon: Icons.mic_outlined,
            title: 'Voice Clip',
            subtitle:
                'Record or upload a voice clip of Kevin. This is stored for reference and nostalgia.',
          ),
          const SizedBox(height: 32),

          // Record button
          Center(
            child: GestureDetector(
              onTap: _toggleRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording
                      ? Colors.red.withOpacity(0.15)
                      : AppTheme.navyDeep.withOpacity(0.08),
                  border: Border.all(
                    color: _isRecording ? Colors.red : AppTheme.navyDeep,
                    width: 2,
                  ),
                ),
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 44,
                  color: _isRecording ? Colors.red : AppTheme.navyDeep,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            _isRecording
                ? 'Recording... Tap to stop.'
                : _recordedPath != null
                    ? 'Recording ready. Add a label and upload.'
                    : 'Tap to start recording',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _isRecording ? Colors.red : AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 28),

          TextFormField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Label / Description',
              hintText: 'e.g. Kevin\'s laugh, 2019 Christmas message',
              prefixIcon: Icon(Icons.label_outline),
            ),
          ),

          const SizedBox(height: 28),

          ElevatedButton.icon(
            onPressed: (_isLoading || _isRecording) ? null : _upload,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.upload_outlined),
            label: const Text('Upload Voice Clip'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared section header widget
// ---------------------------------------------------------------------------
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.navyDeep.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.navyDeep, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
