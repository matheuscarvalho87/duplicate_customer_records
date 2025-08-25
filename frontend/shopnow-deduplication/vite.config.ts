import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import tailwind from "@tailwindcss/vite";
import path from "path";

function readRawBody(req: import("http").IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (chunk) => (data += chunk));
    req.on("end", () => resolve(data));
    req.on("error", reject);
  });
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, ".", "");
  const API_PREFIX = env.VITE_DEV_PROXY_PATH || "/sf";
  const AUTH_PREFIX = env.VITE_DEV_AUTH_PROXY_PATH || "/sf-auth";

  const apexTarget = env.VITE_SF_BASE_URL;    
  const tokenUrl = env.VITE_SF_TOKEN_URL;           

  return {
    plugins: [
      react(),
      tailwind(),
      {
        name: "sf-auth-token-middleware",
        configureServer(server) {
          server.middlewares.use(`${AUTH_PREFIX}/services/oauth2/token`, async (req, res) => {
            if (req.method !== "POST") {
              res.statusCode = 405;
              res.setHeader("Content-Type", "text/plain");
              res.end("Method Not Allowed");
              return;
            }
            try {
              const raw = await readRawBody(req);
              const resp = await fetch(tokenUrl, {
                method: "POST",
                headers: { "Content-Type": "application/x-www-form-urlencoded" },
                body: raw,
                redirect: "follow",
              });
              res.statusCode = resp.status;
              res.setHeader("Content-Type", resp.headers.get("content-type") || "application/json");
              const text = await resp.text();
              res.end(text);
            } catch (e: any) {
              res.statusCode = 500;
              res.setHeader("Content-Type", "application/json");
              res.end(JSON.stringify({ error: "proxy_error", message: e?.message }));
            }
          });
        },
      },
    ],
    resolve: { alias: { "@": path.resolve(__dirname, "src") } },
    server: {
      port: 5173,
      proxy: {
        ...(apexTarget
          ? {
              [API_PREFIX]: {
                target: apexTarget,
                changeOrigin: true,
                secure: true,
              },
            }
          : {}),
      },
    },
  };
});
