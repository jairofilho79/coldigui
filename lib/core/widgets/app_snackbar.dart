import 'package:flutter/material.dart';

/// Exibe toast via [SnackBar] (substitui AppSnackbarHost do SvelteKit).
void showAppSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
