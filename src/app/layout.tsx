"use client";
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import { Refine } from "@refinedev/core";
import { RefineKbar, RefineKbarProvider } from "@refinedev/kbar";
import routerProvider from "@refinedev/nextjs-router/app";
import { authProvider } from "@/providers/auth-provider";
import { supabaseProvider } from "@/providers/supabase-provider";
import { accessControlProvider } from "@/providers/access-control-provider";
import { liveProvider } from "@refinedev/supabase";
import { createBrowserSupabaseClient } from "@/utils/supabase/client";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Nova Dashboard",
  description: "Member dashboard with Supabase and Refine",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <RefineKbarProvider>
          <Refine
            authProvider={authProvider}
            dataProvider={supabaseProvider()}
            liveProvider={liveProvider(createBrowserSupabaseClient())}
            routerProvider={routerProvider}
            accessControlProvider={accessControlProvider}
            resources={[
              {
                name: "dashboard",
                list: "/dashboard",
                meta: {
                  label: "Dashboard"
                },
              },
              {
                name: "profiles",
                list: "/account",
                meta: {
                  label: "My Profile"
                },
              },
              {
                name: "teams",
                list: "/teams",
                show: "/teams/:id",
                create: "/teams/create",
                edit: "/teams/:id/edit",
                meta: {
                  label: "Teams",
                  canDelete: true,
                },
              },
              {
                name: "channels",
                list: "/channels",
                show: "/channels/:id",
                create: "/channels/create",
                edit: "/channels/:id/edit",
                meta: {
                  label: "Channels",
                  canDelete: true,
                },
              },
            ]}
            options={{
              syncWithLocation: true,
              warnWhenUnsavedChanges: true,
            }}
          >
            {children}
            <RefineKbar />
          </Refine>
        </RefineKbarProvider>
      </body>
    </html>
  );
}
