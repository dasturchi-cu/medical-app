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
  return (
    <div className="surface-card overflow-hidden border border-slate-100">
      <div className="w-full overflow-x-auto">
      <UITable className="min-w-[760px]">
        <TableHeader>
          <TableRow className="bg-slate-50/70">
            {columns.map((column) => (
              <TableHead key={String(column.key)} className="h-11 px-4 text-xs font-semibold uppercase tracking-wide text-slate-500">
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
                  <TableCell key={String(column.key)} className="px-4 py-3 text-sm text-slate-700">
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
                <div className="mx-auto max-w-xs">
                  <p className="font-medium text-slate-700">{emptyText}</p>
                  <p className="text-xs text-slate-400">Yangi ma&apos;lumot qo&apos;shing yoki filtrni o&apos;zgartiring.</p>
                </div>
              </TableCell>
            </TableRow>
          )}
        </TableBody>
      </UITable>
      </div>
    </div>
  );
}
