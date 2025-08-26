import { Badge } from 'lucide-react';

export function MatchScoreBadge({ score }: { score: number }) {
  const getScoreColor = (score: number) => {
    if (score >= 90) return 'bg-red-100 text-red-800 border-red-200';
    if (score >= 70) return 'bg-yellow-100 text-yellow-800 border-yellow-200';
    if (score >= 50) return 'bg-blue-100 text-blue-800 border-blue-200';
    return 'bg-gray-100 text-gray-800 border-gray-200';
  };

  const getScoreLabel = (score: number) => {
    if (score >= 90) return 'High Match';
    if (score >= 70) return 'Medium Match';
    if (score >= 50) return 'Low Match';
    return 'Very Low Match';
  };

  return (
    <div className="flex items-center gap-2">
      <div className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium border ${getScoreColor(score)}`}>
        <Badge className="w-4 h-4 mr-1" />
        {score}% {getScoreLabel(score)}
      </div>
    </div>
  );
}