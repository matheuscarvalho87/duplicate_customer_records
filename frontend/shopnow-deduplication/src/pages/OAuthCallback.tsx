import { useEffect, useState } from "react";
import { authService } from "@/services/authService";
import { useNavigate } from "react-router-dom";

export default function OAuthCallback() {
  const nav = useNavigate();
  const [status, setStatus] = useState<"loading" | "ok" | "fail">("loading");

  useEffect(() => {
    (async () => {
      try {
        const ok = await authService.handleOAuthCallback();
        setStatus(ok ? "ok" : "fail");
        nav(ok ? "/" : "/login", { replace: true });
      } catch {
        setStatus("fail");
        nav("/login", { replace: true });
      }
    })();
  }, [nav]);

  return (
    <div className="rounded border p-6 bg-white">
      {status === "loading" && <p>Finalizando login…</p>}
      {status === "ok" && <p>Login concluído. Redirecionando…</p>}
      {status === "fail" && <p>Falha na autenticação. Redirecionando…</p>}
    </div>
  );
}
