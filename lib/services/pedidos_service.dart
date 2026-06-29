import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pedido.dart';
import '../models/tienda.dart';
import 'supabase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shalom: TODO el contacto con la API de Shalom ocurre en las Edge Functions
// (buscar-shalom para obtener el ose_id, verificar-shalom para /estados).
//
// El cliente NO llama a Shalom ni desencripta nada. Esto hace que el flujo
// corra idéntico en web y móvil (sin CORS, sin headers prohibidos, sin AES
// en Dart).
// ─────────────────────────────────────────────────────────────────────────────

class PedidosService {
  static SupabaseClient get _db => SupabaseService.client;

  static Future<Pedido> obtenerPedidoPorId(String pedidoId) async {
    final data =
    await _db.from('pedidos').select().eq('id', pedidoId).single();
    return Pedido.fromMap(data);
  }

  static Stream<Pedido?> streamPedido(String pedidoId) {
    return _db
        .from('pedidos')
        .stream(primaryKey: ['id'])
        .eq('id', pedidoId)
        .map((rows) => rows.isEmpty ? null : Pedido.fromMap(rows.first));
  }

  static Future<List<Pedido>> listarPedidos() async {
    final data = await _db
        .from('pedidos')
        .select()
        .filter('eliminado_en', 'is', null)
        .order('creado_en', ascending: false);
    return (data as List)
        .map((e) => Pedido.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Stream<List<Pedido>> streamPedidos() {
    return _db
        .from('pedidos')
        .stream(primaryKey: ['id'])
        .order('creado_en', ascending: false)
        .map((rows) => rows
        .map((e) => Pedido.fromMap(e))
        .where((p) => !p.estaEliminado)
        .toList());
  }

  static Stream<List<Pedido>> streamPedidosEliminados() {
    return _db
        .from('pedidos')
        .stream(primaryKey: ['id'])
        .order('eliminado_en', ascending: false)
        .map((rows) => rows
        .map((e) => Pedido.fromMap(e))
        .where((p) => p.estaEliminado)
        .toList());
  }

  static Future<void> actualizarEstadoPago(
      String pedidoId, String nuevoEstado) async {
    final result = await _db
        .from('pedidos')
        .update({'estado_pago': nuevoEstado})
        .eq('id', pedidoId)
        .select('id');
    if ((result as List).isEmpty) {
      throw Exception(
          'No se pudo actualizar el estado (sin permiso o pedido no encontrado)');
    }
  }

  static Future<void> actualizarEstadoEnvio(
      String pedidoId, String nuevoEstado) async {
    final result = await _db
        .from('pedidos')
        .update({'estado_envio': nuevoEstado})
        .eq('id', pedidoId)
        .select('id');
    if ((result as List).isEmpty) {
      throw Exception(
          'No se pudo actualizar el estado (sin permiso o pedido no encontrado)');
    }
  }

  static Future<void> guardarNotaInterna(String pedidoId, String nota) async {
    final result = await _db
        .from('pedidos')
        .update({'notas_internas': nota.isEmpty ? null : nota})
        .eq('id', pedidoId)
        .select('id, notas_internas');
    if ((result as List).isEmpty) {
      throw Exception(
          'No se pudo guardar la nota. '
              'Verifica que tu sesión sea válida (cierra sesión y vuelve a entrar).');
    }
  }

  static Future<void> eliminarPedido(String pedidoId) async {
    final result = await _db
        .from('pedidos')
        .update({'eliminado_en': DateTime.now().toUtc().toIso8601String()})
        .eq('id', pedidoId)
        .select('id');
    if ((result as List).isEmpty) {
      throw Exception(
          'No se pudo eliminar el pedido (sin permiso o pedido no encontrado)');
    }
  }

  static Future<void> restaurarPedido(String pedidoId) async {
    final result = await _db
        .from('pedidos')
        .update({'eliminado_en': null})
        .eq('id', pedidoId)
        .select('id');
    if ((result as List).isEmpty) {
      throw Exception('No se pudo restaurar el pedido');
    }
  }

  /// Guarda la guía Shalom en BD obteniendo el ose_id vía la Edge Function
  /// buscar-shalom (server-side). Corre igual en web y móvil.
  ///
  /// Si la función no devuelve ose_id, la guía se guarda igual SIN ose_id y
  /// se relanza un error claro (antes esto quedaba en silencio y el
  /// seguimiento moría sin avisar).
  static Future<void> guardarGuiaShalom(
      String pedidoId, {
        required String numeroOrden,
        required String codigoOrden,
      }) async {
    String? oseId;
    String? origen;
    String? destino;
    String? errorMsg;

    try {
      final resp = await _db.functions.invoke(
        'buscar-shalom',
        body: {
          'numero': numeroOrden.trim(),
          'codigo': codigoOrden.trim().toUpperCase(),
        },
      );
      final data = resp.data;
      if (data is Map && data['ok'] == true) {
        oseId = data['ose_id']?.toString();
        origen = data['origen']?.toString();
        destino = data['destino']?.toString();
      } else if (data is Map) {
        errorMsg =
            (data['error'] ?? 'Respuesta inesperada de Shalom').toString();
        if (data['debug_raw'] != null) {
          debugPrint('[buscar-shalom] debug_raw: ${data['debug_raw']}');
        }
        if (data['debug_keys'] != null) {
          debugPrint('[buscar-shalom] claves recibidas: ${data['debug_keys']}');
        }
      } else {
        errorMsg = 'Respuesta inesperada de la función buscar-shalom.';
      }
    } catch (e) {
      errorMsg = e.toString();
      debugPrint('[PedidosService] buscar-shalom falló: $e');
    }

    await _db.from('pedidos').update({
      'shalom_numero_orden': numeroOrden.trim(),
      'shalom_codigo_orden': codigoOrden.trim().toUpperCase(),
      'shalom_ose_id': oseId,
      'shalom_tracking_activo': true,
      'shalom_ultimo_estado': null,
      'shalom_ultima_verificacion': null,
      'shalom_origen': origen,
      'shalom_destino': destino,
    }).eq('id', pedidoId);

    if (oseId == null || oseId.isEmpty) {
      throw Exception(
          'La guía se guardó, pero no se obtuvo el ose_id de Shalom'
              '${errorMsg != null ? " ($errorMsg)" : ""}. '
              'El seguimiento automático no quedará activo hasta resolverlo.');
    }
  }

  static Future<void> quitarGuiaShalom(String pedidoId) async {
    await _db.from('pedidos').update({
      'shalom_numero_orden': null,
      'shalom_codigo_orden': null,
      'shalom_ose_id': null,
      'shalom_tracking_activo': false,
      'shalom_ultimo_estado': null,
      'shalom_ultima_verificacion': null,
      'shalom_origen': null,
      'shalom_destino': null,
    }).eq('id', pedidoId);
  }

  static Future<void> verificarShalomAhora(String pedidoId) async {
    final response = await _db.functions.invoke(
      'verificar-shalom',
      body: {'pedido_id': pedidoId},
    );
    final data = response.data;
    if (data is Map) {
      if (data['ok'] == false) {
        if (data['necesita_reactivar'] == true) {
          throw Exception(
              'Este pedido fue activado antes de la actualización.\n'
                  'Por favor, presiona "Quitar guía" e ingresa el N° y Código de '
                  'Orden nuevamente para reactivar el seguimiento automático.');
        }
        final msg = data['error'] ?? 'Error desconocido en la verificación';
        throw Exception(msg.toString());
      }
    }
  }

  static Future<ResumenDashboard> obtenerResumen() async {
    final data = await _db.from('resumen_dashboard').select().maybeSingle();
    return ResumenDashboard.fromMap(data);
  }

  static Future<VentasPeriodo> obtenerResumenVentas({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final data = await _db.rpc('resumen_ventas_periodo', params: {
      'p_desde': desde.toIso8601String(),
      'p_hasta': hasta.toIso8601String(),
    });
    final fila =
    (data as List).isNotEmpty ? data.first as Map<String, dynamic> : null;
    return VentasPeriodo.fromMap(fila);
  }
}