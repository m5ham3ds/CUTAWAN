import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../domain/project_contract.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({required this.projects,required this.onCreate,required this.onOpenJobs,required this.onOpenReview,required this.onOpenModels,required this.onOpenSettings,super.key});
  final ValueListenable<List<CutawanProject>> projects;
  final VoidCallback onCreate;
  final VoidCallback onOpenJobs;
  final VoidCallback onOpenReview;
  final VoidCallback onOpenModels;
  final VoidCallback onOpenSettings;
  @override
  Widget build(BuildContext context) {
    final theme=Theme.of(context); final scheme=theme.colorScheme;
    return ValueListenableBuilder<List<CutawanProject>>(
      valueListenable:projects,
      builder:(context,items,_){
        final completed=items.where((p)=>p.job.status==ProjectJobStatus.completed).length;
        final running=items.where((p)=>p.job.status==ProjectJobStatus.running).length;
        final attention=items.where((p)=>p.job.status==ProjectJobStatus.failed||p.job.status==ProjectJobStatus.cancelled).length;
        final recent=items.take(3).toList(growable:false);
        return ListView(
          key:const ValueKey('cutawan-dashboard-list'),
          padding:const EdgeInsets.fromLTRB(16,20,16,34),
          children:[
            Row(children:[
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('مساحة عملك',style:theme.textTheme.labelLarge?.copyWith(color:scheme.primary)),
                const SizedBox(height:5),
                Text('مرحباً بك في CUTAWAN',style:theme.textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
              ])),
              IconButton(key:const ValueKey('dashboard-settings'),tooltip:'الإعدادات',onPressed:onOpenSettings,icon:const Icon(Icons.settings_outlined)),
            ]),
            const SizedBox(height:16),
            Container(
              padding:const EdgeInsets.all(20),
              decoration:BoxDecoration(
                borderRadius:BorderRadius.circular(24),
                gradient:LinearGradient(begin:AlignmentDirectional.topStart,end:AlignmentDirectional.bottomEnd,colors:[scheme.primary.withValues(alpha:0.18),scheme.surfaceContainer]),
                border:Border.all(color:scheme.outlineVariant),
              ),
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Icon(Icons.movie_filter_rounded,size:28,color:scheme.primary),
                const SizedBox(height:12),
                Text('حوّل الفيديو إلى قصة قصيرة متماسكة.',style:theme.textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w900)),
                const SizedBox(height:7),
                Text('ابدأ باستيراد ملفك، ثم راجع التفريغ واللحظات المقترحة وعدّل المقاطع قبل التصدير.',style:theme.textTheme.bodyMedium?.copyWith(color:scheme.onSurfaceVariant)),
                const SizedBox(height:16),
                SizedBox(width:double.infinity,child:FilledButton.icon(
                  key:const ValueKey('dashboard-create-project'),onPressed:onCreate,
                  icon:const Icon(Icons.add_rounded),label:const Text('إنشاء مشروع جديد'),
                )),
              ]),
            ),
            const SizedBox(height:22),
            Text('نظرة عامة',style:theme.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w900)),
            const SizedBox(height:10),
            LayoutBuilder(builder:(context,constraints){
              final columns=constraints.maxWidth<350?2:3; const gap=9.0;
              final width=(constraints.maxWidth-gap*(columns-1))/columns;
              return Wrap(spacing:gap,runSpacing:gap,children:[
                SizedBox(width:width,child:_DashboardMetric(label:'المشاريع',value:items.length,icon:Icons.video_library_outlined)),
                SizedBox(width:width,child:_DashboardMetric(label:'مكتملة',value:completed,icon:Icons.check_circle_outline_rounded)),
                SizedBox(width:width,child:_DashboardMetric(label:'قيد العمل',value:running,icon:Icons.pending_outlined)),
                if(attention>0)SizedBox(width:width,child:_DashboardMetric(label:'تحتاج مراجعة',value:attention,icon:Icons.error_outline_rounded,warning:true)),
              ]);
            }),
            const SizedBox(height:22),
            Text('مسارات العمل',style:theme.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w900)),
            const SizedBox(height:9),
            _DashboardAction(icon:Icons.grid_view_rounded,title:'المهام والمشاريع',subtitle:'تابع التقدم، الأخطاء، والمساحة المستخدمة',onTap:onOpenJobs),
            const SizedBox(height:8),
            _DashboardAction(icon:Icons.movie_filter_outlined,title:'المراجعة والتحرير',subtitle:'راجع التفريغ والاقتراحات وحرّر حدود المقاطع',onTap:onOpenReview),
            const SizedBox(height:8),
            _DashboardAction(icon:Icons.memory_rounded,title:'مركز النماذج',subtitle:'إدارة Whisper والنماذج المحلية والمزودين',onTap:onOpenModels),
            const SizedBox(height:22),
            Row(children:[
              Expanded(child:Text('المشاريع الأخيرة',style:theme.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w900))),
              TextButton(onPressed:onOpenJobs,child:const Text('عرض الكل')),
            ]),
            if(recent.isEmpty)Card(child:Padding(
              padding:const EdgeInsets.all(18),
              child:Column(children:[
                Icon(Icons.video_collection_outlined,size:32,color:scheme.onSurfaceVariant),
                const SizedBox(height:8),
                const Text('لا توجد مشاريع محفوظة بعد'),
                const SizedBox(height:4),
                Text('سيظهر سجل الفيديوهات هنا بعد استيراد أول مشروع.',textAlign:TextAlign.center,style:theme.textTheme.bodySmall?.copyWith(color:scheme.onSurfaceVariant)),
              ]),
            )) else for(final project in recent)Card(
              margin:const EdgeInsets.only(bottom:8),
              child:ListTile(
                leading:CircleAvatar(backgroundColor:scheme.primary.withValues(alpha:0.12),child:Icon(Icons.video_file_outlined,color:scheme.primary)),
                title:Text(project.title,maxLines:1,overflow:TextOverflow.ellipsis),
                subtitle:Text('${project.source.width} × ${project.source.height} · ${project.job.stage}',maxLines:1,overflow:TextOverflow.ellipsis),
                trailing:const Icon(Icons.chevron_left_rounded),onTap:onOpenReview,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({required this.label,required this.value,required this.icon,this.warning=false});
  final String label; final int value; final IconData icon; final bool warning;
  @override
  Widget build(BuildContext context){
    final scheme=Theme.of(context).colorScheme;
    return Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:warning?scheme.error:scheme.primary),const SizedBox(height:9),
      Text(value.toString(),style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w900)),
      Text(label,maxLines:1,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.bodySmall?.copyWith(color:scheme.onSurfaceVariant)),
    ])));
  }
}
class _DashboardAction extends StatelessWidget {
  const _DashboardAction({required this.icon,required this.title,required this.subtitle,required this.onTap});
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  @override
  Widget build(BuildContext context){
    final scheme=Theme.of(context).colorScheme;
    return Card(child:ListTile(
      leading:Icon(icon,color:scheme.primary),
      title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),
      subtitle:Text(subtitle),trailing:const Icon(Icons.chevron_left_rounded),onTap:onTap,
    ));
  }
}
