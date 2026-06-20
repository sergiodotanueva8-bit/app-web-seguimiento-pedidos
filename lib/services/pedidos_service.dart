import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pedido.dart';
import '../models/tienda.dart';
import 'supabase_service.dart';

class PedidosService {
  static SupabaseClient get _db => SupabaseService.client;

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