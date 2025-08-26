import type { DuplicateMatch } from '@/types/DuplicateMatch';
import CustomerCard from '../CustomerCard';

interface DuplicateDetailModalProps {
  duplicate: DuplicateMatch | null;
  onClose: () => void;
}

export function DuplicateDetailModal({ duplicate, onClose }: DuplicateDetailModalProps) {
  if (!duplicate) return null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
      <div className="bg-white rounded-lg max-w-4xl w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
          <h2 className="text-xl font-semibold text-gray-900">Duplicate Match Details</h2>
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 transition-colors"
            aria-label="Close modal"
          >
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        
        <div className="p-6 space-y-6">
          {/* Match Score and Status */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <span className={`inline-flex items-center px-3 py-2 rounded-full text-lg font-semibold ${
                duplicate.score >= 90 ? 'bg-red-100 text-red-800' :
                duplicate.score >= 70 ? 'bg-yellow-100 text-yellow-800' :
                'bg-green-100 text-green-800'
              }`}>
                {duplicate.score}% Match
              </span>
              <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${
                duplicate.status === 'Pending Review' ? 'bg-gray-100 text-gray-800' :
                duplicate.status === 'Merged' ? 'bg-green-100 text-green-800' :
                'bg-red-100 text-red-800'
              }`}>
                {duplicate.status}
              </span>
            </div>
          </div>

          {/* Customer Comparison */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div>
              <h3 className="text-lg font-medium text-gray-900 mb-4">Customer A</h3>
              <CustomerCard
                customer={duplicate.customerA}
                otherCustomer={duplicate.customerB}
                showDifferences={true}
                variant="detailed"
              />
            </div>
            
            <div>
              <h3 className="text-lg font-medium text-gray-900 mb-4">Customer B</h3>
              <CustomerCard
                customer={duplicate.customerB}
                otherCustomer={duplicate.customerA}
                showDifferences={true}
                variant="detailed"
              />
            </div>
          </div>
          <div className="border-t border-gray-200 pt-6">
            <div className="flex justify-end gap-3">
              <button
                onClick={onClose}
                className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
              >
                Close
              </button>
              {duplicate.status === 'Pending Review' && (
                <>
                  <button className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50">
                    Ignore
                  </button>
                  <button className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700">
                    Merge
                  </button>
                </>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}