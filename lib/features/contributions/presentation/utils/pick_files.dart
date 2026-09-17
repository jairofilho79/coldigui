import 'package:file_picker/file_picker.dart';

/// Assina o `FilePicker` real; a tela recebe [PickFiles] por parâmetro para
/// os testes de widget nunca tocarem o plugin (nota do Step 6 do plano).
typedef PickFiles = Future<List<PlatformFile>> Function({
  required Set<String> allowedExtensions,
});

/// Implementação real de [PickFiles] — usada como valor padrão de
/// `ContributeScreen.pickFiles`.
Future<List<PlatformFile>> platformPickFiles({
  required Set<String> allowedExtensions,
}) {
  // file_picker 13: `FilePicker.pickFiles` (sem `.platform`) já devolve
  // `List<PlatformFile>` (vazia se o usuário cancelar) — nada de
  // `FilePickerResult?`/`withData` da API antiga.
  return FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowedExtensions.toList(),
  );
}
