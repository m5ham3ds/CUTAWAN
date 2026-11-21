import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../domain/clip_candidate.dart';
import '../../domain/clip_preferences.dart';
import '../../domain/project_contract.dart';
import '../../services/local_project_repository.dart';

class ClipEditorPage extends StatefulWidget {
  const ClipEditorPage({required this.project,required this.candidateSet,required this.candidate,required this.repository,required this.onSaved,super.key});
  final CutawanProject project;
  final CandidateSet candidateSet;
  final ClipCandidate candidate;
  final LocalProjectRepository repository;
  final Future<void> Function() onSaved;
  @override
  State<ClipEditorPage> createState()=>_ClipEditorPageState();
}

class _ClipEditorPageState extends State<ClipEditorPage>{
  VideoPlayerController? _player;
  late final TextEditingController _titleController;
  late int _startMs;
  late int _endMs;
  late ClipAspectRatio _aspectRatio;
  bool _loading=true;
  bool _saving=false;
  bool _handlingBoundary=false;
  String? _error;

  @override
  void initState(){
    super.initState();
    _startMs=widget.candidate.startMs;
    _endMs=widget.candidate.endMs;
    _aspectRatio=widget.project.preferences.aspectRatio;
    _titleController=TextEditingController(text:widget.candidate.title);
    unawaited(_initializePlayer());
  }

  Future<void> _initializePlayer() async{
    VideoPlayerController? controller;
    try{
      final uri=Uri.parse(widget.project.source.uri);
      controller=switch(uri.scheme){
        'content'=>VideoPlayerController.contentUri(uri),
        'file'=>VideoPlayerController.file(File.fromUri(uri)),
        'http'||'https'=>VideoPlayerController.networkUrl(uri),
        _=>throw FormatException('مصدر الفيديو غير مدعوم للمعاينة: ${uri.scheme}'),
      };
      await controller.initialize();
      await controller.setLooping(false);
      final duration=controller.value.duration.inMilliseconds;
      if (duration < 500) { throw StateError('مدة الفيديو أقصر من أن تسمح بإنشاء مقطع صالح.'); }
      _startMs=_startMs.clamp(0,duration-1).toInt();
      _endMs=_endMs.clamp(_startMs+1,duration).toInt();
      if (_endMs - _startMs < 500) { _endMs = (_startMs + 500).clamp(500, duration).toInt(); }
      controller.addListener(_handlePlaybackBoundary);
      await controller.seekTo(Duration(milliseconds:_startMs));
      if(!mounted){await controller.dispose();return;}
      setState(()=>_player=controller);
      setState(()=>_loading=false);
    }catch(error){
      await controller?.dispose();
      if (!mounted) { return; }
      setState(()=>_error=error.toString());
      setState(()=>_loading=false);
    }
  }

  void _handlePlaybackBoundary(){
    final player=_player;
    if (!mounted || player == null || !player.value.isInitialized || !player.value.isPlaying || _handlingBoundary) { return; }
    if (player.value.position.inMilliseconds < _endMs) { return; }
    _handlingBoundary=true;
    unawaited(player.pause().then((_)=>player.seekTo(Duration(milliseconds:_startMs))).whenComplete(()=>_handlingBoundary=false));
  }

  Future<void> _togglePlayback() async{
    final player=_player;
    if (player == null || !player.value.isInitialized) { return; }
    if(player.value.isPlaying){await player.pause();}
    else{
      final position=player.value.position.inMilliseconds;
      if (position < _startMs || position >= _endMs) { await player.seekTo(Duration(milliseconds: _startMs)); }
      await player.play();
    }
  }

  Future<void> _seekTo(int milliseconds) async{
    final player=_player;
    if (player == null || !player.value.isInitialized) { return; }
    await player.seekTo(Duration(milliseconds:milliseconds.clamp(_startMs,_endMs).toInt()));
  }

  void _updateTrim(RangeValues values){
    final player=_player;
    if (player == null || !player.value.isInitialized) { return; }
    final duration=player.value.duration.inMilliseconds;
    if (duration < 500) { return; }
    var start=values.start.round().clamp(0,duration-1).toInt();
    var end=values.end.round().clamp(1,duration).toInt();
    if(end-start<500){
      if(start+500<=duration){end=start+500;}
      else{start=(end-500).clamp(0,duration-1).toInt();}
    }
    setState(() { _startMs = start; _endMs = end; });
  }

