import axios, { AxiosError, AxiosHeaders } from "axios";
import type { AxiosInstance, InternalAxiosRequestConfig } from "axios";

import { apiBase } from "../config/env";
import { authService, authStore } from "../services/authService";
import { logger } from "../utils/logger";

function ensureAxiosHeaders(
  h?: InternalAxiosRequestConfig["headers"],
): AxiosHeaders {
  return h instanceof AxiosHeaders ? h : AxiosHeaders.from(h ?? {});
}


let isRefreshing = false;
let pendingQueue: Array<(token: string | null) => void> = [];

function subscribeTokenRefresh(cb: (token: string | null) => void) {
  pendingQueue.push(cb);
}
function onRefreshed(token: string | null) {
  pendingQueue.forEach((cb) => cb(token));
  pendingQueue = [];
}

export const http: AxiosInstance = axios.create({
  baseURL: apiBase,
  headers: { "Content-Type": "application/json" },
});

http.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  logger.debug("HTTP →", config.method?.toUpperCase(), config.baseURL, config.url, {
    params: config.params,
    data: config.data,
  });

  config.headers = ensureAxiosHeaders(config.headers);

  const token = authStore.accessToken;
  if (token) {
    (config.headers as AxiosHeaders).set("Authorization", `Bearer ${token}`);
  }

  (config.headers as AxiosHeaders).set("Accept", "application/json");
  (config.headers as AxiosHeaders).set("Content-Type", "application/json");

  return config;
});


http.interceptors.response.use(
  (resp) => {
    logger.debug("HTTP ←", resp.status, resp.config.url, resp.data);
    return resp;
  },
  async (error: AxiosError) => {
    const original = error.config as InternalAxiosRequestConfig & { _retry?: boolean };

    logger.error("HTTP ✖", error.response?.status, original?.url, error.message, {
      data: error.response?.data,
    });

    // If 401 error, try to refresh the token
    if (error.response?.status === 401 && original && !original._retry) {
      if (!authStore.refreshToken) {
        logger.warn("Sem refresh_token. Forçar logout.");
        throw error;
      }

      original._retry = true;

      if (!isRefreshing) {
        isRefreshing = true;
        try {
          const newAccess = await authService.refresh();
          onRefreshed(newAccess ?? null);
        } catch (e) {
          onRefreshed(null);
          throw e;
        } finally {
          isRefreshing = false;
        }
      }
      const newToken = await new Promise<string | null>((resolve) => {
        subscribeTokenRefresh(resolve);
      });

      if (!newToken) {
        logger.warn("Refresh failed. Force logout.");
        throw error;
      }

      original.headers = ensureAxiosHeaders(original.headers);
      (original.headers as AxiosHeaders).set("Authorization", `Bearer ${newToken}`);
      (original.headers as AxiosHeaders).set("Accept", "application/json");
      (original.headers as AxiosHeaders).set("Content-Type", "application/json");

      return http(original);
    }

    throw error;
  },
);
