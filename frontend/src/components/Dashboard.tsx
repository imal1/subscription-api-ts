"use client";

import { Button } from "@/components/ui/button";
import ThemeToggle from "@/components/ThemeToggle";
import { apiService, type ApiStatus, type UpdateResult } from "@/lib/api";
import { Icon } from "@iconify/react";
import { useCallback, useEffect, useState, useTransition } from "react";
import ConvertModal from "./ConvertModal";

/* ── Status badge ── */
interface StatusBadgeProps {
  label: string;
  status: "success" | "warning" | "danger" | "info";
}

const StatusBadge = ({ label, status }: StatusBadgeProps) => {
  const variant = {
    success: "stats-badge stats-badge-success",
    warning: "stats-badge stats-badge-warning",
    danger: "stats-badge stats-badge-danger",
    info: "stats-badge stats-badge-info",
  }[status];

  return <span className={variant}>
    <span className={`live-dot ${status === "success" || status === "info" ? "live-dot-active" : "live-dot-inactive"}`} />
    {label}
  </span>;
};

/* ── Stat card ── */
interface StatCardProps {
  label: string;
  value: string | number;
  sub?: string;
  icon: string;
  status: "success" | "warning" | "danger" | "info";
}

const StatCard = ({ label, value, sub, icon, status }: StatCardProps) => {
  const borderMap = {
    success: "border-l-[var(--fern)]",
    warning: "border-l-[var(--marigold)]",
    danger: "border-l-[var(--terracotta)]",
    info: "border-l-[var(--info)]",
  };

  return (
    <div className={`garden-card border-l-[3px] p-5 ${borderMap[status]}`}>
      <div className="flex items-start justify-between">
        <div className="flex-1 min-w-0">
          <p className="text-xs font-semibold uppercase tracking-widest text-[var(--muted-foreground)] mb-2">
            {label}
          </p>
          <p className="text-2xl font-bold text-[var(--foreground)] truncate" style={{ fontFamily: "var(--font-display)" }}>
            {value}
          </p>
          {sub && (
            <p className="text-xs text-[var(--muted-foreground)] mt-1.5 truncate">
              {sub}
            </p>
          )}
        </div>
        <div className="flex-shrink-0 w-9 h-9 rounded-lg flex items-center justify-center" style={{ backgroundColor: "var(--muted)" }}>
          <Icon icon={icon} className="w-[18px] h-[18px] text-[var(--foreground)]" />
        </div>
      </div>
    </div>
  );
};

/* ── Info row ── */
const InfoRow = ({ label, children }: { label: string; children: React.ReactNode }) => (
  <div className="flex items-center justify-between py-2.5">
    <span className="text-sm text-[var(--muted-foreground)]">{label}</span>
    <span className="text-sm font-medium text-[var(--foreground)]">{children}</span>
  </div>
);

/* ── Section heading ── */
const SectionHeading = ({ icon, title, desc }: { icon: string; title: string; desc: string }) => (
  <div className="section-rule">
    <div className="flex items-center gap-2.5">
      <Icon icon={icon} className="w-[18px] h-[18px] text-[var(--fern)]" />
      <h2 className="text-base font-semibold text-[var(--foreground)]" style={{ fontFamily: "var(--font-display)" }}>
        {title}
      </h2>
    </div>
    <p className="text-xs text-[var(--muted-foreground)] mt-1">{desc}</p>
  </div>
);

/* ── API table method badge ── */
const MethodBadge = ({ method }: { method: string }) => (
  <span className={`inline-flex items-center rounded-md px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wider ${
    method === "GET"
      ? "bg-[var(--success-bg)] text-[var(--fern)] border border-[var(--success-border)]"
      : "bg-[var(--warning-bg)] text-[var(--warning)] border border-[var(--warning-border)]"
  }`}>
    {method}
  </span>
);

/* ── Dashboard ── */
interface DashboardProps {
  initialStatus?: ApiStatus | null;
  initialError?: string | null;
}

