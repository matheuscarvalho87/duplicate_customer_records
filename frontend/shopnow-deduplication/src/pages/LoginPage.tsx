import { authService, authStore } from "@/services/authService";

export default function LoginPage() {
  const isAuthed = !!authStore.accessToken;

  return (
    <div className="space-y-4">
      <h2 className="text-xl font-semibold">Login Salesforce</h2>
      

      {!isAuthed ? (
        <>
          <p className="text-slate-600">
            Authenticate with your Salesforce account to access the application.
          </p>
          <button
            onClick={() => authService.login()}
            className="rounded-lg bg-blue-600 px-4 py-2 text-white"
          >
            Enter with Salesforce
          </button>
        </>
      ) : (
        <div className="rounded border p-4 bg-white">
          <p className="text-emerald-700">You're already authenticated.</p>
          <p className="text-sm text-slate-500 mt-1">
            Go to <code className="px-1 rounded bg-slate-100">/</code> to see yout home.
          </p>
        </div>
      )}
    </div>
  );
}
