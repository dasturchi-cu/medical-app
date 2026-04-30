import { DataTable, type DataColumn } from "@/components/data-table";

type Column<T> = DataColumn<T>;

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
  return <DataTable columns={columns} data={data} emptyTitle={emptyText} />;
}
