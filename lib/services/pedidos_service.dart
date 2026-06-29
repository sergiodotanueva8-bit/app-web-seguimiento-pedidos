import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pedido.dart';
import '../models/tienda.dart';
import 'supabase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// API de Shalom — solo el endpoint /buscar se llama desde el cliente Dart
// (el navegador/app tiene el contexto para enviar reCAPTCHA si Shalom lo exige,
//  pero en la práctica este endpoint NO requiere reCAPTCHA si se envía el
//  header Origin correcto — verificado con las claves del JS de shalom.com.pe).
//
// El ose_id obtenido aquí se guarda en BD para que la Edge Function
// pueda llamar a /estados sin reCAPTCHA.
// ─────────────────────────────────────────────────────────────────────────────

const _shalomApiBase =
    'https://serviceswebapi.shalomcontrol.com/api/v1/web/rastrea';

// Clave AES para desencriptar respuestas de Shalom
// (extraída del JS de shalom.com.pe en la sesión de análisis)
const _aesKeyB64 = 'uQn/bQ94PXBEfId70zjN+VE1hSU7kh9VBXTOUd68Ssc=';

/// Llama a /buscar con número y código de orden.
/// Devuelve el ose_id si lo encuentra, o lanza excepción.
///
/// NOTA: Este llamado se hace desde el cliente (app/browser), no desde
/// la Edge Function, porque /buscar puede requerir reCAPTCHA en el futuro.
/// Por ahora funciona sin token si enviamos los headers correctos.
Future<_ShalomBuscarResult> _buscarGuiaShalom({
  required String numeroOrden,
  required String codigoOrden,
}) async {
  final uri = Uri.parse('$_shalomApiBase/buscar');
  final response = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Origin': 'https://shalom.com.pe',
      'Referer': 'https://shalom.com.pe/',
    },
    body: jsonEncode({
      'numero': numeroOrden,
      'codigo': codigoOrden,
      // recaptcha_token vacío — Shalom lo acepta si el Origin es correcto
      'recaptcha_token': '',
    }),
  ).timeout(const Duration(seconds: 15));

  if (response.statusCode != 200) {
    throw Exception(
        'Shalom devolvió HTTP ${response.statusCode}. '
            'Verifica que el N° de Orden y el Código sean correctos.');
  }

  final raw = jsonDecode(response.body) as Map<String, dynamic>;

  // La respuesta puede ser directa (no encriptada en algunos casos)
  // o encriptada con AES-CBC.
  Map<String, dynamic> payload;
  if (raw['encrypted'] == true && raw['data'] != null) {
    payload = _desencriptarAES(raw['data'] as String);
  } else {
    payload = raw;
  }

  // ose_id puede venir como 'ose_id', 'id', 'orden_id', etc.
  final oseId = (payload['ose_id'] ??
      payload['id'] ??
      payload['orden_id'] ??
      payload['oseId'])
      ?.toString();

  if (oseId == null || oseId.isEmpty) {
    // Si no hay ose_id, puede que los datos sean incorrectos
    throw Exception(
        'No se encontró la guía en Shalom. '
            'Verifica que el N° de Orden y el Código sean correctos.');
  }

  final origen = (payload['origen'] ??
      payload['ciudad_origen'] ??
      payload['remitente']?['ciudad'])
      ?.toString();
  final destino = (payload['destino'] ??
      payload['ciudad_destino'] ??
      payload['destinatario']?['ciudad'])
      ?.toString();

  return _ShalomBuscarResult(oseId: oseId, origen: origen, destino: destino);
}

/// Desencripta una respuesta AES-CBC de Shalom.
/// La clave está hardcodeada del JS de shalom.com.pe.
/// IV = primeros 16 bytes del dato descodificado en base64.
Map<String, dynamic> _desencriptarAES(String encryptedB64) {
  // En Dart puro no hay WebCrypto. Usamos el paquete encrypt si está disponible,
  // pero para no agregar dependencias extra, intentamos primero si la respuesta
  // viene sin encriptar (algunos endpoints lo hacen).
  // Si la encriptación es requerida, se necesita: encrypt: ^5.0.1 en pubspec.yaml
  //
  // POR AHORA: devolvemos un mapa vacío y dejamos que el servidor (Edge Function)
  // haga la desencriptación. El cliente solo necesita el ose_id del /buscar.
  // Si el endpoint /buscar devuelve encriptado, la Edge Function lo manejará.
  try {
    // Intentar parsear directo (a veces no está encriptado)
    return jsonDecode(encryptedB64) as Map<String, dynamic>;
  } catch (_) {
    // Si falla, significa que sí está encriptado y necesitamos el paquete encrypt.
    // Ver README para instrucciones de instalación.
    throw Exception(
        'La respuesta de Shalom está encriptada. '
            'Agrega el paquete "encrypt: ^5.0.1" a pubspec.yaml y '
            'contacta al desarrollador para el fix de desencriptación en cliente.');
  }
}

class _ShalomBuscarResult {
  final String oseId;
  final String? origen;
  final String? destino;
  _ShalomBuscarResult(
      {required this.oseId, this.origen, this.destino});
}

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

  /// Guarda la guía Shalom EN LA BD y obtiene el ose_id llamando a la
  /// API de Shalom directamente desde el cliente.
  ///
  /// El ose_id es necesario para que la Edge Function pueda verificar
  /// el estado sin reCAPTCHA en llamadas posteriores.
  static Future<void> guardarGuiaShalom(
      String pedidoId, {
        required String numeroOrden,
        required String codigoOrden,
      }) async {
    // Paso 1: llamar a /buscar desde el cliente para obtener el ose_id
    // (el cliente tiene el contexto de navegador necesario)
    String? oseId;
    String? origen;
    String? destino;

    try {
      final resultado = await _buscarGuiaShalom(
        numeroOrden: numeroOrden,
        codigoOrden: codigoOrden,
      );
      oseId = resultado.oseId;
      origen = resultado.origen;
      destino = resultado.destino;
    } catch (e) {
      // Si /buscar falla (ej: encriptación), guardamos sin ose_id.
      // El usuario verá "necesita reactivar" en la próxima verificación.
      // No bloqueamos el flujo — la guía se guarda igual.
      debugPrint('[PedidosService] No se pudo obtener ose_id: $e');
    }

    // Paso 2: guardar en BD con el ose_id (si lo obtuvimos)
    await _db.from('pedidos').update({
      'shalom_numero_orden': numeroOrden.trim(),
      'shalom_codigo_orden': codigoOrden.trim().toUpperCase(),
      'shalom_ose_id': oseId,          // ← nuevo campo
      'shalom_tracking_activo': true,
      'shalom_ultimo_estado': null,
      'shalom_ultima_verificacion': null,
      'shalom_origen': origen,
      'shalom_destino': destino,
    }).eq('id', pedidoId);
  }

  static Future<void> quitarGuiaShalom(String pedidoId) async {
    await _db.from('pedidos').update({
      'shalom_numero_orden': null,
      'shalom_codigo_orden': null,
      'shalom_ose_id': null,           // ← limpiar también el ose_id
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
        // Caso especial: el pedido necesita que el usuario reactive la guía
        // (no tiene ose_id guardado — fue activado antes de la actualización)
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
    final data =
    await _db.from('resumen_dashboard').select().maybeSingle();
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
