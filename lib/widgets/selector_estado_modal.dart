import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Muestra un modal de opciones para elegir un nuevo estado.
/// Devuelve el valor elegido, o null si se cerró sin elegir.
Future<String?> mostrarSelectorEstado({
  required BuildContext context,
  required String titulo,
  required List<String> opciones,
  required String Function(String) etiquetaDe,
  required Color Function(String) colorDe,
  required String actual,
}) {
  return showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  titulo,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ...opciones.map((opcion) {
                final esActual = opcion == actual;
                final color = colorDe(opcion);
                return ListTile(
                  leading: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  title: Text(etiquetaDe(opcion)),
                  trailing: esActual ? const Icon(Icons.check, color: AppTheme.primario) : null,
                  onTap: () => Navigator.pop(context, opcion),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
