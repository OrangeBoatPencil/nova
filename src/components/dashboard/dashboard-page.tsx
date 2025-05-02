import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Activity, CreditCard, DollarSign, Users } from "lucide-react";

export const DashboardPage = () => {
  return (
    <div className="flex flex-col space-y-6">
      <div className="flex flex-col space-y-2">
        <h2 className="text-3xl font-bold tracking-tight">Dashboard</h2>
        <p className="text-muted-foreground">
          Welcome to your dashboard. View your stats and manage your resources.
        </p>
      </div>
      <Tabs defaultValue="overview" className="space-y-4">
        <TabsList>
          <TabsTrigger value="overview">Overview</TabsTrigger>
          <TabsTrigger value="analytics">Analytics</TabsTrigger>
          <TabsTrigger value="reports">Reports</TabsTrigger>
        </TabsList>
        <TabsContent value="overview" className="space-y-4">
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">
                  Total Revenue
                </CardTitle>
                <DollarSign className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">$45,231.89</div>
                <p className="text-xs text-muted-foreground">
                  +20.1% from last month
                </p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">
                  Subscriptions
                </CardTitle>
                <Users className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">+2350</div>
                <p className="text-xs text-muted-foreground">
                  +180.1% from last month
                </p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Sales</CardTitle>
                <CreditCard className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">+12,234</div>
                <p className="text-xs text-muted-foreground">
                  +19% from last month
                </p>
              </CardContent>
            </Card>
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Active Now</CardTitle>
                <Activity className="h-4 w-4 text-muted-foreground" />
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">+573</div>
                <p className="text-xs text-muted-foreground">
                  +201 since last hour
                </p>
              </CardContent>
            </Card>
          </div>
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-7">
            <Card className="col-span-4">
              <CardHeader>
                <CardTitle>Recent Activity</CardTitle>
                <CardDescription>
                  There were 2,452 transactions this month.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="h-[200px] border-b border-dashed text-center flex items-center justify-center">
                  <span className="text-muted-foreground">Chart visualization would go here</span>
                </div>
              </CardContent>
            </Card>
            <Card className="col-span-3">
              <CardHeader>
                <CardTitle>Recent Sales</CardTitle>
                <CardDescription>
                  You made 265 sales this month.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-8">
                  {[
                    {
                      name: "Jane Cooper",
                      email: "jane@example.com",
                      amount: "+$892.00",
                    },
                    {
                      name: "Wade Warren",
                      email: "wade@example.com",
                      amount: "+$424.00",
                    },
                    {
                      name: "Esther Howard",
                      email: "esther@example.com",
                      amount: "+$1,200.00",
                    },
                  ].map((item, i) => (
                    <div key={i} className="flex items-center">
                      <div className="rounded-full h-9 w-9 bg-primary/10 flex items-center justify-center mr-3">
                        <span className="font-medium text-primary">
                          {item.name.charAt(0)}
                        </span>
                      </div>
                      <div className="space-y-1">
                        <p className="text-sm font-medium leading-none">
                          {item.name}
                        </p>
                        <p className="text-sm text-muted-foreground">
                          {item.email}
                        </p>
                      </div>
                      <div className="ml-auto font-medium">{item.amount}</div>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>
        <TabsContent value="analytics" className="h-[400px] border rounded-md flex items-center justify-center">
          <p className="text-muted-foreground">Analytics content would go here</p>
        </TabsContent>
        <TabsContent value="reports" className="h-[400px] border rounded-md flex items-center justify-center">
          <p className="text-muted-foreground">Reports content would go here</p>
        </TabsContent>
      </Tabs>
    </div>
  );
}; 