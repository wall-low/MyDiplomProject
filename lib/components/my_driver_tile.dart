import 'package:flutter/material.dart';

class MyDrawerTile extends StatelessWidget {

  final String title;
  final IconData iconData;
  final void Function()? onTap;

  const MyDrawerTile({super.key, required this.title, required this.iconData, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),),
      leading: Icon(iconData, color: Theme.of(context).colorScheme.onSurface,),
      onTap: onTap,
    );
   
  }
}