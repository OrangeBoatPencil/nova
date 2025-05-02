import { PropsWithChildren } from "react";
import { LayoutProps } from "@refinedev/core";
import { User, Settings, Users, Home, Package, CreditCard } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import Link from "next/link";

export const AppLayout: React.FC<PropsWithChildren<LayoutProps>> = ({
  children,
}) => {
  return (
    <div className="flex min-h-screen flex-col bg-background">
      <header className="sticky top-0 z-40 w-full border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="container flex h-14 items-center">
          <div className="mr-4 flex">
            <Link className="mr-6 flex items-center space-x-2" href="/">
              <span className="hidden font-bold sm:inline-block">Nova Dashboard</span>
            </Link>
          </div>
          <div className="flex flex-1 items-center justify-end space-x-4">
            <nav className="flex items-center space-x-2">
              <Button variant="ghost" size="icon">
                <User className="h-4 w-4" />
                <span className="sr-only">Toggle user menu</span>
              </Button>
              <Button variant="ghost" size="icon">
                <Settings className="h-4 w-4" />
                <span className="sr-only">Toggle settings</span>
              </Button>
            </nav>
          </div>
        </div>
      </header>
      <div className="flex flex-1">
        <aside className="hidden w-64 border-r md:block">
          <div className="py-4">
            <div className="px-3 py-2">
              <div className="space-y-1">
                <Button variant="ghost" className="w-full justify-start" asChild>
                  <Link href="/">
                    <Home className="mr-2 h-4 w-4" /> Dashboard
                  </Link>
                </Button>
                <Button variant="ghost" className="w-full justify-start" asChild>
                  <Link href="/products">
                    <Package className="mr-2 h-4 w-4" /> Products
                  </Link>
                </Button>
                <Button variant="ghost" className="w-full justify-start" asChild>
                  <Link href="/members">
                    <Users className="mr-2 h-4 w-4" /> Members
                  </Link>
                </Button>
                <Button variant="ghost" className="w-full justify-start" asChild>
                  <Link href="/billing">
                    <CreditCard className="mr-2 h-4 w-4" /> Billing
                  </Link>
                </Button>
                <Button variant="ghost" className="w-full justify-start" asChild>
                  <Link href="/settings">
                    <Settings className="mr-2 h-4 w-4" /> Settings
                  </Link>
                </Button>
              </div>
            </div>
          </div>
        </aside>
        <main className="flex-1 p-6 md:p-8">
          <Card className="p-6">
            {children}
          </Card>
        </main>
      </div>
      <footer className="py-6 border-t">
        <div className="container flex flex-col items-center justify-between gap-4 md:flex-row">
          <p className="text-center text-sm leading-loose text-muted-foreground md:text-left">
            © 2025 Nova Dashboard. All rights reserved.
          </p>
        </div>
      </footer>
    </div>
  );
}; 