  double _targetAspectRatio()=>switch(_aspectRatio){
    ClipAspectRatio.portrait916=>9/16,
    ClipAspectRatio.square11=>1,
    ClipAspectRatio.landscape169=>16/9,
    ClipAspectRatio.original=>_player?.value.aspectRatio??9/16,
  };

  Future<void> _saveEdits() async{
    if (_saving) { return; }
    final player=_player;
    if (player == null || !player.value.isInitialized) { return; }
    final duration=player.value.duration.inMilliseconds;
    if(_startMs<0||_endMs<=_startMs||_endMs>duration||_endMs-_startMs<500){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('نطاق القص غير صالح.')));
      return;
    }
    setState(()=>_saving=true);
    try{
      final title=_titleController.text.trim();
      final editedCandidate=widget.candidate.copyWith(
        startMs:_startMs,endMs:_endMs,
        title:title.isEmpty?widget.candidate.title:title,
      );
      final editedSet=widget.candidateSet.copyWith(
        candidates:widget.candidateSet.candidates.map((item)=>item.id==editedCandidate.id?editedCandidate:item).toList(growable:false),
      );
      editedSet.validate();
      final updatedProject=widget.project.copyWith(
        preferences:widget.project.preferences.copyWith(aspectRatio:_aspectRatio),
        updatedAtUtc:DateTime.now().toUtc(),
      );
      await widget.repository.saveCandidates(widget.project.id,editedSet);
      await widget.repository.save(updatedProject);
      await widget.onSaved();
      if (!mounted) { return; }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('حُفظت حدود المقطع ونسبة الإخراج. أعد تشغيل مسار المعالجة لتحديث التصدير.')));
      Navigator.of(context).pop();
    }catch(error){
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر حفظ تعديلات المقطع: $error'))); }
    }finally{
      if (mounted) { setState(() => _saving = false); }
    }
  }

  String _formatTime(int milliseconds){
    final value=milliseconds<0?0:milliseconds;
    final minutes=value~/60000;
    final seconds=(value%60000)~/1000;
    final tenths=(value%1000)~/100;
    return '${minutes.toString().padLeft(2,'0')}:${seconds.toString().padLeft(2,'0')}.$tenths';
  }

  @override
  void dispose(){
    _titleController.dispose();
    final player=_player;
    if(player!=null){player.removeListener(_handlePlaybackBoundary);unawaited(player.dispose());}
    super.dispose();
  }

  @override
  Widget build(BuildContext context){
    final theme=Theme.of(context);final scheme=theme.colorScheme;final player=_player;
    return Scaffold(
      appBar:AppBar(title:const Text('محرر المقطع'),actions:[
        IconButton(tooltip:'حفظ التعديلات',onPressed:_saving||_loading||_error!=null?null:_saveEdits,icon:const Icon(Icons.save_outlined)),
      ]),
      body:_loading?const Center(child:CircularProgressIndicator()):
        _error!=null||player==null?_PlaybackError(message:_error??'مشغل الفيديو غير متاح.'):
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable:player,
          builder:(context,value,_){
            if (!value.isInitialized) { return const Center(child: CircularProgressIndicator()); }
            final duration=value.duration.inMilliseconds;
            final position=value.position.inMilliseconds.clamp(_startMs,_endMs).toInt();
            final size=value.size;
            return ListView(padding:const EdgeInsets.fromLTRB(16,10,16,32),children:[
              Text('معاينة وتعديل',style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
              const SizedBox(height:5),
              Text('شغّل المصدر، حدّد بداية المقطع ونهايته، ثم احفظ التغييرات داخل المشروع.',style:theme.textTheme.bodySmall?.copyWith(color:scheme.onSurfaceVariant)),
              const SizedBox(height:14),
              Center(child:ConstrainedBox(
                constraints:const BoxConstraints(maxHeight:430),
                child:AspectRatio(
                  aspectRatio:_targetAspectRatio(),
                  child:ClipRRect(
                    borderRadius:BorderRadius.circular(22),
                    child:ColoredBox(color:Colors.black,child:FittedBox(
                      fit:BoxFit.cover,
                      child:SizedBox(width:size.width>0?size.width:16,height:size.height>0?size.height:9,child:VideoPlayer(player)),
                    )),
                  ),
                ),
              )),
              const SizedBox(height:8),
              Text('المعاينة تعرض قصّاً مركزياً حسب النسبة المختارة. خطة التأطير المتغيرة تُعاد معالجتها في التصدير.',style:theme.textTheme.bodySmall?.copyWith(color:scheme.onSurfaceVariant)),
              const SizedBox(height:12),
              Row(children:[
                IconButton.filledTonal(tooltip:value.isPlaying?'إيقاف مؤقت':'تشغيل',onPressed:_togglePlayback,icon:Icon(value.isPlaying?Icons.pause_rounded:Icons.play_arrow_rounded)),
                const SizedBox(width:10),
                Expanded(child:Text('${_formatTime(position)} / ${_formatTime(_endMs)}',style:theme.textTheme.bodySmall?.copyWith(fontWeight:FontWeight.w700))),
              ]),
              Slider(value:position.toDouble(),min:_startMs.toDouble(),max:_endMs.toDouble(),onChanged:(v)=>_seekTo(v.round())),
              const SizedBox(height:6),
              Text('نطاق القص',style:theme.textTheme.titleSmall?.copyWith(fontWeight:FontWeight.w900)),
              RangeSlider(
                values:RangeValues(_startMs.toDouble(),_endMs.toDouble()),min:0,max:duration.toDouble(),
                divisions:(duration~/250).clamp(1,1200).toInt(),
                labels:RangeLabels(_formatTime(_startMs),_formatTime(_endMs)),
                onChanged:_updateTrim,
                onChangeEnd: (_) { final current = player.value.position.inMilliseconds; if (current < _startMs || current > _endMs) { unawaited(_seekTo(_startMs)); } },
              ),
              Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                Text('البداية: ${_formatTime(_startMs)}'),Text('النهاية: ${_formatTime(_endMs)}'),
              ]),
              const SizedBox(height:18),
              TextField(controller:_titleController,maxLength:80,decoration:const InputDecoration(labelText:'اسم المقطع',prefixIcon:Icon(Icons.title_rounded))),
              const SizedBox(height:10),
              DropdownButtonFormField<ClipAspectRatio>(
                initialValue:_aspectRatio,isExpanded:true,
                decoration:const InputDecoration(labelText:'نسبة أبعاد الإخراج',prefixIcon:Icon(Icons.aspect_ratio_rounded)),
                items:ClipAspectRatio.values.map((ratio)=>DropdownMenuItem(value:ratio,child:Text(switch(ratio){
                  ClipAspectRatio.portrait916=>'عمودي 9:16',
                  ClipAspectRatio.square11=>'مربع 1:1',
                  ClipAspectRatio.landscape169=>'أفقي 16:9',
                  ClipAspectRatio.original=>'الأصلية',
                }))).toList(growable:false),
                onChanged:(value){if (value != null) { setState(() => _aspectRatio = value); }},
              ),
              const SizedBox(height:18),
              FilledButton.icon(
                onPressed:_saving?null:_saveEdits,
                icon:_saving?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)):const Icon(Icons.save_rounded),
                label:Text(_saving?'جارٍ حفظ التعديلات…':'حفظ تعديلات المقطع'),
              ),
            ]);
          },
        ),
    );
  }
}

class _PlaybackError extends StatelessWidget{
  const _PlaybackError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context){
    final scheme=Theme.of(context).colorScheme;
    return Center(child:Padding(
      padding:const EdgeInsets.all(24),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Icon(Icons.video_file_outlined,size:38,color:scheme.error),
        const SizedBox(height:12),
        const Text('تعذّر فتح معاينة الفيديو',style:TextStyle(fontWeight:FontWeight.w800)),
        const SizedBox(height:8),
        Text(message,textAlign:TextAlign.center),
      ]),
    ));
  }
}
