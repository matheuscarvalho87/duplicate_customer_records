import axios from "axios";
import { apiBase } from "../config/env";

export const http = axios.create({
  baseURL: apiBase,
  headers: { "Content-Type": "application/json" },
});

http.interceptors.request.use((config) => {
  return config;
});
