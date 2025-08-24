import axios, { AxiosError, AxiosHeaders } from "axios";
import type { AxiosInstance, InternalAxiosRequestConfig } from "axios";
import { apiBase } from "../config/env";
import { authService, authStore } from "../services/authService";
import { logger } from "../utils/logger";

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

  const token = authStore.accessToken;
  if (token) {
    (config.headers ??= new AxiosHeaders()).set("Authorization", `Bearer ${token}`);
     config.headers.set("Accept", "application/json");
     config.headers.set("Content-Type", "application/json");
  }

  return config;
});


http.interceptors.response.use(
  (resp) => {
    logger.debug("HTTP ←", resp.status, resp.config.url, resp.data);
    return resp;
  },
  async (error: AxiosError) => {
    const original = error.config;
    logger.error("HTTP ✖", error.response?.status, original?.url, error.message, {
      data: error.response?.data,
    });

    // If 401 and not already retried, try refresh token
    if (error.response?.status === 401 && original && !original._retry) {
      if (!authStore.refreshToken) {
        logger.warn("No refresh_token. Force logout.");
        throw error;
      }

      (original as any)._retry = true;

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

       (original.headers as any).set
        ? original.headers.set("Authorization", `Bearer ${newToken}`)
        : (original.headers = { ...(original.headers || {}), Authorization: `Bearer ${newToken}` });

      return http(original);
    }

    throw error;
  },
);
