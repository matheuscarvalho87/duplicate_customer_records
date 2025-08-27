import { useState } from 'react';
import { AlertCircle } from 'lucide-react';
import DuplicatesTable from '../components/DuplicatesTables';
import { useDuplicateManagement } from '../hooks/useDuplicateManagement';
import type { DuplicateMatch } from '../types/DuplicateMatch';
import DuplicateDetailModal from '@/components/modals/DuplicationDetailModal';


export default function Home() {
  const [selectedDuplicate, setSelectedDuplicate] = useState<DuplicateMatch | null>(null);

  const {
    duplicates,
    isLoading,
    isError,
    error,
    pagination,
    filters,
    actions,
  } = useDuplicateManagement({
    initialPageSize: 10
  });

  const handleRowClick = (duplicate: DuplicateMatch) => {
    setSelectedDuplicate(duplicate);
  };

  const handleMergeOne = async (id: string,) => {
      await actions.resolveOne(id, 'merge');
  };

  const handleIgnoreOne = async (id: string) => {
      await actions.resolveOne(id, 'ignore');
  };

  return (
    <div className="space-y-6">

      {isError && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <div className="flex items-start">
            <div className="flex-shrink-0">
              <AlertCircle className="w-5 h-5 text-red-400" />
            </div>
            <div className="ml-3 flex-1">
              <h3 className="text-sm font-medium text-red-800">Error Loading Data</h3>
              <p className="text-sm text-red-700 mt-1">{error?.message || 'An unexpected error occurred'}</p>
            </div>
          </div>
        </div>
      )}

      <div className="bg-white border border-gray-200 rounded-lg">
        {duplicates.length === 0 && !isLoading ? (
          <div className="text-center py-12">
            <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <AlertCircle className="w-6 h-6 text-green-600" />
            </div>
            <h3 className="text-lg font-medium text-gray-900 mb-2">No duplicates found</h3>
            <p className="text-gray-500 mb-6">
              {filters.hasActiveFilters 
                ? 'No duplicates match your current filters.'
                : 'Great! There are no pending duplicate records to review at this time.'}
            </p>
            {filters.hasActiveFilters && (
              <button
                onClick={filters.clearAllFilters}
                className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-blue-600 bg-blue-50 rounded-md hover:bg-blue-100"
              >
                Clear filters
              </button>
            )}
          </div>
        ) : (
          <DuplicatesTable
            duplicates={duplicates}
            onRowClick={handleRowClick}
            onMergeOne={handleMergeOne}
            onIgnoreOne={handleIgnoreOne}
            loading={isLoading || actions.isResolving}
            currentPage={pagination.currentPage}
            pageSize={pagination.pageSize}
            totalPages={pagination.totalPages}
            totalCount={pagination.totalCount}
            onPageChange={pagination.goToPage}
            onPageSizeChange={pagination.setPageSize}
          />
        )}
      </div>

      <DuplicateDetailModal
        duplicate={selectedDuplicate}
        onClose={() => setSelectedDuplicate(null)}
      />
    </div>
  );
}
