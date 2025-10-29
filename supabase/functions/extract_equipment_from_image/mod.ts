/// <reference path="./deno-stubs.d.ts" />

// CORS headers (declarados antes de Deno.serve para evitar referencias antes de inicialización)
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  // Incluye variantes en mayúsculas/minúsculas para evitar fallos de preflight en algunos navegadores
  "Access-Control-Allow-Headers": [
    "authorization",
    "Authorization",
    "x-client-info",
    "X-Client-Info",
    "apikey",
    "Apikey",
    "content-type",
    "Content-Type",
  ].join(", "),
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Credentials": "true",
  // Ayuda a caches/proxies y a los navegadores a procesar correctamente CORS
  "Vary": "Origin, Access-Control-Request-Method, Access-Control-Request-Headers",
  "Access-Control-Max-Age": "86400",
};

function encodeBase64(data: ArrayBuffer | Uint8Array | string): string {
  let bytes: Uint8Array;
  if (typeof data === "string") {
    bytes = new TextEncoder().encode(data);
  } else if (data instanceof Uint8Array) {
    bytes = data;
  } else {
    bytes = new Uint8Array(data);
  }
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]!);
  }
  return btoa(binary);
}

type RequestPayload = {
  mode?: "base64" | "url";
  image_base64?: string;
  image_url?: string;
  mime_type?: string;
};

const MODELS = (Deno.env.get("GEMINI_MODELS")?.split(",").map((s) => s.trim()).filter((s) => s.length > 0)) ?? [
  "gemini-2.5-flash-lite",
  "gemini-2.5-flash",
  "gemini-2.5-pro",
  "gemini-1.5-flash",
  "gemini-1.5-pro",
  "gemini-pro-vision",
];

const API_KEY = Deno.env.get("GOOGLE_API_KEY");
const ENDPOINT_BASE = "https://generativelanguage.googleapis.com/v1beta";

if (!API_KEY) {
  console.warn("[extract_equipment_from_image] GOOGLE_API_KEY no configurado en variables de entorno");
}

function buildPrompt(): string {
  return `Eres un asistente experto en equipos biomédicos.
Analiza la imagen del dispositivo o su etiqueta y devuelve exclusivamente un JSON con las claves:
{
  "name": string | null,
  "brand": string | null,
  "model": string | null,
  "serial": string | null,
  "category": string | null,
  "confidence": number,
  "notes": string | null
}

Reglas para "notes":
 - Escribe un único párrafo en español (120–180 palabras) que explique con detalle: 1) qué es el dispositivo de la imagen y 2) para qué se usa.
 - Apóyate explícitamente en lo que se observa: menciona al menos 3 rasgos visibles (por ejemplo, tipo de pantalla, mandos/puertos, conectores, sondas/accesorios, textos legibles, formas o materiales) y cómo esos rasgos justifican la identificación y el uso.
 - Describe brevemente cómo se opera en el uso típico (qué mide/administra/actúa) y en qué contexto clínico se emplea.
 - Evita respuestas genéricas; personaliza la explicación a lo que se ve en la imagen. No incluyas marcas, modelos ni números de serie dentro del párrafo.
Si la imagen NO muestra un equipo biomédico, establece: notes = "No le puedo responder a eso", category = null y confidence <= 0.3.
Si no estás seguro de un campo, usa null y reduce confidence.
Responde únicamente JSON válido, sin comentarios ni explicaciones.`;
}

function buildPayload(prompt: string, opts: { base64?: string; mime?: string }): any {
  const parts: any[] = [{ text: prompt }];
  if (opts.base64) {
    parts.push({ inline_data: { mime_type: opts.mime ?? "image/jpeg", data: opts.base64 } });
  }
  return {
    contents: [{ role: "user", parts }],
    generationConfig: { temperature: 0.3, responseMimeType: "application/json", maxOutputTokens: 512 },
  };
}

const SUPPORTED_IMAGE_MIMES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
  "image/bmp",
  "image/heic",
  "image/heif",
  "image/tiff",
]);

