import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

async function decryptShalom(base64Data: string, keyBase64: string): Promise<unknown> {
  const dataBytes = Uint8Array.from(atob(base64Data), c => c.charCodeAt(0));
  const dataHex = Array.from(dataBytes).map(b => b.toString(16).padStart(2, '0')).join('');
  const iv = new Uint8Array(dataHex.substring(0, 32).match(/.{2}/g)!.map(h => parseInt(h, 16)));
  const cipherBytes = new Uint8Array(dataHex.substring(32).match(/.{2}/g)!.map(h => parseInt(h, 16)));
  const keyBytes = Uint8Array.from(atob(keyBase64), c => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey("raw", keyBytes, { name: "AES-CBC" }, false, ["decrypt"]);
  const decrypted = await crypto.subtle.decrypt({ name: "AES-CBC", iv }, cryptoKey, cipherBytes);
  const text = new TextDecoder().decode(decrypted);
  try { return JSON.parse(text); } catch { return text; }
}

const KEY_STRING = "uQn/bQ94PXBEfId70zjN+VE1hSU7kh9VBXTOUd68Ssc=";
const SHALOM_API = "https://serviceswebapi.shalomcontrol.com/api/v1/web/rastrea";

async function shalomPost(endpoint: string, fields: Record<string, string>) {
  const formData = new FormData();
  for (const [k, v] of Object.entries(fields)) formData.append(k, v);
  const res = await fetch(`${SHALOM_API}/${endpoint}`, {
    method: "POST",
    headers: {
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
      "Origin": "https://shalom.com.pe",
      "Referer": "https://shalom.com.pe/rastrea",
    },
    body: formData,
  });
  if (!res.ok) throw new Error(`Shalom ${endpoint} HTTP ${res.status}`);
  const json = await res.json();
  if (json.encrypted && json.data) return await decryptShalom(json.data, KEY_STRING);
  return json;
}

// Devuelve clave interna compatible con Flutter (colorEstadoEnvio / labelEstadoEnvio)
function derivarEstado(estados: any, entregado: boolean): string {
  if (!estados) return "en_origen";
  if (entregado || estados.entregado?.fecha) return "entregado";
  if (estados.reparto?.fecha)        return "en_transito";
  if (estados.destino?.completo)     return "en_destino";
  if (estados.destino?.fecha)        return "en_destino";
  if (estados.transito?.completo)    return "en_transito";
  if (estados.transito?.fecha)       return "en_transito";
  if (estados.origen?.fecha)         return "en_origen";
  if (estados.registrado?.fecha)     return "en_origen";
  return "en_origen";
}

// Verifica UN pedido en Shalom y actualiza Supabase
async function verificarPedido(
  supabase: any,
  pedidoId: string,
  numeroOrden: string,
  codigoOrden: string
): Promise<{ id: string; estado: string; ok: boolean; error?: string }> {
  try {
    const respuesta: any = await shalomPost("buscar", {
      numero: numeroOrden,
      codigo: codigoOrden,
      ose_id: "",
    });

    if (!respuesta?.success || !respuesta?.data) {
      return { id: pedidoId, estado: "", ok: false, error: respuesta?.message || "No encontrado" };
    }

    const info = respuesta.data;

    let estados: any = null;
    if (info.ose_id) {
      try {
        const rawEstados: any = await shalomPost("estados", { ose_id: String(info.ose_id) });
        estados = rawEstados?.data || rawEstados;
      } catch (e) {
        console.error(`[${pedidoId}] Error obteniendo estados:`, e);
      }
    }

    const estado = derivarEstado(estados, info.entregado);

    await supabase.from("pedidos").update({
      shalom_ultimo_estado: estado,
      shalom_origen: info.origen?.nombre || null,
      shalom_destino: info.destino?.nombre || null,
      shalom_ultima_verificacion: new Date().toISOString(),
      // Si ya fue entregado, desactivamos el tracking para no gastar invocaciones
      ...(estado === "entregado" ? { shalom_tracking_activo: false } : {}),
    }).eq("id", pedidoId);

    return { id: pedidoId, estado, ok: true };
  } catch (e: any) {
    return { id: pedidoId, estado: "", ok: false, error: e.message };
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  try {
    const body = await req.json().catch(() => ({}));
    const { pedido_id, numero_orden, codigo_orden } = body;

    // ─── MODO INDIVIDUAL (botón manual desde la app, viene pedido_id) ─────────
    if (pedido_id) {
      let numeroOrden = numero_orden;
      let codigoOrden = codigo_orden;

      if (!numeroOrden || !codigoOrden) {
        const { data: pedido, error } = await supabase
          .from("pedidos")
          .select("shalom_numero_orden, shalom_codigo_orden")
          .eq("id", pedido_id)
          .single();

        if (error || !pedido?.shalom_numero_orden) {
          return new Response(
            JSON.stringify({ valido: false, mensaje: "No se encontraron datos de guía Shalom para este pedido" }),
            { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
          );
        }
        numeroOrden = pedido.shalom_numero_orden;
        codigoOrden = pedido.shalom_codigo_orden;
      }

      const resultado = await verificarPedido(supabase, pedido_id, numeroOrden, codigoOrden);

      if (!resultado.ok) {
        return new Response(
          JSON.stringify({ valido: false, mensaje: resultado.error }),
          { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
        );
      }

      return new Response(
        JSON.stringify({ valido: true, estado: resultado.estado }),
        { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
      );
    }

    // ─── MODO DIRECTO (numero_orden + codigo_orden sin pedido_id) ────────────
    // Solo para pruebas desde PowerShell, no se usa en producción
    if (numero_orden && codigo_orden) {
      const resultado = await verificarPedido(supabase, "test", numero_orden, codigo_orden);
      return new Response(
        JSON.stringify({ valido: resultado.ok, estado: resultado.estado, error: resultado.error }),
        { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
      );
    }

    // ─── MODO BATCH (llamado por cron-job.org sin pedido_id) ─────────────────
    const { data: pedidos, error } = await supabase
      .from("pedidos")
      .select("id, shalom_numero_orden, shalom_codigo_orden")
      .eq("shalom_tracking_activo", true)
      .not("shalom_numero_orden", "is", null)
      .not("shalom_codigo_orden", "is", null);

    if (error) {
      return new Response(
        JSON.stringify({ error: "Error leyendo pedidos: " + error.message }),
        { status: 500, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
      );
    }

    if (!pedidos || pedidos.length === 0) {
      return new Response(
        JSON.stringify({ mensaje: "No hay pedidos activos para verificar", total: 0 }),
        { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
      );
    }

    // Procesamos uno por uno con pausa para no saturar la API de Shalom
    const resultados = [];
    for (let i = 0; i < pedidos.length; i++) {
      const pedido = pedidos[i];
      const res = await verificarPedido(
        supabase,
        pedido.id,
        pedido.shalom_numero_orden,
        pedido.shalom_codigo_orden
      );
      resultados.push(res);
      if (i < pedidos.length - 1) {
        await new Promise(r => setTimeout(r, 500)); // 500ms entre pedidos
      }
    }

    const exitosos = resultados.filter(r => r.ok).length;
    const fallidos = resultados.filter(r => !r.ok).length;

    console.log(`Batch: ${exitosos} ok, ${fallidos} fallidos de ${pedidos.length} pedidos`);

    return new Response(
      JSON.stringify({ total: pedidos.length, exitosos, fallidos, resultados }),
      { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
    );

  } catch (err: any) {
    console.error("Error en Edge Function:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Error interno", valido: false }),
      { status: 500, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
    );
  }
});