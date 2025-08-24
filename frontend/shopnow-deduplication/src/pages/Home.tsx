import { authStore } from "@/services/authService";
import { duplicateService } from "@/services/duplicateService";
import { useEffect, useState } from "react";
import type { DuplicateMatch } from "@/types/DuplicateMatch";

export default function Home() {
  const [items, setItems] = useState<DuplicateMatch[]>([]);
  const [loading, setLoading] = useState(false);

  async function load() {
    setLoading(true);
    try {
      const data = await duplicateService.getPending();
      setItems(data);
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    load();
  }, []);

  return (
    <div className="space-y-4">
      <div className="rounded border bg-white p-4">
        <h2 className="text-lg font-semibold">Bem-vindo!</h2>
        <p className="text-sm text-slate-600 mt-1 break-all">
          <strong>Access Token:</strong> {authStore.accessToken ? "OK (oculto)" : "—"}
        </p>
      </div>

      <div className="rounded border bg-white p-4">
        <div className="flex items-center justify-between">
          <h3 className="font-medium">Duplicatas Pendentes</h3>
          <button onClick={load} className="rounded bg-slate-700 px-3 py-1 text-white">
            Recarregar
          </button>
        </div>
        {loading ? (
          <p className="mt-3 text-slate-500">Carregando…</p>
        ) : items.length === 0 ? (
          <p className="mt-3 text-slate-500">Nenhuma duplicata pendente.</p>
        ) : (
          <ul className="mt-3 list-disc pl-5 text-sm">
            {items.map((d) => (
              <li key={d.id}>
                {d.customerA.firstName} {d.customerA.lastName} ↔{" "}
                {d.customerB.firstName} {d.customerB.lastName} — score {d.score}
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
