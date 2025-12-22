import 'package:flutter/material.dart';

class ShowDialog {
  void showCommonDialog(BuildContext context, String title, String message, Color backGroundColor) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: backGroundColor,
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void showAutoDismissAlert(BuildContext context, String title, String message, int showSeconds) {
    showDialog(
      context: context,
      builder: (context) {
        // Schedule a delayed dismissal of the alert dialog after 3 seconds
        Future.delayed(Duration(seconds: showSeconds), () {
          Navigator.of(context).pop(); // Close the dialog
        });
        // Return the AlertDialog widget
        return AlertDialog(
          title: Text(title),
          content: Text(message),
        );
      },
    );
  }
}