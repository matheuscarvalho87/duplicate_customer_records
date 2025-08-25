export const ENV = {
  SF_BASE_URL: import.meta.env.VITE_SF_BASE_URL as string,
  SF_API_PREFIX: import.meta.env.VITE_SF_API_PREFIX as string,
  DEV_PROXY_PATH: import.meta.env.VITE_DEV_PROXY_PATH as string | undefined,

  SF_AUTH_URL: import.meta.env.VITE_SF_AUTH_URL as string,
  SF_TOKEN_URL: import.meta.env.VITE_SF_TOKEN_URL as string,
  SF_CLIENT_ID: import.meta.env.VITE_SF_CLIENT_ID as string,
  SF_REDIRECT_URI: import.meta.env.VITE_SF_REDIRECT_URI as string,
  SF_SCOPES: (import.meta.env.VITE_SF_SCOPES as string) || "openid refresh_token api web",

  DEV_AUTH_PROXY_PATH: import.meta.env.VITE_DEV_AUTH_PROXY_PATH as string | undefined,

  LOG_LEVEL: (import.meta.env.VITE_LOG_LEVEL as string) || "info",
};

export const apiBase = (() => {
  if (import.meta.env.DEV && ENV.DEV_PROXY_PATH) {
    return `${ENV.DEV_PROXY_PATH}${ENV.SF_API_PREFIX}`;
  }
  return `${ENV.SF_BASE_URL}${ENV.SF_API_PREFIX}`;
})();

export const tokenEndpoint = (() => {
  if (import.meta.env.DEV && ENV.DEV_AUTH_PROXY_PATH) {
    return `${ENV.DEV_AUTH_PROXY_PATH}/services/oauth2/token`;
  }
  return ENV.SF_TOKEN_URL;
})();
