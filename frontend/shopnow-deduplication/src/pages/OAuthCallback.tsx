import { useEffect, useRef } from "react";
import { authService } from "@/services/authService";
import { useNavigate } from "react-router-dom";

export default function OAuthCallback() {
  const nav = useNavigate();
  const didRun = useRef(false);

  useEffect(() => {
    if (didRun.current) return; // avoid running twice in dev mode
    didRun.current = true;

    (async () => {
      try {
        const ok = await authService.handleOAuthCallback();
        nav(ok ? "/" : "/login", { replace: true });
      } catch {
        nav("/login", { replace: true });
      }
    })();
  }, [nav]);

  return <p className="p-6">Finishing login…</p>;
}
