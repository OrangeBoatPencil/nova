import * as React from "react";
import { cn } from "@/lib/utils";

export const Pagination = ({ className, ...props }: React.HTMLAttributes<HTMLElement>) => (
  <nav
    role="navigation"
    aria-label="pagination"
    className={cn("flex w-full", className)}
    {...props}
  />
);

export const PaginationContent = React.forwardRef<HTMLUListElement, React.HTMLAttributes<HTMLUListElement>>(
  ({ className, ...props }, ref) => (
    <ul ref={ref} className={cn("flex flex-1 items-center gap-4", className)} {...props} />
  )
);
PaginationContent.displayName = "PaginationContent";

export const PaginationItem = React.forwardRef<HTMLLIElement, React.HTMLAttributes<HTMLLIElement>>(
  ({ className, ...props }, ref) => (
    <li ref={ref} className={cn("", className)} {...props} />
  )
);
PaginationItem.displayName = "PaginationItem";

export const PaginationLink = React.forwardRef<HTMLButtonElement, React.ButtonHTMLAttributes<HTMLButtonElement>>(
  ({ className, ...props }, ref) => (
    <button
      ref={ref}
      className={cn(
        "flex h-8 w-8 items-center justify-center rounded border bg-background text-sm transition-colors hover:bg-muted disabled:opacity-50",
        className
      )}
      {...props}
    />
  )
);
PaginationLink.displayName = "PaginationLink";

export const PaginationPrevious = PaginationLink;
export const PaginationNext = PaginationLink; 