import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/estados_pedido.dart';
import '../core/theme.dart';
import '../models/pedido.dart';
import '../services/pedidos_service.dart';
import '../services/whatsapp_service.dart';
import '../widgets/estado_badge.dart';
import '../widgets/selector_estado_modal.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modelo interno para notas tipo chat.
// Se serializa/deserializa como JSON y se guarda en la columna notas_internas.
// ─────────────────────────────────────────────────────────────────────────────
class _NotaChat {
  final String texto;
  final DateTime fecha;

  _NotaChat({required this.texto, required this.fecha});

  Map<String, dynamic> toJson() => {
    'texto': texto,
    'fecha': fecha.toUtc().toIso8601String(),
  };

  factory _NotaChat.fromJson(Map<String, dynamic> j) => _NotaChat(
    texto: j['texto'] as String,
    fecha: DateTime.parse(j['fecha'] as String).toLocal(),
  );
}

// Parsea el valor raw de notas_internas de la BD.
// Soporta tres casos:
//   1. null / vacío                  → lista vacía
//   2. JSON array [ {...}, ... ]     → historial normal
//   3. Texto plano (legado)          → lo convierte al primer mensaje
List<_NotaChat> _parsearNotas(String? raw) {
  if (raw == null || raw.trim().isEmpty) return [];
  final trimmed = raw.trim();
  if (trimmed.startsWith('[')) {
    try {
      final lista = jsonDecode(trimmed) as List<dynamic>;
      return lista
          .map((e) => _NotaChat.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }
  // Texto plano legado → primer mensaje con fecha aproximada (creado_en del pedido,
  // o ahora si no disponemos de ella).
  return [_NotaChat(texto: trimmed, fecha: DateTime.now())];
}

String _serializarNotas(List<_NotaChat> notas) {
  if (notas.isEmpty) return '';
  return jsonEncode(notas.map((n) => n.toJson()).toList());
}

// ─────────────────────────────────────────────────────────────────────────────

class PedidoDetalleScreen extends StatefulWidget {
  final Pedido pedido;

  const PedidoDetalleScreen({super.key, required this.pedido});

  @override
  State<PedidoDetalleScreen> createState() => _PedidoDetalleScreenState();
}

class _PedidoDetalleScreenState extends State<PedidoDetalleScreen> {
  late Pedido _pedido;
  final _notaCtrl = TextEditingController();
  bool _guardandoNota = false;
  bool _eliminando = false;

  // Historial de notas parseado (cache local en memoria)
  List<_NotaChat> _notas = [];

  final _numeroOrdenCtrl = TextEditingController();
  final _codigoOrdenCtrl = TextEditingController();
  bool _guardandoGuiaShalom = false;
  bool _verificandoShalom = false;

  StreamSubscription<Pedido?>? _subs;

  @override
  void initState() {
    super.initState();
    _pedido = widget.pedido;
    _notas = _parsearNotas(_pedido.notasInternas);
    _numeroOrdenCtrl.text = _pedido.shalomNumeroOrden ?? '';
    _codigoOrdenCtrl.text = _pedido.shalomCodigoOrden ?? '';

    _subs = PedidosService.streamPedido(_pedido.id).listen((actualizado) {
      if (actualizado != null && mounted) {
        setState(() {
          _pedido = actualizado;
          // Solo sincronizamos notas si el usuario NO está escribiendo
          if (!_notaCtrl.selection.isValid) {
            _notas = _parsearNotas(actualizado.notasInternas);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _subs?.cancel();
    _notaCtrl.dispose();
    _numeroOrdenCtrl.dispose();
    _codigoOrdenCtrl.dispose();
    super.dispose();
  }

  // ── Contacto / WhatsApp ────────────────────────────────────────────────────

  Future<void> _copiarNumero() async {
    await Clipboard.setData(ClipboardData(text: _pedido.whatsapp));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número copiado al portapapeles')),
      );
    }
  }

  Future<void> _abrirWhatsapp() async {
    final mensaje = _pedido.mensajePedidoCompleto?.isNotEmpty == true
        ? _pedido.mensajePedidoCompleto!
        : (_pedido.mensajeWhatsappCorto ?? '');
    try {
      await WhatsappService.abrirChat(
          telefono: _pedido.whatsappLimpio, mensaje: mensaje);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  Future<void> _copiarMensaje() async {
    final texto = _pedido.mensajePedidoCompleto?.isNotEmpty == true
        ? _pedido.mensajePedidoCompleto!
        : 'Pedido de ${_pedido.nombreCompleto} — sin mensaje detallado guardado.';
    await Clipboard.setData(ClipboardData(text: texto));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Mensaje copiado. Ábrelo en WhatsApp y pégalo (mantén presionado → Pegar).'),
        ),
      );
    }
  }

  // ── Estados ────────────────────────────────────────────────────────────────

  Future<void> _cambiarEstadoPago() async {
    final nuevo = await mostrarSelectorEstado(
      context: context,
      titulo: 'Estado de pago',
      opciones: EstadosPedido.estadosPago,
      etiquetaDe: EstadosPedido.labelEstadoPago,
      colorDe: AppTheme.colorEstadoPago,
      actual: _pedido.estadoPago,
    );
    if (nuevo != null && nuevo != _pedido.estadoPago) {
      try {
        await PedidosService.actualizarEstadoPago(_pedido.id, nuevo);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text(
                  'No se pudo cambiar el estado: ${_mensajeError(e)}'),
            ),
          );
        }
      }
    }
  }

  Future<void> _cambiarEstadoEnvio() async {
    final flujo = EstadosPedido.flujoSegunTipo(_pedido.tipoEnvio);
    final nuevo = await mostrarSelectorEstado(
      context: context,
      titulo: 'Estado de envío (${_pedido.etiquetaDestino})',
      opciones: flujo,
      etiquetaDe: EstadosPedido.labelEstadoEnvio,
      colorDe: AppTheme.colorEstadoEnvio,
      actual: _pedido.estadoEnvio,
    );
    if (nuevo != null && nuevo != _pedido.estadoEnvio) {
      try {
        await PedidosService.actualizarEstadoEnvio(_pedido.id, nuevo);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text(
                  'No se pudo cambiar el estado: ${_mensajeError(e)}'),
            ),
          );
        }
      }
    }
  }

  // ── Notas tipo chat ────────────────────────────────────────────────────────

  Future<void> _guardarNota() async {
    final texto = _notaCtrl.text.trim();
    if (texto.isEmpty) return;

    setState(() => _guardandoNota = true);
    try {
      // Construimos el nuevo historial añadiendo la nota al final
      final nuevasNotas = List<_NotaChat>.from(_notas)
        ..add(_NotaChat(texto: texto, fecha: DateTime.now()));

      final jsonString = _serializarNotas(nuevasNotas);

      await PedidosService.guardarNotaInterna(_pedido.id, jsonString);

      if (mounted) {
        setState(() {
          _notas = nuevasNotas;
          _notaCtrl.clear(); // ← limpiamos el campo después de guardar
          // Actualizamos el pedido local con el nuevo JSON
          _pedido = Pedido(
            id: _pedido.id,
            creadoEn: _pedido.creadoEn,
            tiendaId: _pedido.tiendaId,
            tipoEnvio: _pedido.tipoEnvio,
            nombreCompleto: _pedido.nombreCompleto,
            whatsapp: _pedido.whatsapp,
            dni: _pedido.dni,
            distrito: _pedido.distrito,
            direccionExacta: _pedido.direccionExacta,
            agregaInstalacion: _pedido.agregaInstalacion,
            departamento: _pedido.departamento,
            ciudadDestino: _pedido.ciudadDestino,
            sedeShalom: _pedido.sedeShalom,
            cantidad: _pedido.cantidad,
            precioUnitario: _pedido.precioUnitario,
            costoInstalacion: _pedido.costoInstalacion,
            totalPagar: _pedido.totalPagar,
            estadoPago: _pedido.estadoPago,
            estadoEnvio: _pedido.estadoEnvio,
            mensajeWhatsappCorto: _pedido.mensajeWhatsappCorto,
            mensajePedidoCompleto: _pedido.mensajePedidoCompleto,
            notasInternas: jsonString,
            shalomNumeroOrden: _pedido.shalomNumeroOrden,
            shalomCodigoOrden: _pedido.shalomCodigoOrden,
            shalomUltimoEstado: _pedido.shalomUltimoEstado,
            shalomUltimaVerificacion: _pedido.shalomUltimaVerificacion,
            shalomTrackingActivo: _pedido.shalomTrackingActivo,
            shalomOrigen: _pedido.shalomOrigen,
            shalomDestino: _pedido.shalomDestino,
            eliminadoEn: _pedido.eliminadoEn,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota guardada ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('No se pudo guardar la nota: ${_mensajeError(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardandoNota = false);
    }
  }

  // ── Eliminar pedido ────────────────────────────────────────────────────────

  Future<void> _eliminarPedido() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar pedido?'),
        content: Text(
          'El pedido de ${_pedido.nombreCompleto} será eliminado de la lista.\n\n'
              'Podrás restaurarlo desde el Dashboard en cualquier momento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.peligro),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _eliminando = true);
    try {
      await PedidosService.eliminarPedido(_pedido.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _eliminando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('No se pudo eliminar: ${_mensajeError(e)}'),
          ),
        );
      }
    }
  }

  // ── Seguimiento Shalom ─────────────────────────────────────────────────────

  Future<void> _activarSeguimientoShalom() async {
    final numero = _numeroOrdenCtrl.text.trim();
    final codigo = _codigoOrdenCtrl.text.trim();
    if (numero.isEmpty || codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ingresa el N° de Orden y el Código de Orden')),
      );
      return;
    }
    setState(() => _guardandoGuiaShalom = true);
    try {
      await PedidosService.guardarGuiaShalom(
        _pedido.id,
        numeroOrden: numero,
        codigoOrden: codigo,
      );

      // ✅ FIX: verificamos PRIMERO y LUEGO mostramos el snackbar de éxito.
      // Así la UI no queda congelada en "Verificando..." con estado null.
      await _verificarShalomAhora(mostrarMensaje: false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seguimiento activado ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('No se pudo guardar la guía: ${_mensajeError(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardandoGuiaShalom = false);
    }
  }

  Future<void> _verificarShalomAhora({bool mostrarMensaje = true}) async {
    setState(() => _verificandoShalom = true);
    try {
      await PedidosService.verificarShalomAhora(_pedido.id);
      if (mounted && mostrarMensaje) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estado actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('No se pudo verificar: ${_mensajeError(e)}'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _verificandoShalom = false);
    }
  }

  Future<void> _quitarGuiaShalom() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Quitar guía Shalom?'),
        content:
        const Text('Se detendrá el seguimiento automático de este envío.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Quitar')),
        ],
      ),
    );
    if (confirmar != true) return;
    await PedidosService.quitarGuiaShalom(_pedido.id);
    if (mounted) {
      _numeroOrdenCtrl.clear();
      _codigoOrdenCtrl.clear();
    }
  }

  // ── Utilidades ─────────────────────────────────────────────────────────────

  String _hace(DateTime fecha) {
    final diff = DateTime.now().difference(fecha);
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return DateFormat('dd/MM/yyyy hh:mm a').format(fecha);
  }

  String _mensajeError(Object e) {
    final texto = e.toString();
    return texto.length > 160 ? '${texto.substring(0, 160)}...' : texto;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final formatoMoneda =
    NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final formatoFecha = DateFormat('dd/MM/yyyy hh:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del pedido')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_pedido.nombreCompleto,
              style:
              const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(formatoFecha.format(_pedido.creadoEn),
              style: const TextStyle(color: AppTheme.textoSecundario)),
          const SizedBox(height: 14),

          Row(
            children: [
              EstadoBadge(
                texto: EstadosPedido.labelEstadoPago(_pedido.estadoPago),
                color: AppTheme.colorEstadoPago(_pedido.estadoPago),
              ),
              const SizedBox(width: 8),
              EstadoBadge(
                texto: EstadosPedido.labelEstadoEnvio(_pedido.estadoEnvio),
                color: AppTheme.colorEstadoEnvio(_pedido.estadoEnvio),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _seccion('Contacto', [
            _filaDato(Icons.phone, 'Celular / WhatsApp', _pedido.whatsapp,
                accion: _copiarNumero, iconoAccion: Icons.copy),
            if (_pedido.dni != null)
              _filaDato(Icons.badge_outlined, 'DNI', _pedido.dni!),
          ]),

          _seccion('Envío', [
            _filaDato(
                Icons.place_outlined, 'Destino', _pedido.etiquetaDestino),
            if (_pedido.tipoEnvio == 'lima') ...[
              if (_pedido.distrito != null)
                _filaDato(Icons.map_outlined, 'Distrito', _pedido.distrito!),
              if (_pedido.direccionExacta != null)
                _filaDato(Icons.home_outlined, 'Dirección',
                    _pedido.direccionExacta!),
              _filaDato(Icons.build_outlined, 'Instalación',
                  _pedido.agregaInstalacion ? 'Sí' : 'No'),
            ] else ...[
              if (_pedido.departamento != null)
                _filaDato(Icons.map_outlined, 'Departamento',
                    _pedido.departamento!),
              if (_pedido.ciudadDestino != null)
                _filaDato(Icons.location_city_outlined, 'Ciudad',
                    _pedido.ciudadDestino!),
              if (_pedido.sedeShalom != null)
                _filaDato(Icons.store_outlined, 'Sede Shalom',
                    _pedido.sedeShalom!),
            ],
          ]),

          _seccion('Pedido', [
            _filaDato(
                Icons.shopping_bag_outlined, 'Cantidad', '${_pedido.cantidad}'),
            _filaDato(Icons.attach_money, 'Total a pagar',
                formatoMoneda.format(_pedido.totalPagar)),
          ]),

          if (_pedido.tipoEnvio == 'provincia') ...[
            const SizedBox(height: 4),
            _seccionSeguimientoShalom(),
          ],

          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cambiarEstadoPago,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Cambiar pago'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cambiarEstadoEnvio,
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Cambiar envío'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          ElevatedButton.icon(
            onPressed: _copiarMensaje,
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copiar mensaje del pedido'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _abrirWhatsapp,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Abrir WhatsApp del cliente'),
          ),

          // ── Notas tipo chat ──────────────────────────────────────────────
          const SizedBox(height: 24),
          _seccionNotasChat(),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),

          OutlinedButton.icon(
            onPressed: _eliminando ? null : _eliminarPedido,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.peligro,
              side: const BorderSide(color: AppTheme.peligro),
            ),
            icon: _eliminando
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.peligro),
            )
                : const Icon(Icons.delete_outline),
            label: Text(_eliminando ? 'Eliminando...' : 'Eliminar pedido'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ── Sección notas tipo chat ────────────────────────────────────────────────

  Widget _seccionNotasChat() {
    final formatoNota = DateFormat('dd/MM/yyyy hh:mm a');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notas internas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        // Historial de notas (burbujas de chat)
        if (_notas.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Column(
              children: _notas.map((nota) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Burbuja de nota
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primario.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nota.texto,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatoNota.format(nota.fecha),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textoSecundario
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text(
              'Sin notas aún. Agrega una nota para este pedido.',
              style: TextStyle(
                color: AppTheme.textoSecundario,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: 10),

        // Campo para nueva nota + botón enviar
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _notaCtrl,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Ej: cliente pidió cambiar dirección...',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Botón de enviar estilo chat
            SizedBox(
              height: 48,
              width: 48,
              child: _guardandoNota
                  ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
                  : IconButton.filled(
                onPressed: _guardarNota,
                icon: const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primario,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Sección seguimiento Shalom ─────────────────────────────────────────────

  Widget _seccionSeguimientoShalom() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Seguimiento Shalom',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.primario),
                ),
                const SizedBox(width: 6),
                const Text('🚚', style: TextStyle(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            if (!_pedido.tieneGuiaShalom) ...[
              const Text(
                'Ingresa el N° de Orden y el Código de Orden de la guía '
                    '(los mismos que aparecen en el ticket de Shalom) para '
                    'activar el seguimiento automático del envío.',
                style: TextStyle(
                    fontSize: 12.5, color: AppTheme.textoSecundario),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _numeroOrdenCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      decoration: const InputDecoration(
                        labelText: 'N° de Orden',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _codigoOrdenCtrl,
                      maxLength: 4,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Código de Orden',
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                  _guardandoGuiaShalom ? null : _activarSeguimientoShalom,
                  icon: _guardandoGuiaShalom
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.gps_fixed),
                  label: Text(_guardandoGuiaShalom
                      ? 'Activando...'
                      : 'Activar seguimiento'),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  EstadoBadge(
                    texto: _pedido.shalomUltimoEstado != null
                        ? EstadosPedido.labelEstadoEnvio(
                        _pedido.shalomUltimoEstado!)
                        : 'Verificando...',
                    color: AppTheme.colorEstadoEnvio(
                        _pedido.shalomUltimoEstado ?? 'nuevo'),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed:
                    _verificandoShalom ? null : () => _verificarShalomAhora(),
                    tooltip: 'Verificar ahora',
                    icon: _verificandoShalom
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.refresh, color: AppTheme.primario),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _pedido.shalomUltimaVerificacion != null
                    ? 'Última verificación: ${_hace(_pedido.shalomUltimaVerificacion!)}'
                    : 'Aún sin verificar — se revisará automáticamente en los próximos minutos.',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textoSecundario),
              ),
              if (_pedido.shalomOrigen != null ||
                  _pedido.shalomDestino != null) ...[
                const SizedBox(height: 10),
                if (_pedido.shalomOrigen != null)
                  _filaDato(Icons.trip_origin, 'Origen', _pedido.shalomOrigen!),
                if (_pedido.shalomDestino != null)
                  _filaDato(
                      Icons.flag_outlined, 'Destino', _pedido.shalomDestino!),
              ],
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _quitarGuiaShalom,
                  icon: const Icon(Icons.close,
                      size: 16, color: AppTheme.peligro),
                  label: const Text('Quitar guía',
                      style: TextStyle(color: AppTheme.peligro)),
                ),
              ),
            ],
            const SizedBox(height: 2),
            Text(
              'N° de Orden: 8 dígitos · Código de Orden: 4 caracteres (mismo formato que shalom.com.pe/rastrea)',
              style: TextStyle(
                  fontSize: 10.5,
                  color: AppTheme.textoSecundario.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets auxiliares ─────────────────────────────────────────────────────

  Widget _seccion(String titulo, List<Widget> filas) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.primario)),
            const SizedBox(height: 8),
            ...filas,
          ],
        ),
      ),
    );
  }

  Widget _filaDato(IconData icono, String etiqueta, String valor,
      {VoidCallback? accion, IconData? iconoAccion}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icono, size: 18, color: AppTheme.textoSecundario),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiqueta,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppTheme.textoSecundario)),
                Text(valor, style: const TextStyle(fontSize: 14.5)),
              ],
            ),
          ),
          if (accion != null)
            IconButton(
              onPressed: accion,
              icon: Icon(iconoAccion ?? Icons.touch_app, color: AppTheme.exito),
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
