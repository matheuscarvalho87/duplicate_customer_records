import axios from "axios";
import { ENV } from "../config/env";
import { createCodeChallenge, generateCodeVerifier, popPkce, storePkce } from "../utils/pkce";
import { logger } from "../utils/logger";

const STORAGE_KEYS = {
  ACCESS: "sf_access_token",
  REFRESH: "sf_refresh_token",
  INSTANCE: "sf_instance_url", 
  EXP: "sf_access_exp",
};

type TokenResponse = {
  access_token: string;
  refresh_token?: string;
  instance_url?: string;
  id_token?: string;
  issued_at?: string; 
  token_type?: string; 
  signature?: string;
  scope?: string;
  expires_in?: number;
};

function nowMs() {
  return Date.now();
}

export const authStore = {
  get accessToken() {
    return localStorage.getItem(STORAGE_KEYS.ACCESS);
  },
  set accessToken(value: string | null) {
    if (value) localStorage.setItem(STORAGE_KEYS.ACCESS, value);
    else localStorage.removeItem(STORAGE_KEYS.ACCESS);
  },
  get refreshToken() {
    return localStorage.getItem(STORAGE_KEYS.REFRESH);
  },
  set refreshToken(value: string | null) {
    if (value) localStorage.setItem(STORAGE_KEYS.REFRESH, value);
    else localStorage.removeItem(STORAGE_KEYS.REFRESH);
  },
  get instanceUrl() {
    return localStorage.getItem(STORAGE_KEYS.INSTANCE);
  },
  set instanceUrl(value: string | null) {
    if (value) localStorage.setItem(STORAGE_KEYS.INSTANCE, value);
    else localStorage.removeItem(STORAGE_KEYS.INSTANCE);
  },
  get accessExp() {
    const value = localStorage.getItem(STORAGE_KEYS.EXP);
    return value ? Number(value) : null;
  },
  set accessExp(value: number | null) {
    if (value) localStorage.setItem(STORAGE_KEYS.EXP, String(value));
    else localStorage.removeItem(STORAGE_KEYS.EXP);
  },
  clear() {
    this.accessToken = null;
    this.refreshToken = null;
    this.instanceUrl = null;
    this.accessExp = null;
  },
};

export const authService = {
  async login() {
    const state = crypto.randomUUID();
    const verifier = await generateCodeVerifier(64);
    const challenge = await createCodeChallenge(verifier);
    storePkce(verifier, state);

    const params = new URLSearchParams({
      response_type: "code",
      client_id: ENV.SF_CLIENT_ID,
      redirect_uri: ENV.SF_REDIRECT_URI,
      scope: ENV.SF_SCOPES,
      state,
      code_challenge: challenge,
      code_challenge_method: "S256",
    });
    const url = `${ENV.SF_AUTH_URL}?${params.toString()}`;
    window.location.assign(url);
  },

  async handleOAuthCallback() {
    const url = new URL(window.location.href);
    const code = url.searchParams.get("code");
    const returnedState = url.searchParams.get("state");
    if (!code) return false;

    const { verifier, state } = popPkce();
    if (!verifier || !state || state !== returnedState) {
      logger.error("PKCE/State inválido.");
      return false;
    }

    const body = new URLSearchParams({
      grant_type: "authorization_code",
      code,
      client_id: ENV.SF_CLIENT_ID,
      redirect_uri: ENV.SF_REDIRECT_URI,
      code_verifier: verifier,
    });

    const resp = await axios.post<TokenResponse>(ENV.SF_TOKEN_URL, body, {
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    });

    persistTokens(resp.data);
    return true;
  },

  async refresh() {
    const refresh_token = authStore.refreshToken;
    if (!refresh_token) return null;

    const body = new URLSearchParams({
      grant_type: "refresh_token",
      client_id: ENV.SF_CLIENT_ID,
      refresh_token,
    });

    const resp = await axios.post<TokenResponse>(ENV.SF_TOKEN_URL, body, {
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    });

    persistTokens(resp.data, true);
    return resp.data.access_token;
  },

  logout() {
    authStore.clear();
  },

  isAccessTokenValid(): boolean {
    const exp = authStore.accessExp;
    if (!exp) return false;
    return nowMs() < exp - 30_000;
  },
};

function persistTokens(t: TokenResponse, keepRefresh = false) {
  authStore.accessToken = t.access_token;
  if (!keepRefresh && t.refresh_token) authStore.refreshToken = t.refresh_token;
  if (t.instance_url) authStore.instanceUrl = t.instance_url;

  const expMs =
    t.expires_in != null ? nowMs() + t.expires_in * 1000 : t.issued_at ? Number(t.issued_at) : null;
  authStore.accessExp = expMs ?? nowMs() + 3600 * 1000;
}
