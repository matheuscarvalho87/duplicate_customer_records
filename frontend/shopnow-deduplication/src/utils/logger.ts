import { ENV } from "../config/env";

type Level = "debug" | "info" | "warn" | "error";
const order: Record<Level, number> = { debug: 10, info: 20, warn: 30, error: 40 };

const current = (ENV.LOG_LEVEL as Level) || "info";
const threshold = order[current] ?? order.info;

export const logger = {
  debug: (...args: unknown[]) => {
    if (order.debug >= threshold) console.debug("[DEBUG]", ...args);
  },
  info: (...args: unknown[]) => {
    if (order.info >= threshold) console.info("[INFO]", ...args);
  },
  warn: (...args: unknown[]) => {
    if (order.warn >= threshold) console.warn("[WARN]", ...args);
  },
  error: (...args: unknown[]) => console.error("[ERROR]", ...args),
};
