import { flexRender } from "@tanstack/react-table";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Pagination,
  PaginationContent,
  PaginationItem,
  PaginationLink,
  PaginationNext,
  PaginationPrevious,
} from "@/components/ui/pagination";
import { ChevronLeftIcon, ChevronRightIcon } from "@radix-ui/react-icons";
import { ArrowLeftToLine, ArrowRightToLine } from "lucide-react";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

// This component expects all props returned from `useTable()`
export function DataTable({ ...tableProps }: any) {
  const {
    getHeaderGroups,
    getRowModel,
    refineCore: {
      tableQuery: { data: tableData },
    },
    getState,
    setPageIndex,
    getCanPreviousPage,
    getPageCount,
    getCanNextPage,
    nextPage,
    previousPage,
    setPageSize,
  } = tableProps;

  return (
    <div style={{ maxWidth: "100%", overflowY: "auto" }}>
      <Table>
        <TableHeader>
          {getHeaderGroups().map((headerGroup: any) => (
            <TableRow key={headerGroup.id}>
              {headerGroup.headers.map((header: any) => (
                <TableHead key={header.id}>
                  {!header.isPlaceholder &&
                    flexRender(
                      header.column.columnDef.header,
                      header.getContext()
                    )}
                </TableHead>
              ))}
            </TableRow>
          ))}
        </TableHeader>
        <TableBody>
          {getRowModel().rows.map((row: any) => (
            <TableRow key={row.id}>
              {row.getVisibleCells().map((cell: any) => (
                <TableCell key={cell.id}>
                  {flexRender(cell.column.columnDef.cell, cell.getContext())}
                </TableCell>
              ))}
            </TableRow>
          ))}
        </TableBody>
      </Table>

      <Pagination>
        <PaginationContent>
          <PaginationItem>
            <PaginationLink onClick={() => setPageIndex(0)} disabled={!getCanPreviousPage()}>
              <ArrowLeftToLine className="h-4 w-4" />
            </PaginationLink>
          </PaginationItem>
          <PaginationItem>
            <PaginationPrevious onClick={() => previousPage()} disabled={!getCanPreviousPage()}>
              <ChevronLeftIcon className="h-4 w-4" />
            </PaginationPrevious>
          </PaginationItem>
          <PaginationItem>
            <PaginationNext onClick={() => nextPage()} disabled={!getCanNextPage()}>
              <ChevronRightIcon className="h-4 w-4" />
            </PaginationNext>
          </PaginationItem>
          <PaginationItem>
            <PaginationLink onClick={() => setPageIndex(getPageCount() - 1)} disabled={!getCanNextPage()}>
              <ArrowRightToLine className="h-4 w-4" />
            </PaginationLink>
          </PaginationItem>
          <div className="flex items-center space-x-6 lg:space-x-8 ml-auto">
            <div className="flex w-[100px] items-center justify-center text-sm font-medium">
              Page {getState().pagination.pageIndex + 1} of {getPageCount()}
            </div>
            <div className="flex items-center space-x-2">
              <p className="text-sm font-medium">Rows per page</p>
              <Select
                value={`${getState().pagination.pageSize}`}
                onValueChange={(value: any) => setPageSize(Number(value))}
              >
                <SelectTrigger className="h-8 w-[70px]">
                  <SelectValue placeholder={getState().pagination.pageSize} />
                </SelectTrigger>
                <SelectContent side="top">
                  {[5, 10, 20, 30, 40, 50].map((pageSize) => (
                    <SelectItem key={pageSize} value={`${pageSize}`}>
                      {pageSize}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        </PaginationContent>
      </Pagination>
    </div>
  );
} 