function detectMimeFromBytes(bytes: Uint8Array): string {
  // JPEG
  if (bytes.length >= 3 && bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF) return "image/jpeg";
  // PNG
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E && bytes[3] === 0x47 &&
    bytes[4] === 0x0D && bytes[5] === 0x0A && bytes[6] === 0x1A && bytes[7] === 0x0A
  ) return "image/png";
  // GIF
  if (
    bytes.length >= 6 &&
    bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46 &&
    bytes[3] === 0x38 && (bytes[4] === 0x39 || bytes[4] === 0x37) && bytes[5] === 0x61
  ) return "image/gif";
  // WEBP (RIFF....WEBP)
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
    bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50
  ) return "image/webp";
  // BMP
  if (bytes.length >= 2 && bytes[0] === 0x42 && bytes[1] === 0x4D) return "image/bmp";
  // TIFF (II*\0 or MM\0*)
  if (
    (bytes.length >= 4 && bytes[0] === 0x49 && bytes[1] === 0x49 && bytes[2] === 0x2A && bytes[3] === 0x00) ||
    (bytes.length >= 4 && bytes[0] === 0x4D && bytes[1] === 0x4D && bytes[2] === 0x00 && bytes[3] === 0x2A)
  ) return "image/tiff";
  // HEIC/HEIF: simple ftyp check with brand 'heic'/'heif' (not exhaustive)
  if (
    bytes.length >= 12 &&
    bytes[4] === 0x66 && bytes[5] === 0x74 && bytes[6] === 0x79 && bytes[7] === 0x70 &&
    ((bytes[8] === 0x68 && bytes[9] === 0x65 && bytes[10] === 0x69 && bytes[11] === 0x63) ||
     (bytes[8] === 0x68 && bytes[9] === 0x65 && bytes[10] === 0x69 && bytes[11] === 0x66))
  ) return "image/heic";
  return "image/jpeg"; // fallback razonable para el modelo
}

function decodeBase64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

async function fetchImageAsBase64(url: string): Promise<{ base64: string; mime: string }> {
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`No se pudo descargar imagen (${resp.status})`);
  let mime = resp.headers.get("content-type") ?? "image/jpeg";
  const ab = await resp.arrayBuffer();
  const bytes = new Uint8Array(ab);
  const base64 = encodeBase64(bytes);
  // Si el header es desconocido o no es image/*, detecta por firma
  if (!mime.startsWith("image/") || !SUPPORTED_IMAGE_MIMES.has(mime)) {
    mime = detectMimeFromBytes(bytes);
  }
  return { base64, mime };
}

async function callModel(model: string, payload: any): Promise<any> {
  const url = `${ENDPOINT_BASE}/models/${model}:generateContent?key=${API_KEY}`;
  const resp = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
  let data: any;
  try {
    data = await resp.json();
  } catch (_) {
    throw new Error(`Gemini ${resp.status}: respuesta no es JSON válido`);
  }
  if (!resp.ok) {
    throw new Error(`Gemini ${resp.status}: ${JSON.stringify(data)}`);
  }
  // Los resultados suelen venir en candidates[0].content.parts[0].text o output_text
  const raw = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? data?.candidates?.[0]?.output_text;
  if (!raw) throw new Error("Respuesta vacía de modelo");
  const clean = String(raw).trim().replace(/^```json\s*/i, "").replace(/```$/i, "");
  try {
    return JSON.parse(clean);
  } catch (e) {
    // Intenta encontrar primer bloque JSON
    const match = clean.match(/\{[\s\S]*\}/);
    if (match) return JSON.parse(match[0]);
    throw new Error(`No se pudo parsear JSON: ${String(e)}`);
  }
}

Deno.serve(async (req) => {
  try {
    // Preflight CORS
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Método no permitido" }), {
        status: 405,
        headers: { "content-type": "application/json", ...corsHeaders },
      });
    }

    const body = (await req.json()) as RequestPayload;
    const mode: "base64" | "url" | undefined = body.mode ?? (body.image_base64 ? "base64" : body.image_url ? "url" : undefined);
    if (!mode) {
      return new Response(JSON.stringify({ error: "Falta imagen (base64 o url)" }), {
        status: 400,
        headers: { "content-type": "application/json", ...corsHeaders },
      });
    }

    let base64 = body.image_base64;
    let mime = body.mime_type ?? "image/jpeg";
    if (mode === "url" && body.image_url) {
      const fetched = await fetchImageAsBase64(body.image_url);
      base64 = fetched.base64;
      mime = fetched.mime;
    }
    if (mode === "base64" && base64) {
      // Si mime no es image/* o no está soportado, intenta detectar
      if (!mime.startsWith("image/") || !SUPPORTED_IMAGE_MIMES.has(mime)) {
        const bytes = decodeBase64ToBytes(base64);
        mime = detectMimeFromBytes(bytes);
      }
    }

    if (!base64) {
      return new Response(JSON.stringify({ error: "No se pudo preparar imagen para el modelo" }), {
        status: 400,
        headers: { "content-type": "application/json", ...corsHeaders },
      });
    }

    const prompt = buildPrompt();
    const payload = buildPayload(prompt, { base64, mime });

    const errors: string[] = [];
    for (const model of MODELS) {
      try {
        const result = await callModel(model, payload);
        return new Response(
          JSON.stringify({ result, model_used: model, fallback_used: model !== MODELS[0] }),
          { headers: { "content-type": "application/json", ...corsHeaders } },
        );
      } catch (e) {
        errors.push(`${model}: ${(e as Error).message}`);
      }
    }

    return new Response(JSON.stringify({ error: "Todos los modelos fallaron", errors }), {
      status: 502,
      headers: { "content-type": "application/json", ...corsHeaders },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      status: 500,
      headers: { "content-type": "application/json", ...corsHeaders },
    });
  }
});