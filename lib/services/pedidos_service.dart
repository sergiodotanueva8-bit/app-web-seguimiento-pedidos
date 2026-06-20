import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pedido.dart';
import '../models/tienda.dart';
import 'supabase_service.dart';

class PedidosService {
  static SupabaseClient get _db => SupabaseService.client;

  /// Trae un solo pedido actualizado (usado para refrescar la pantalla
  /// de detalle después de guardar la guía Shalom o verificar el estado).
  static Future<Pedido> obtenerPedidoPorId(String pedidoId) async {
    final data = await _db.from('pedidos').select().eq('id', pedidoId).single();
    return Pedido.fromMap(data);
  }

  /// Stream en tiempo real de UN solo pedido (útil para que la pantalla
  /// de detalle se actualice sola cuando el cron de Shalom cambie el
  /// estado en segundo plano, sin que el usuario tenga que volver atrás).
  static Stream<Pedido?> streamPedido(String pedidoId) {
    return _db
        .from('pedidos')
        .stream(primaryKey: ['id'])
        .eq('id', pedidoId)
        .map((rows) => rows.isEmpty ? null : Pedido.fromMap(rows.first));
  }

  /// Trae pedidos una sola vez (RLS ya filtra por tienda automáticamente).
  static Future<List<Pedido>> listarPedidos() async {
    final data = await _db
        .from('pedidos')
        .select()
        .order('creado_en', ascending: false);
    return (data as List).map((e) => Pedido.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Stream en tiempo real: se actualiza solo cuando hay un INSERT/UPDATE/DELETE.
  /// RLS aplica también a las suscripciones realtime.
  static Stream<List<Pedido>> streamPedidos() {
    return _db
        .from('pedidos')
        .stream(primaryKey: ['id'])
        .order('creado_en', ascending: false)
        .map((rows) => rows.map((e) => Pedido.fromMap(e)).toList());
  }

  static Future<void> actualizarEstadoPago(String pedidoId, String nuevoEstado) async {
    await _db.from('pedidos').update({'estado_pago': nuevoEstado}).eq('id', pedidoId);
  }

  static Future<void> actualizarEstadoEnvio(String pedidoId, String nuevoEstado) async {
    await _db.from('pedidos').update({'estado_envio': nuevoEstado}).eq('id', pedidoId);
  }

  static Future<void> guardarNotaInterna(String pedidoId, String nota) async {
    await _db.from('pedidos').update({'notas_internas': nota}).eq('id', pedidoId);
  }

  /// Guarda el N° de Orden y Código de Orden de la guía Shalom para
  /// un pedido de provincia y activa el seguimiento automático.
  /// El Edge Function `verificar-shalom` (corre cada 3-5 min vía
  /// pg_cron) recogerá este pedido en su próxima pasada.
  static Future<void> guardarGuiaShalom(
      String pedidoId, {
        required String numeroOrden,
        required String codigoOrden,
      }) async {
    await _db.from('pedidos').update({
      'shalom_numero_orden': numeroOrden.trim(),
      'shalom_codigo_orden': codigoOrden.trim().toUpperCase(),
      'shalom_tracking_activo': true,
      // Limpiamos el estado anterior para que se note en la UI que
      // la primera verificación todavía está pendiente.
      'shalom_ultimo_estado': null,
      'shalom_ultima_verificacion': null,
    }).eq('id', pedidoId);
  }

  /// Quita la guía guardada y desactiva el seguimiento automático
  /// (por si el cliente se equivocó al ingresar el número/código).
  static Future<void> quitarGuiaShalom(String pedidoId) async {
    await _db.from('pedidos').update({
      'shalom_numero_orden': null,
      'shalom_codigo_orden': null,
      'shalom_tracking_activo': false,
      'shalom_ultimo_estado': null,
      'shalom_ultima_verificacion': null,
      'shalom_origen': null,
      'shalom_destino': null,
    }).eq('id', pedidoId);
  }

  /// Dispara una verificación inmediata (botón "Verificar ahora"),
  /// sin esperar a la próxima pasada del cron. Llama al mismo Edge
  /// Function que usa el cron, pero solo para este pedido puntual.
  static Future<void> verificarShalomAhora(String pedidoId) async {
    await _db.functions.invoke('verificar-shalom', body: {'pedido_id': pedidoId});
  }

  static Future<ResumenDashboard> obtenerResumen() async {
    final data = await _db.from('resumen_dashboard').select().maybeSingle();
    return ResumenDashboard.fromMap(data);
  }

  /// Resumen de ventas para un rango de fechas (semana, quincena, mes
  /// o un rango personalizado). `hasta` se considera exclusivo, así
  /// que para incluir todo el día final hay que pasar el día siguiente
  /// a las 00:00 (el dashboard ya se encarga de eso).
  static Future<VentasPeriodo> obtenerResumenVentas({
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final data = await _db.rpc('resumen_ventas_periodo', params: {
      'p_desde': desde.toIso8601String(),
      'p_hasta': hasta.toIso8601String(),
    });
    final fila = (data as List).isNotEmpty ? data.first as Map<String, dynamic> : null;
    return VentasPeriodo.fromMap(fila);
  }
}