import { useState } from 'react';
import { RefreshCw, Upload, AlertCircle } from 'lucide-react';
import DuplicatesTable from '../components/DuplicatesTables';
import ActionButtons from '../components/ActionButtons';
import { useDuplicates } from '../hooks/useDuplicateHooks';
import type { DuplicateMatch } from '../types/DuplicateMatch';
import { DuplicateDetailModal } from '@/components/modals/DuplicationDetailModal';




export default function Home() {
  const [selectedDuplicate, setSelectedDuplicate] = useState<DuplicateMatch | null>(null);
  
  const {
    duplicates,
    loading,
    error,
    selectedIds,
    totalCount,
    setSelectedIds,
    refreshData,
    mergeDuplicates,
    ignoreDuplicates,
    clearError
  } = useDuplicates({
    autoFetch: true,
  });

  const handleRowClick = (duplicate: DuplicateMatch) => {
    setSelectedDuplicate(duplicate);
  };

  const handleMerge = async (ids: string[]) => {
    try {
      await mergeDuplicates(ids);
    } catch (error) {
      console.error('Merge operation failed:', error);
    }
  };

  const handleIgnore = async (ids: string[]) => {
    try {
      await ignoreDuplicates(ids);
    } catch (error) {
      console.error('Ignore operation failed:', error);
    }
  };

  return (
    <div className="space-y-6">
      <div className="bg-white shadow-sm border border-gray-200 rounded-lg p-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">Duplicate Management</h1>
            <p className="text-gray-600 mt-1">
              Review and manage potential duplicate customer records
            </p>
          </div>
          
          <div className="flex items-center gap-3">
            <button
              onClick={refreshData}
              disabled={loading}
              className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
              aria-label="Refresh duplicate data"
            >
              <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
              Refresh
            </button>
          </div>
        </div>

        <div className="mt-6 grid grid-cols-1 md:grid-cols-4 gap-4">
          <div className="bg-blue-50 rounded-lg p-4">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <div className="w-8 h-8 bg-blue-100 rounded-md flex items-center justify-center">
                  <AlertCircle className="w-5 h-5 text-blue-600" />
                </div>
              </div>
              <div className="ml-3">
                <p className="text-sm font-medium text-blue-900">Pending Review</p>
                <p className="text-2xl font-semibold text-blue-700">{totalCount}</p>
              </div>
            </div>
          </div>
          
          <div className="bg-green-50 rounded-lg p-4">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <div className="w-8 h-8 bg-green-100 rounded-md flex items-center justify-center">
                  <svg className="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
              </div>
              <div className="ml-3">
                <p className="text-sm font-medium text-green-900">High Confidence</p>
                <p className="text-2xl font-semibold text-green-700">
                  {duplicates.filter(d => d.score >= 90).length}
                </p>
              </div>
            </div>
          </div>
          
          <div className="bg-yellow-50 rounded-lg p-4">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <div className="w-8 h-8 bg-yellow-100 rounded-md flex items-center justify-center">
                  <svg className="w-5 h-5 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.664-.833-2.464 0L3.34 16.5c-.77.833.192 2.5 1.732 2.5z" />
                  </svg>
                </div>
              </div>
              <div className="ml-3">
                <p className="text-sm font-medium text-yellow-900">Medium Confidence</p>
                <p className="text-2xl font-semibold text-yellow-700">
                  {duplicates.filter(d => d.score >= 70 && d.score < 90).length}
                </p>
              </div>
            </div>
          </div>
          
          <div className="bg-gray-50 rounded-lg p-4">
            <div className="flex items-center">
              <div className="flex-shrink-0">
                <div className="w-8 h-8 bg-gray-100 rounded-md flex items-center justify-center">
                  <svg className="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
              </div>
              <div className="ml-3">
                <p className="text-sm font-medium text-gray-900">Low Confidence</p>
                <p className="text-2xl font-semibold text-gray-700">
                  {duplicates.filter(d => d.score < 70).length}
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <div className="flex items-start">
            <div className="flex-shrink-0">
              <AlertCircle className="w-5 h-5 text-red-400" />
            </div>
            <div className="ml-3 flex-1">
              <h3 className="text-sm font-medium text-red-800">Error</h3>
              <p className="text-sm text-red-700 mt-1">{error}</p>
            </div>
            <div className="ml-auto pl-3">
              <button
                onClick={clearError}
                className="inline-flex rounded-md bg-red-50 p-1.5 text-red-500 hover:bg-red-100 focus:outline-none focus:ring-2 focus:ring-red-600 focus:ring-offset-2 focus:ring-offset-red-50"
              >
                <span className="sr-only">Dismiss</span>
                <svg className="h-4 w-4" viewBox="0 0 20 20" fill="currentColor">
                  <path fillRule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clipRule="evenodd" />
                </svg>
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="bg-white border border-gray-200 rounded-lg p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-4">
            <ActionButtons
              selectedIds={selectedIds}
              duplicates={duplicates}
              onMerge={handleMerge}
              onIgnore={handleIgnore}
              disabled={loading}
            />
          </div>
          
          <div className="flex items-center gap-3 text-sm text-gray-500">
            <span>
              {selectedIds.length > 0 
                ? `${selectedIds.length} of ${totalCount} selected` 
                : `${totalCount} total records`
              }
            </span>
            
            {loading && (
              <div className="flex items-center gap-2">
                <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
                <span>Loading...</span>
              </div>
            )}
          </div>
        </div>
      </div>

      <div className="bg-white border border-gray-200 rounded-lg">
        {totalCount === 0 && !loading ? (
          <div className="text-center py-12">
            <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7" />
              </svg>
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">No duplicates found</h3>
            <p className="text-gray-500 mb-6">
              Great! There are no pending duplicate records to review at this time.
            </p>
            <div className="flex items-center justify-center gap-3">
              <button
                onClick={refreshData}
                className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
              >
                <RefreshCw className="w-4 h-4" />
                Check Again
              </button>
              <button className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700">
                <Upload className="w-4 h-4" />
                Import Data
              </button>
            </div>
          </div>
        ) : (
          <DuplicatesTable
            duplicates={duplicates}
            selectedIds={selectedIds}
            onSelectionChange={setSelectedIds}
            onRowClick={handleRowClick}
            loading={loading}
          />
        )}
      </div>
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div className="flex">
          <div className="flex-shrink-0">
            <svg className="w-5 h-5 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          <div className="ml-3">
            <h3 className="text-sm font-medium text-blue-800">Tips for reviewing duplicates</h3>
            <div className="text-sm text-blue-700 mt-2">
              <ul className="list-disc list-inside space-y-1">
                <li><strong>High confidence (90%+):</strong> Usually safe to merge automatically</li>
                <li><strong>Medium confidence (70-89%):</strong> Review customer details before merging</li>
                <li><strong>Low confidence (&lt;70%):</strong> Carefully examine all fields before action</li>      
              </ul>
            </div>
          </div>
        </div>
      </div>
      <DuplicateDetailModal 
        duplicate={selectedDuplicate} 
        onClose={() => setSelectedDuplicate(null)} 
      />
    </div>
  );
}