import * as React from "react";
import { cn } from "@/lib/utils";

type AnyProps = React.HTMLAttributes<HTMLDivElement> & Record<string, any>;

export const Select = ({ className, ...props }: AnyProps) => (
  <div className={cn("relative", className)} {...props} />
);

export const SelectTrigger = React.forwardRef<HTMLButtonElement, React.ButtonHTMLAttributes<HTMLButtonElement> & Record<string, any>>(
  ({ className, ...props }, ref) => (
    <button ref={ref} className={cn("flex items-center justify-between border rounded px-2 h-10", className)} {...props} />
  )
);
SelectTrigger.displayName = "SelectTrigger";

export const SelectValue = ({ children }: { children: React.ReactNode }) => <span>{children}</span>;

export const SelectContent = ({ className, ...props }: AnyProps) => (
  <div className={cn("absolute z-20 mt-1 w-full border rounded bg-background", className)} {...props} />
);

export const SelectItem = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement> & Record<string, any>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn("px-2 py-1 cursor-pointer hover:bg-muted", className)} {...props} />
  )
);
SelectItem.displayName = "SelectItem"; 