const Dashboard = ({ initialStatus = null, initialError = null }: DashboardProps) => {
  const [status, setStatus] = useState<ApiStatus | null>(initialStatus);
  const [loading, setLoading] = useState(false);
  const [updating, setUpdating] = useState(false);
  const [error, setError] = useState<string | null>(initialError);
  const [updateResult, setUpdateResult] = useState<UpdateResult | null>(null);
  const [convertModalOpen, setConvertModalOpen] = useState(false);
  const [, startTransition] = useTransition();

  const fetchStatus = useCallback(async () => {
    try {
      setError(null);
      const statusData = await apiService.getStatus();
      setStatus(statusData);
    } catch (err) {
      setError(err instanceof Error ? err.message : "获取状态失败");
    } finally {
      setLoading(false);
    }
  }, []);

  const handleUpdate = useCallback(async () => {
    startTransition(() => {
      setUpdating(true);
      setUpdateResult(null);
    });

    try {
      const result = await apiService.updateSubscription();
      startTransition(() => setUpdateResult(result));
      await fetchStatus();
    } catch (err) {
      startTransition(() =>
        setError(err instanceof Error ? err.message : "更新失败")
      );
    } finally {
      startTransition(() => setUpdating(false));
    }
  }, [fetchStatus]);

  const handleDownload = useCallback((filename: string) => {
    window.open(apiService.getDownloadUrl(filename), "_blank");
  }, []);

  useEffect(() => {
    fetchStatus();
    const timer = setInterval(fetchStatus, 30000);
    return () => clearInterval(timer);
  }, [fetchStatus]);

  const formatUptime = (s: number) => {
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    return `${h}h ${m}m`;
  };

  const formatSize = (b: number) => {
    if (!b) return "-";
    const i = Math.floor(Math.log(b) / Math.log(1024));
    return `${(b / Math.pow(1024, i)).toFixed(1)} ${["B", "KB", "MB", "GB"][i]}`;
  };

  const formatDate = (d: string) => new Date(d).toLocaleString("zh-CN");

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-[var(--background)]">
        <div className="flex items-center gap-3 animate-breathe">
          <Icon icon="ph:plant" className="w-5 h-5 text-[var(--fern)]" />
          <span className="text-sm text-[var(--muted-foreground)]">加载中…</span>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[var(--background)]">
      {/* ── Header ── */}
      <header className="border-b border-[var(--border)] bg-[var(--card)]">
        <div className="max-w-6xl mx-auto px-6 py-6">
          <div className="flex items-start justify-between">
            <div>
              <div className="flex items-center gap-2 mb-1">
                <Icon
                  icon="ph:plant"
                  className="w-7 h-7 text-[var(--fern)]"
                  style={{ animation: "sway 4s ease-in-out infinite" }}
                />
                <h1 className="text-2xl font-bold text-[var(--foreground)]" style={{ fontFamily: "var(--font-display)" }}>
                  Subscription Garden
                </h1>
              </div>
              <p className="text-sm text-[var(--muted-foreground)] mt-1">
                订阅转换服务控制面板 · 实时 SSR
              </p>
            </div>
            <ThemeToggle />
          </div>
          <div className="mt-4 h-[3px] bg-[var(--fern)] rounded-full w-12 origin-left animate-grow-line" />
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-6 py-8 space-y-8">
        {/* ── Error ── */}
        {error && (
          <div className="garden-alert garden-alert-danger">
            <Icon icon="ph:warning-circle-bold" className="w-5 h-5 flex-shrink-0 mt-0.5" />
            <div>
              <p className="text-sm font-semibold">出错了</p>
              <p className="text-sm mt-0.5 opacity-90">{error}</p>
            </div>
          </div>
        )}

        {/* ── Update result ── */}
        {updateResult && (
          <div className={`garden-alert ${updateResult.success ? "garden-alert-success" : "garden-alert-danger"}`}>
            <Icon
              icon={updateResult.success ? "ph:check-circle-bold" : "ph:x-circle-bold"}
              className="w-5 h-5 flex-shrink-0 mt-0.5"
            />
            <div>
              <p className="text-sm font-semibold">{updateResult.success ? "更新完成" : "更新失败"}</p>
              <p className="text-sm mt-0.5 opacity-90">{updateResult.message}</p>
              {updateResult.errors && updateResult.errors.length > 0 && (
                <ul className="mt-2 space-y-0.5">
                  {updateResult.errors.map((e, i) => (
                    <li key={i} className="text-xs opacity-80">· {e}</li>
                  ))}
                </ul>
              )}
            </div>
          </div>
        )}

        {/* ── Status overview ── */}
        <section>
          <SectionHeading
            icon="ph:gauge"
            title="状态概览"
            desc="服务与订阅文件的实时状态"
          />
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 stagger-slide-up">
            <StatCard
              label="订阅文件"
              value={status?.subscriptionExists ? "已生成" : "未生成"}
              sub={status?.subscriptionExists && status?.subscriptionLastUpdated
                ? formatDate(status.subscriptionLastUpdated) : "尚未更新"}
              icon="ph:file-text"
              status={status?.subscriptionExists ? "success" : "danger"}
            />
            <StatCard
              label="Clash 配置"
              value={status?.clashExists ? "已生成" : "未生成"}
              sub={status?.clashExists && status?.clashLastUpdated
                ? formatDate(status.clashLastUpdated) : "尚未更新"}
              icon="ph:shield-check"
              status={status?.clashExists ? "success" : "danger"}
            />
            <StatCard
              label="节点数量"
              value={status?.nodesCount ?? 0}
              sub="可用节点"
              icon="ph:tree-structure"
              status={status?.nodesCount && status.nodesCount > 0 ? "success" : "warning"}
            />
            <StatCard
              label="运行时间"
              value={status ? formatUptime(status.uptime) : "-"}
              sub="服务实例"
              icon="ph:clock"
              status="info"
            />
          </div>
        </section>

        {/* ── Services + Files ── */}
        <section>
          <SectionHeading
            icon="ph:hard-drives"
            title="服务与文件"
            desc="依赖服务及生成文件详情"
          />
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 stagger-slide-up">
            {/* Services */}
            <div className="garden-card p-5">
              <h3 className="text-xs font-semibold uppercase tracking-widest text-[var(--muted-foreground)] mb-4">
                核心服务
              </h3>
              <div className="space-y-1 divide-y divide-[var(--border)]">
                <InfoRow label="Mihomo">
                  <StatusBadge
                    label={status?.mihomoAvailable ? "可用" : "不可用"}
                    status={status?.mihomoAvailable ? "success" : "danger"}
                  />
                  {status?.mihomoVersion && (
                    <span className="ml-2 text-xs text-[var(--muted-foreground)]">
                      v{status.mihomoVersion}
                    </span>
                  )}
                </InfoRow>
                <InfoRow label="Sing-box">
                  <StatusBadge
                    label={status?.singBoxAccessible ? "可访问" : "不可访问"}
                    status={status?.singBoxAccessible ? "success" : "danger"}
                  />
                </InfoRow>
                <InfoRow label="API 版本">
                  <span className="font-mono text-xs text-[var(--muted-foreground)]">
                    {status?.version ?? "-"}
                  </span>
                </InfoRow>
              </div>
            </div>

            {/* File info */}
            <div className="garden-card p-5">
              <h3 className="text-xs font-semibold uppercase tracking-widest text-[var(--muted-foreground)] mb-4">
                文件信息
              </h3>
              <div className="space-y-1 divide-y divide-[var(--border)]">
                <InfoRow label="subscription.txt">
                  {status?.subscriptionSize ? formatSize(status.subscriptionSize) : "-"}
                </InfoRow>
                <InfoRow label="clash.yaml">
                  {status?.clashSize ? formatSize(status.clashSize) : "-"}
                </InfoRow>
                <InfoRow label="raw.txt">
                  {status?.rawExists ? (
                    <StatusBadge label="已生成" status="success" />
                  ) : (
                    <StatusBadge label="未生成" status="warning" />
                  )}
                </InfoRow>
              </div>
            </div>
          </div>
        </section>

        {/* ── Quick actions ── */}
        <section>
          <SectionHeading
            icon="ph:lightning"
            title="快速操作"
            desc="常用功能的快捷入口"
          />
          <div className="garden-card p-5">
            <div className="flex flex-wrap gap-2.5">
              <Button
                onClick={handleUpdate}
                disabled={updating}
                className="gap-2 h-10 px-4 text-sm font-medium rounded-lg"
                style={{
                  backgroundColor: "var(--primary)",
                  color: "var(--primary-foreground)",
                  border: "none",
                }}
              >
                <Icon
                  icon={updating ? "ph:spinner" : "ph:arrows-clockwise"}
                  className={`w-4 h-4 ${updating ? "animate-spin" : ""}`}
                />
                {updating ? "更新中..." : "更新订阅"}
              </Button>

              <Button
                variant="outline"
                onClick={() => handleDownload("subscription.txt")}
                className="gap-2 h-10 px-4 text-sm font-medium rounded-lg"
              >
                <Icon icon="ph:download-simple" className="w-4 h-4" />
                订阅文件
              </Button>

              <Button
                variant="outline"
                onClick={() => handleDownload("clash.yaml")}
                className="gap-2 h-10 px-4 text-sm font-medium rounded-lg"
              >
                <Icon icon="ph:download-simple" className="w-4 h-4" />
                Clash 配置
              </Button>

              <Button
                variant="outline"
                onClick={() => handleDownload("raw.txt")}
                className="gap-2 h-10 px-4 text-sm font-medium rounded-lg"
              >
                <Icon icon="ph:download-simple" className="w-4 h-4" />
                原始链接
              </Button>

              <Button
                variant="outline"
                onClick={fetchStatus}
                className="gap-2 h-10 px-4 text-sm font-medium rounded-lg"
              >
                <Icon icon="ph:arrows-clockwise" className="w-4 h-4" />
                刷新状态
              </Button>

              <Button
                variant="outline"
                onClick={() => setConvertModalOpen(true)}
                className="gap-2 h-10 px-4 text-sm font-medium rounded-lg"
              >
                <Icon icon="ph:code" className="w-4 h-4" />
                转换订阅
              </Button>
            </div>
          </div>
        </section>

        {/* ── API docs ── */}
        {status && (
          <section>
            <SectionHeading
              icon="ph:globe"
              title="API 端点"
              desc="可用接口与快速测试"
            />
            <div className="garden-card overflow-hidden">
              <table className="garden-table">
                <thead>
                  <tr>
                    <th>方法</th>
                    <th>端点</th>
                    <th>描述</th>
                    <th className="text-right">操作</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td><MethodBadge method="GET" /></td>
                    <td><code className="text-xs font-mono text-[var(--foreground)]">/api/status</code></td>
                    <td className="text-[var(--muted-foreground)]">获取服务状态</td>
                    <td className="text-right">
                      <Button variant="outline" size="sm" className="rounded-lg text-xs h-8" onClick={() => window.open("/api/status", "_blank")}>
                        测试
                      </Button>
                    </td>
                  </tr>
                  <tr>
                    <td><MethodBadge method="GET" /></td>
                    <td><code className="text-xs font-mono text-[var(--foreground)]">/api/update</code></td>
                    <td className="text-[var(--muted-foreground)]">更新订阅</td>
                    <td className="text-right">
                      <Button variant="outline" size="sm" className="rounded-lg text-xs h-8" onClick={handleUpdate}>
                        执行
                      </Button>
                    </td>
                  </tr>
                  <tr>
                    <td><MethodBadge method="GET" /></td>
                    <td><code className="text-xs font-mono text-[var(--foreground)]">/subscription.txt</code></td>
                    <td className="text-[var(--muted-foreground)]">下载订阅文件</td>
                    <td className="text-right">
                      <Button variant="outline" size="sm" className="rounded-lg text-xs h-8" onClick={() => handleDownload("subscription.txt")}>
                        下载
                      </Button>
                    </td>
                  </tr>
                  <tr>
                    <td><MethodBadge method="GET" /></td>
                    <td><code className="text-xs font-mono text-[var(--foreground)]">/clash.yaml</code></td>
                    <td className="text-[var(--muted-foreground)]">下载 Clash 配置</td>
                    <td className="text-right">
                      <Button variant="outline" size="sm" className="rounded-lg text-xs h-8" onClick={() => handleDownload("clash.yaml")}>
                        下载
                      </Button>
                    </td>
                  </tr>
                  <tr>
                    <td><MethodBadge method="GET" /></td>
                    <td><code className="text-xs font-mono text-[var(--foreground)]">/raw.txt</code></td>
                    <td className="text-[var(--muted-foreground)]">下载原始链接</td>
                    <td className="text-right">
                      <Button variant="outline" size="sm" className="rounded-lg text-xs h-8" onClick={() => handleDownload("raw.txt")}>
                        下载
                      </Button>
                    </td>
                  </tr>
                  <tr>
                    <td><MethodBadge method="GET" /></td>
                    <td><code className="text-xs font-mono text-[var(--foreground)]">/health</code></td>
                    <td className="text-[var(--muted-foreground)]">健康检查</td>
                    <td className="text-right">
                      <Button variant="outline" size="sm" className="rounded-lg text-xs h-8" onClick={() => window.open("/health", "_blank")}>
                        测试
                      </Button>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>
        )}

        {/* ── Footer ── */}
        <footer className="text-center pt-8 pb-12">
          <p className="text-xs text-[var(--muted-foreground)]">
            Subscription Garden · Next.js SSR · Botanical Garden Theme
          </p>
        </footer>
      </main>

      {/* Convert modal */}
      <ConvertModal
        isOpen={convertModalOpen}
        onClose={() => setConvertModalOpen(false)}
      />
    </div>
  );
};

export default Dashboard;
