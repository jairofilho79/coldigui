import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/color_extensions.dart';
import '../../../../l10n/app_localizations.dart';

/// Diálogo "ir para página" (spec A.3 C16) — teclado numérico com validação
/// 1..[pageCount]. Devolve a página escolhida via `Navigator.pop<int>`, ou
/// `null` se cancelado.
///
/// Acionado pelo toque no indicador de página ([PdfReaderPageIndicator]) e
/// pela tecla `G` ([PdfPageKeyboardPolicy] / [PdfReaderPageKeyHandler]).
class GoToPageDialog extends StatefulWidget {
  const GoToPageDialog({required this.pageCount, this.initialPage, super.key});

  /// Total de páginas do documento — teto da validação.
  final int pageCount;

  /// Valor inicial do campo (página atual), opcional.
  final int? initialPage;

  /// Abre o diálogo e devolve a página escolhida, ou `null` se cancelado.
  static Future<int?> show(
    BuildContext context, {
    required int pageCount,
    int? initialPage,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) =>
          GoToPageDialog(pageCount: pageCount, initialPage: initialPage),
    );
  }

  @override
  State<GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<GoToPageDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialPage?.toString() ?? '',
  );
  int? _validPage;

  @override
  void initState() {
    super.initState();
    _validPage = _parse(_controller.text);
    _controller.addListener(_onChanged);
  }

  int? _parse(String raw) {
    final value = int.tryParse(raw.trim());
    if (value == null || value < 1 || value > widget.pageCount) return null;
    return value;
  }

  void _onChanged() {
    final next = _parse(_controller.text);
    if (next != _validPage) {
      setState(() => _validPage = next);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final page = _validPage;
    if (page == null) return;
    Navigator.of(context).pop(page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(
        l10n?.readerGoToPageTitle ?? 'Ir para página',
        style: const TextStyle(color: AppColors.title),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(color: AppColors.title),
        decoration: InputDecoration(
          labelText: l10n?.readerGoToPageFieldLabel ?? 'Número da página',
          hintText: '1–${widget.pageCount}',
          hintStyle: TextStyle(color: AppColors.title.withValues(alpha: 0.5)),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.title),
          child: Text(l10n?.readerGoToPageCancel ?? 'Cancelar'),
        ),
        FilledButton(
          onPressed: _validPage == null ? null : _submit,
          child: Text(l10n?.readerGoToPageConfirm ?? 'Ir'),
        ),
      ],
    );
  }
}
