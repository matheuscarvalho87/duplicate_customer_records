
import { useCallback } from 'react';
import toast from 'react-hot-toast';

interface ToastOptions {
  duration?: number;
  position?: 'top-left' | 'top-center' | 'top-right' | 'bottom-left' | 'bottom-center' | 'bottom-right';
}

export function useToast() {
  const showToast = useCallback((
    message: string, 
    type: 'success' | 'error' | 'loading' | 'custom' = 'custom',
    options: ToastOptions = {}
  ) => {
    const toastOptions = {
      duration: options.duration || 4000,
      position: options.position || 'top-right',
    };

    switch (type) {
      case 'success':
        return toast.success(message, toastOptions);
      case 'error':
        return toast.error(message, toastOptions);
      case 'loading':
        return toast.loading(message, toastOptions);
      default:
        return toast(message, toastOptions);
    }
  }, []);

  const success = useCallback((message: string, options?: ToastOptions) => 
    showToast(message, 'success', options), [showToast]);
  
  const error = useCallback((message: string, options?: ToastOptions) => 
    showToast(message, 'error', options), [showToast]);
  
  const loading = useCallback((message: string, options?: ToastOptions) => 
    showToast(message, 'loading', options), [showToast]);

  const dismiss = useCallback((toastId?: string) => {
    const toast = require('react-hot-toast').default;
    toast.dismiss(toastId);
  }, []);

  return {
    toast: showToast,
    success,
    error,
    loading,
    dismiss,
  };
}