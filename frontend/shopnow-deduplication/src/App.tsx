import { Routes, Route, Navigate, Link } from "react-router-dom";
import { Toaster } from 'react-hot-toast';
import { QueryProvider } from "./providers/QueryProvider";
import LoginPage from "./pages/LoginPage";
import OAuthCallback from "./pages/OAuthCallback";
import Home from "./pages/Home";
import { authStore } from "./services/authService";

function Protected({ children }: { children: React.ReactNode }) {
  const isAuthed = !!authStore.accessToken;
  return isAuthed ? <>{children}</> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <QueryProvider>
      <div className="min-h-screen bg-slate-50">
        <header className="border-b bg-white">
          <div className="mx-auto max-w-5xl px-6 py-4 flex items-center gap-6">
            <Link to="/" className="font-semibold">
              ShopNow — Duplicate Management
            </Link>
            <nav className="text-sm text-slate-600 flex gap-4">
              <Link to="/">Home</Link>
              <Link to="/login">Login</Link>
            </nav>
          </div>
        </header>

        <main className="mx-auto max-w-5xl p-6">
          <Routes>
            <Route
              path="/"
              element={
                <Protected>
                  <Home />
                </Protected>
              }
            />
            <Route path="/login" element={<LoginPage />} />
            <Route path="/oauth/callback" element={<OAuthCallback />} />
          </Routes>
        </main>
        <Toaster
          position="top-right"
          toastOptions={{
            duration: 4000,
            style: {
              background: '#363636',
              color: '#fff',
            },
            success: {
              style: {
                background: '#059669',
              },
            },
            error: {
              style: {
                background: '#dc2626',
              },
            },
          }}
        />
      </div>
    </QueryProvider>
  );
}