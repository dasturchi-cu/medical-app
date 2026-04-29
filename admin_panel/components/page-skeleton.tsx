export function PageSkeleton() {
  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
      {[1, 2, 3, 4].map((item) => (
        <div key={item} className="surface-card h-28 animate-pulse bg-slate-100" />
      ))}
    </div>
  );
}
