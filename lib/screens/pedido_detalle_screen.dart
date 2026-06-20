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

  @override
  void initState() {
    super.initState();
    _pedido = widget.pedido;
    _notaCtrl.text = _pedido.notasInternas ?? '';
  }

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
      await WhatsappService.abrirChat(telefono: _pedido.whatsappLimpio, mensaje: mensaje);
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
        const SnackBar(content: Text('Mensaje copiado. Ábrelo en WhatsApp y pégalo (mantén presionado → Pegar).')),
      );
    }
  }

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
              content: Text('No se pudo cambiar el estado: ${_mensajeError(e)}'),
            ),
          );
        }
        return; // No actualizamos el estado local: el cambio NO se guardó
      }
      setState(() {
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
          estadoPago: nuevo,
          estadoEnvio: _pedido.estadoEnvio,
          mensajeWhatsappCorto: _pedido.mensajeWhatsappCorto,
          mensajePedidoCompleto: _pedido.mensajePedidoCompleto,
          notasInternas: _pedido.notasInternas,
        );
      });
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
              content: Text('No se pudo cambiar el estado: ${_mensajeError(e)}'),
            ),
          );
        }
        return; // No actualizamos el estado local: el cambio NO se guardó
      }
      setState(() {
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
          estadoEnvio: nuevo,
          mensajeWhatsappCorto: _pedido.mensajeWhatsappCorto,
          mensajePedidoCompleto: _pedido.mensajePedidoCompleto,
          notasInternas: _pedido.notasInternas,
        );
      });
    }
  }

  Future<void> _guardarNota() async {
    setState(() => _guardandoNota = true);
    await PedidosService.guardarNotaInterna(_pedido.id, _notaCtrl.text.trim());
    setState(() => _guardandoNota = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nota guardada')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatoMoneda = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final formatoFecha = DateFormat('dd/MM/yyyy hh:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del pedido')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_pedido.nombreCompleto, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(formatoFecha.format(_pedido.creadoEn), style: const TextStyle(color: AppTheme.textoSecundario)),
          const SizedBox(height: 14),

          Row(
            children: [
              EstadoBadge(texto: EstadosPedido.labelEstadoPago(_pedido.estadoPago), color: AppTheme.colorEstadoPago(_pedido.estadoPago)),
              const SizedBox(width: 8),
              EstadoBadge(texto: EstadosPedido.labelEstadoEnvio(_pedido.estadoEnvio), color: AppTheme.colorEstadoEnvio(_pedido.estadoEnvio)),
            ],
          ),
          const SizedBox(height: 20),

          _seccion('Contacto', [
            _filaDato(Icons.phone, 'Celular / WhatsApp', _pedido.whatsapp, accion: _copiarNumero, iconoAccion: Icons.copy),
            if (_pedido.dni != null) _filaDato(Icons.badge_outlined, 'DNI', _pedido.dni!),
          ]),

          _seccion('Envío', [
            _filaDato(Icons.place_outlined, 'Destino', _pedido.etiquetaDestino),
            if (_pedido.tipoEnvio == 'lima') ...[
              if (_pedido.distrito != null) _filaDato(Icons.map_outlined, 'Distrito', _pedido.distrito!),
              if (_pedido.direccionExacta != null) _filaDato(Icons.home_outlined, 'Dirección', _pedido.direccionExacta!),
              _filaDato(Icons.build_outlined, 'Instalación', _pedido.agregaInstalacion ? 'Sí' : 'No'),
            ] else ...[
              if (_pedido.departamento != null) _filaDato(Icons.map_outlined, 'Departamento', _pedido.departamento!),
              if (_pedido.ciudadDestino != null) _filaDato(Icons.location_city_outlined, 'Ciudad', _pedido.ciudadDestino!),
              if (_pedido.sedeShalom != null) _filaDato(Icons.store_outlined, 'Sede Shalom', _pedido.sedeShalom!),
            ],
          ]),

          _seccion('Pedido', [
            _filaDato(Icons.shopping_bag_outlined, 'Cantidad', '${_pedido.cantidad}'),
            _filaDato(Icons.attach_money, 'Total a pagar', formatoMoneda.format(_pedido.totalPagar)),
          ]),

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

          const SizedBox(height: 24),
          const Text('Notas internas', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _notaCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Ej: cliente pidió cambiar dirección...'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _guardandoNota ? null : _guardarNota,
              child: Text(_guardandoNota ? 'Guardando...' : 'Guardar nota'),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// Intenta sacar un mensaje legible de una excepción de Supabase
  /// (PostgrestException trae el mensaje real del trigger/constraint
  /// que rechazó el cambio, ej. "no se puede revertir un pedido cancelado").
  String _mensajeError(Object e) {
    final texto = e.toString();
    // PostgrestException ya incluye el "message" de Postgres en su toString()
    return texto.length > 160 ? '${texto.substring(0, 160)}...' : texto;
  }

  Widget _seccion(String titulo, List<Widget> filas) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primario)),
            const SizedBox(height: 8),
            ...filas,
          ],
        ),
      ),
    );
  }

  Widget _filaDato(IconData icono, String etiqueta, String valor, {VoidCallback? accion, IconData? iconoAccion}) {
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
                Text(etiqueta, style: const TextStyle(fontSize: 11.5, color: AppTheme.textoSecundario)),
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