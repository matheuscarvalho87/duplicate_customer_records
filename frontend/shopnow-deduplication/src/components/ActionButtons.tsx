import React, { useState } from 'react';
import { Merge, UserX, Loader2, CheckCircle, XCircle, AlertTriangle } from 'lucide-react';
import type { DuplicateMatch } from '../types/DuplicateMatch';

interface ActionButtonsProps {
  selectedIds: string[];
  duplicates: DuplicateMatch[];
  onMerge: (ids: string[]) => Promise<void>;
  onIgnore: (ids: string[]) => Promise<void>;
  disabled?: boolean;
}

interface ActionState {
  isLoading: boolean;
  action: 'merge' | 'ignore' | null;
  showConfirmation: boolean;
  pendingIds: string[];
}

interface ToastMessage {
  type: 'success' | 'error' | 'warning';
  message: string;
  id: string;
}

export default function ActionButtons({
  selectedIds,
  duplicates,
  onMerge,
  onIgnore,
  disabled = false
}: ActionButtonsProps) {
  const [actionState, setActionState] = useState<ActionState>({
    isLoading: false,
    action: null,
    showConfirmation: false,
    pendingIds: []
  });
  
  const [toasts, setToasts] = useState<ToastMessage[]>([]);

  const selectedDuplicates = duplicates.filter(d => selectedIds.includes(d.id));
  const canPerformActions = selectedIds.length > 0 && !disabled && !actionState.isLoading;

  const showToast = (type: ToastMessage['type'], message: string) => {
    const id = Date.now().toString();
    setToasts(prev => [...prev, { type, message, id }]);
    
    setTimeout(() => {
      setToasts(prev => prev.filter(toast => toast.id !== id));
    }, 5000);
  };

  const dismissToast = (id: string) => {
    setToasts(prev => prev.filter(toast => toast.id !== id));
  };

  const handleActionClick = (action: 'merge' | 'ignore') => {
    if (!canPerformActions) return;

    setActionState({
      isLoading: false,
      action,
      showConfirmation: true,
      pendingIds: [...selectedIds]
    });
  };

  const confirmAction = async () => {
    const { action, pendingIds } = actionState;
    if (!action || pendingIds.length === 0) return;

    setActionState(prev => ({
      ...prev,
      isLoading: true,
      showConfirmation: false
    }));

    try {
      if (action === 'merge') {
        await onMerge(pendingIds);
        showToast('success', `Successfully merged ${pendingIds.length} duplicate${pendingIds.length === 1 ? '' : 's'}`);
      } else {
        await onIgnore(pendingIds);
        showToast('success', `Successfully ignored ${pendingIds.length} duplicate${pendingIds.length === 1 ? '' : 's'}`);
      }
    } catch (error) {
      console.error(`Failed to ${action} duplicates:`, error);
      showToast('error', `Failed to ${action} duplicates. Please try again.`);
    } finally {
      setActionState({
        isLoading: false,
        action: null,
        showConfirmation: false,
        pendingIds: []
      });
    }
  };

  const cancelAction = () => {
    setActionState({
      isLoading: false,
      action: null,
      showConfirmation: false,
      pendingIds: []
    });
  };

  const getToastIcon = (type: ToastMessage['type']) => {
    switch (type) {
      case 'success':
        return <CheckCircle className="w-5 h-5 text-green-500" />;
      case 'error':
        return <XCircle className="w-5 h-5 text-red-500" />;
      case 'warning':
        return <AlertTriangle className="w-5 h-5 text-yellow-500" />;
    }
  };

  return (
    <>
      <div className="flex items-center gap-2">
        <button
          onClick={() => handleActionClick('merge')}
          disabled={!canPerformActions}
          className={`inline-flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 ${
            canPerformActions
              ? 'bg-blue-600 hover:bg-blue-700 text-white focus:ring-blue-500'
              : 'bg-gray-300 text-gray-500 cursor-not-allowed'
          }`}
          aria-label={`Merge ${selectedIds.length} selected duplicate${selectedIds.length === 1 ? '' : 's'}`}
        >
          {actionState.isLoading && actionState.action === 'merge' ? (
            <Loader2 className="w-4 h-4 animate-spin" />
          ) : (
            <Merge className="w-4 h-4" />
          )}
          Merge ({selectedIds.length})
        </button>

        <button
          onClick={() => handleActionClick('ignore')}
          disabled={!canPerformActions}
          className={`inline-flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-md border transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 ${
            canPerformActions
              ? 'border-gray-300 bg-white text-gray-700 hover:bg-gray-50 focus:ring-gray-500'
              : 'border-gray-200 bg-gray-100 text-gray-400 cursor-not-allowed'
          }`}
          aria-label={`Ignore ${selectedIds.length} selected duplicate${selectedIds.length === 1 ? '' : 's'}`}
        >
          {actionState.isLoading && actionState.action === 'ignore' ? (
            <Loader2 className="w-4 h-4 animate-spin" />
          ) : (
            <UserX className="w-4 h-4" />
          )}
          Ignore ({selectedIds.length})
        </button>

        {selectedIds.length > 0 && (
          <span className="text-sm text-gray-500 ml-2">
            {selectedIds.length} selected
          </span>
        )}
      </div>

      {actionState.showConfirmation && (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div className="bg-white rounded-lg max-w-md w-full p-6">
            <div className="flex items-center gap-3 mb-4">
              <div className={`flex-shrink-0 w-10 h-10 rounded-full flex items-center justify-center ${
                actionState.action === 'merge' ? 'bg-blue-100' : 'bg-gray-100'
              }`}>
                {actionState.action === 'merge' ? (
                  <Merge className="w-5 h-5 text-blue-600" />
                ) : (
                  <UserX className="w-5 h-5 text-gray-600" />
                )}
              </div>
              <div>
                <h3 className="text-lg font-medium text-gray-900">
                  Confirm {actionState.action === 'merge' ? 'Merge' : 'Ignore'}
                </h3>
                <p className="text-sm text-gray-500">
                  {actionState.pendingIds.length} duplicate{actionState.pendingIds.length === 1 ? '' : 's'} selected
                </p>
              </div>
            </div>

            <div className="mb-6">
              <p className="text-sm text-gray-700 mb-4">
                {actionState.action === 'merge' 
                  ? 'This action will merge the selected duplicate records. The customer data will be consolidated, and duplicate entries will be marked as merged.'
                  : 'This action will mark the selected duplicates as ignored. They will no longer appear in pending reviews.'
                }
              </p>
              <div className="bg-gray-50 rounded-lg p-3 max-h-40 overflow-y-auto">
                <h4 className="text-xs font-medium text-gray-700 mb-2">Affected Records:</h4>
                <div className="space-y-2">
                  {selectedDuplicates.slice(0, 3).map((duplicate) => (
                    <div key={duplicate.id} className="text-xs text-gray-600">
                      {duplicate.customerA.firstName} {duplicate.customerA.lastName} ↔ {duplicate.customerB.firstName} {duplicate.customerB.lastName}
                      <span className="ml-2 text-blue-600">({duplicate.score}% match)</span>
                    </div>
                  ))}
                  {selectedDuplicates.length > 3 && (
                    <div className="text-xs text-gray-500">
                      ... and {selectedDuplicates.length - 3} more
                    </div>
                  )}
                </div>
              </div>
            </div>
            <div className="flex justify-end gap-3">
              <button
                onClick={cancelAction}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500"
              >
 
              </button>
              <button
                onClick={confirmAction}
                className={`px-4 py-2 text-sm font-medium text-white rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 ${
                  actionState.action === 'merge'
                    ? 'bg-blue-600 hover:bg-blue-700 focus:ring-blue-500'
                    : 'bg-gray-600 hover:bg-gray-700 focus:ring-gray-500'
                }`}
              >
                Confirm {actionState.action === 'merge' ? 'Merge' : 'Ignore'}
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="fixed top-4 right-4 space-y-2 z-50">
        {toasts.map((toast) => (
          <div
            key={toast.id}
            className={`flex items-center gap-3 px-4 py-3 rounded-lg shadow-lg max-w-sm animate-in slide-in-from-right ${
              toast.type === 'success' ? 'bg-green-50 border border-green-200' :
              toast.type === 'error' ? 'bg-red-50 border border-red-200' :
              'bg-yellow-50 border border-yellow-200'
            }`}
          >
            {getToastIcon(toast.type)}
            <p className={`text-sm font-medium ${
              toast.type === 'success' ? 'text-green-800' :
              toast.type === 'error' ? 'text-red-800' :
              'text-yellow-800'
            }`}>
              {toast.message}
            </p>
            <button
              onClick={() => dismissToast(toast.id)}
              className={`flex-shrink-0 ${
                toast.type === 'success' ? 'text-green-400 hover:text-green-600' :
                toast.type === 'error' ? 'text-red-400 hover:text-red-600' :
                'text-yellow-400 hover:text-yellow-600'
              }`}
              aria-label="Dismiss notification"
            >
              <XCircle className="w-4 h-4" />
            </button>
          </div>
        ))}
      </div>
    </>
  );
}