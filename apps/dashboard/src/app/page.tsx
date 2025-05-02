import { AppLayout } from "@/components/layout/app-layout";
import { DashboardPage } from "@/components/dashboard/dashboard-page";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { MembersList } from "@/components/members/members-list";

export default function Home() {
  return (
    <AppLayout>
      <Tabs defaultValue="dashboard" className="w-full">
        <TabsList className="mb-4">
          <TabsTrigger value="dashboard">Dashboard</TabsTrigger>
          <TabsTrigger value="members">Members</TabsTrigger>
        </TabsList>
        <TabsContent value="dashboard">
          <DashboardPage />
        </TabsContent>
        <TabsContent value="members">
          <MembersList />
        </TabsContent>
      </Tabs>
    </AppLayout>
  );
}
