// Envoi de notifications push via l'API FCM v1, authentifié avec un compte
// de service Firebase (OAuth2 "JWT bearer flow"). Pas de dépendance npm —
// tout est signé/appelé avec les primitives Web Crypto disponibles dans
// l'environnement Deno des Edge Functions.

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

function base64UrlEncode(bytes: Uint8Array | string): string {
  const raw = typeof bytes === 'string' ? bytes : String.fromCharCode(...bytes);
  return btoa(raw).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.token;
  }

  const header = { alg: 'RS256', typ: 'JWT' };
  const claims = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const encoder = new TextEncoder();
  const unsigned =
    base64UrlEncode(JSON.stringify(header)) +
    '.' +
    base64UrlEncode(JSON.stringify(claims));

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    encoder.encode(unsigned),
  );

  const jwt = `${unsigned}.${base64UrlEncode(new Uint8Array(signature))}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    throw new Error(`OAuth2 token exchange failed: ${await response.text()}`);
  }

  const json = await response.json();
  cachedAccessToken = {
    token: json.access_token,
    expiresAt: now + (json.expires_in ?? 3600),
  };
  return cachedAccessToken.token;
}

export interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

/// Envoie à un token FCM. Retourne false si le token est invalide/expiré
/// (l'appelant peut alors le supprimer de device_tokens).
export async function sendToToken(
  serviceAccount: ServiceAccount,
  token: string,
  message: PushMessage,
): Promise<boolean> {
  const accessToken = await getAccessToken(serviceAccount);

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: message.title, body: message.body },
          data: message.data ?? {},
          webpush: {
            notification: { icon: '/icons/Icon-192.png' },
          },
        },
      }),
    },
  );

  if (!response.ok) {
    const text = await response.text();
    const invalid =
      response.status === 404 ||
      text.includes('UNREGISTERED') ||
      text.includes('INVALID_ARGUMENT');
    if (!invalid) {
      console.error(`FCM send failed (${response.status}): ${text}`);
    }
    return false;
  }

  return true;
}

export function loadServiceAccount(): ServiceAccount {
  const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (!raw) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT secret is not set.');
  }
  return JSON.parse(raw);
}
