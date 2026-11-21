import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.onDiagnostics,required this.onModels,super.key});
  final VoidCallback onDiagnostics;
  final VoidCallback onModels;
  @override
  Widget build(BuildContext context){
    final theme=Theme.of(context); final scheme=theme.colorScheme;
    return Scaffold(
      appBar:AppBar(title:const Text('إعدادات CUTAWAN')),
      body:ListView(padding:const EdgeInsets.fromLTRB(16,12,16,30),children:[
        Text('التطبيق والجهاز',style:theme.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w900)),
        const SizedBox(height:9),
        Card(child:ListTile(
          leading:Icon(Icons.monitor_heart_outlined,color:scheme.primary),
          title:const Text('تشخيص وقبول Android'),
          subtitle:const Text('الذاكرة والبطارية والحرارة والتخزين واختبار التخزين الآمن'),
          trailing:const Icon(Icons.chevron_left_rounded),onTap:onDiagnostics,
        )),
        Card(child:ListTile(
          leading:Icon(Icons.memory_rounded,color:scheme.primary),
          title:const Text('مركز النماذج والاتصالات'),
          subtitle:const Text('النماذج المحلية والمزودون والمفاتيح وموافقة الإرسال السحابي'),
          trailing:const Icon(Icons.chevron_left_rounded),onTap:onModels,
        )),
        const SizedBox(height:20),
        Text('المظهر وإمكانية الوصول',style:theme.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w900)),
        const SizedBox(height:9),
        Card(child:ListTile(
          leading:Icon(Icons.dark_mode_outlined,color:scheme.primary),
          title:const Text('وضع الألوان'),
          subtitle:const Text('يتبع التطبيق إعداد المظهر الفاتح أو الداكن في نظام Android.'),
          trailing:const Text('تلقائي'),
        )),
        Card(child:ListTile(
          leading:Icon(Icons.motion_photos_off_outlined,color:scheme.primary),
          title:const Text('تقليل الحركة'),
          subtitle:const Text('تُراجع حركة الواجهة ضمن اختبارات إمكانية الوصول الخاصة بالنظام.'),
          trailing:const Icon(Icons.info_outline_rounded),
        )),
        const SizedBox(height:20),
        Text('الخصوصية والمعالجة',style:theme.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w900)),
        const SizedBox(height:9),
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('المعالجة المحلية هي المسار الافتراضي. لا تُرسل النصوص إلى مزود خارجي إلا بعد تفعيل النمط البعيد وحفظ موافقة صريحة.'),
          const SizedBox(height:8),
          Text('يمكن حذف مفاتيح المزود من مركز النماذج. لا تُدرج المفاتيح أو محتوى الفيديو في سجلات التشخيص.',style:theme.textTheme.bodySmall?.copyWith(color:scheme.onSurfaceVariant)),
        ]))),
        const SizedBox(height:20),
        Text('المعلومات القانونية',style:theme.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w900)),
        const SizedBox(height:9),
        const Card(child:ListTile(
          leading:Icon(Icons.policy_outlined),title:Text('التراخيص والإشعارات'),
          subtitle:Text('راجع LICENSE و THIRD_PARTY_NOTICES.md في مستودع CUTAWAN.'),
        )),
      ]),
    );
  }
}
