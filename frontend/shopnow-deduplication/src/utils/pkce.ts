function base64UrlEncode(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export async function generateCodeVerifier(len = 64): Promise<string> {
  const array = new Uint8Array(len);
  crypto.getRandomValues(array);
  return Array.from(array, (d) => ("0" + d.toString(16)).slice(-2)).join("");
}

export async function sha256(input: string): Promise<ArrayBuffer> {
  const encoder = new TextEncoder();
  const data = encoder.encode(input);
  return crypto.subtle.digest("SHA-256", data);
}

export async function createCodeChallenge(verifier: string): Promise<string> {
  const hashed = await sha256(verifier);
  return base64UrlEncode(hashed);
}

const PKCE_KEYS = {
  VERIFIER: "pkce_code_verifier",
  STATE: "oauth_state",
};

export function storePkce(verifier: string, state: string) {
  sessionStorage.setItem(PKCE_KEYS.VERIFIER, verifier);
  sessionStorage.setItem(PKCE_KEYS.STATE, state);
}

export function popPkce(): { verifier: string | null; state: string | null } {
  const verifier = sessionStorage.getItem(PKCE_KEYS.VERIFIER);
  const state = sessionStorage.getItem(PKCE_KEYS.STATE);
  sessionStorage.removeItem(PKCE_KEYS.VERIFIER);
  sessionStorage.removeItem(PKCE_KEYS.STATE);
  return { verifier, state };
}
