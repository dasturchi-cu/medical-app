import type { ReactNode } from "react";
import {
  Table as UITable,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

interface Column<T> {
  key: keyof T | string;
  label: string;
  render?: (item: T) => ReactNode;
}

interface AppTableProps<T> {
  columns: Column<T>[];
  data: T[];
  emptyText?: string;
}

export function AppTable<T extends object>({
  columns,
  data,
  emptyText = "Ma'lumot mavjud emas.",
}: AppTableProps<T>) {
  const emptyState = (
    <div className="mx-auto max-w-xs py-8 text-center text-slate-500">
      <p className="font-medium text-slate-700">{emptyText}</p>
      <p className="text-xs text-slate-400">Yangi ma&apos;lumot qo&apos;shing yoki filtrni o&apos;zgartiring.</p>
    </div>
  );

  return (
    <div className="surface-card overflow-hidden border border-slate-100">
      <div className="space-y-3 p-3 md:hidden">
        {data.length > 0
          ? data.map((item, index) => (
              <article key={index} className="rounded-xl border border-slate-100 bg-white p-3">
                <div className="space-y-2">
                  {columns.map((column) => (
                    <div key={String(column.key)} className="space-y-1">
                      <p className="text-[11px] font-semibold uppercase tracking-wide text-slate-400">
                        {column.label}
                      </p>
                      <div className="text-sm text-slate-700">
                        {column.render
                          ? column.render(item)
                          : String((item as Record<string, unknown>)[String(column.key)] ?? "")}
                      </div>
                    </div>
                  ))}
                </div>
              </article>
            ))
          : emptyState}
      </div>

      <div className="hidden w-full overflow-x-auto md:block">
        <UITable className="min-w-[760px]">
          <TableHeader>
            <TableRow className="bg-slate-50/70">
              {columns.map((column) => (
                <TableHead
                  key={String(column.key)}
                  className="h-11 px-3 text-xs font-semibold uppercase tracking-wide text-slate-500 md:px-4"
                >
                  {column.label}
                </TableHead>
              ))}
            </TableRow>
          </TableHeader>
          <TableBody>
            {data.length > 0 ? (
              data.map((item, index) => (
                <TableRow key={index} className="hover:bg-slate-50/80">
                  {columns.map((column) => (
                    <TableCell
                      key={String(column.key)}
                      className="px-3 py-2 text-xs text-slate-700 md:px-4 md:py-3 md:text-sm"
                    >
                      {column.render
                        ? column.render(item)
                        : String((item as Record<string, unknown>)[String(column.key)] ?? "")}
                    </TableCell>
                  ))}
                </TableRow>
              ))
            ) : (
              <TableRow>
                <TableCell colSpan={columns.length} className="h-24 text-center text-slate-500">
                  {emptyState}
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </UITable>
      </div>
    </div>
  );
}
