import 'package:flutter/material.dart';
class InputBox extends StatelessWidget {

  final TextEditingController textEditingController;
  final String hintText;
  final void Function()? onPressed;
  final String onPressedText;


  const InputBox({super.key,
  required this.textEditingController,
  required this.hintText,
  required this.onPressed,
  required this.onPressedText});


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8))
      ),

        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      content: TextField(
        controller: textEditingController,
        maxLength: 100,
        maxLines: 3,
        decoration: InputDecoration(

          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
                borderRadius: BorderRadius.circular(12),
          ),

            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
              ),
              borderRadius: BorderRadius.circular(12),
            ),


          hintText: hintText,
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary),

          fillColor: Theme.of(context).colorScheme.secondaryContainer,
          filled: true,

            counterStyle: TextStyle(color: Theme.of(context).colorScheme.primary),


        ),
      ),
      actions: [
        TextButton(
            onPressed: (){
              Navigator.pop(context);
              textEditingController.clear();

            },
            child: const Text("Cancel")
        ),

        TextButton(
            onPressed: (){
              Navigator.pop(context);

              onPressed!();

              textEditingController.clear();

            },
            child: Text(onPressedText),
        )

      ],
    );
  }
}