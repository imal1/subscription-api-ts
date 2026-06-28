"use client";

import { useState } from 'react';
import { Icon } from '@iconify/react';

interface AddNodeFormProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (data: NodeFormData) => void;
}

export interface NodeFormData {
  name: string;
  host: string;
  port: number;
  kernel: 'sing-box' | 'xray' | 'v2ray';
  location: string;
  sshUser: string;
  sshPort: number;
  sshKey: string;
  sshPassword: string;
}

export function AddNodeForm({ isOpen, onClose, onSubmit }: AddNodeFormProps) {
  const [form, setForm] = useState<NodeFormData>({
    name: '', host: '', port: 443,
    kernel: 'sing-box', location: '',
    sshUser: 'root', sshPort: 22, sshKey: '', sshPassword: '',
  });
  const [submitting, setSubmitting] = useState(false);

  if (!isOpen) return null;

  const update = (field: keyof NodeFormData, value: string | number) => {
    setForm(prev => ({ ...prev, [field]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    try {
      onSubmit(form);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50" onClick={onClose}>
      <div className="garden-card p-6 max-w-lg w-full mx-4 max-h-[90vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold" style={{ fontFamily: 'var(--font-display)' }}>
            添加节点
          </h3>
          <button onClick={onClose} className="p-1 rounded-md hover:bg-[var(--muted)]">
            <Icon icon="ph:x-bold" className="w-5 h-5" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {/* Node info */}
          <div>
            <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>节点名称</label>
            <input type="text" value={form.name} onChange={e => update('name', e.target.value)}
              className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
              style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }}
              placeholder="如: 新加坡" required />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>主机地址</label>
              <input type="text" value={form.host} onChange={e => update('host', e.target.value)}
                className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
                style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }}
                placeholder="sg.example.com" required />
            </div>
            <div>
              <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>端口</label>
              <input type="number" value={form.port} onChange={e => update('port', parseInt(e.target.value) || 443)}
                className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
                style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }} />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>内核类型</label>
              <select value={form.kernel} onChange={e => update('kernel', e.target.value)}
                className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
                style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }}>
                <option value="sing-box">Sing-Box</option>
                <option value="xray">Xray</option>
                <option value="v2ray">V2Ray</option>
              </select>
            </div>
            <div>
              <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>地域标签</label>
              <input type="text" value={form.location} onChange={e => update('location', e.target.value)}
                className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
                style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }}
                placeholder="如: 东京" required />
            </div>
          </div>

          <hr style={{ borderColor: 'var(--border)' }} />

          {/* SSH info */}
          <h4 className="text-sm font-semibold" style={{ color: 'var(--muted-foreground)' }}>SSH 连接信息</h4>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>SSH 用户</label>
              <input type="text" value={form.sshUser} onChange={e => update('sshUser', e.target.value)}
                className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
                style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }} />
            </div>
            <div>
              <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>SSH 端口</label>
              <input type="number" value={form.sshPort} onChange={e => update('sshPort', parseInt(e.target.value) || 22)}
                className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
                style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }} />
            </div>
          </div>

          <div>
            <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>
              SSH 私钥 <span className="text-xs opacity-70">(粘贴内容或路径)</span>
            </label>
            <textarea value={form.sshKey} onChange={e => update('sshKey', e.target.value)}
              rows={3}
              className="w-full mt-1 px-3 py-2 rounded-lg border text-sm font-mono"
              style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }}
              placeholder="-----BEGIN OPENSSH PRIVATE KEY-----" />
          </div>

          <div>
            <label className="text-sm font-medium" style={{ color: 'var(--muted-foreground)' }}>
              SSH 密码 <span className="text-xs opacity-70">(密钥为空时使用密码认证)</span>
            </label>
            <input type="password" value={form.sshPassword} onChange={e => update('sshPassword', e.target.value)}
              className="w-full mt-1 px-3 py-2 rounded-lg border text-sm"
              style={{ borderColor: 'var(--border)', backgroundColor: 'var(--background)', color: 'var(--foreground)' }}
              placeholder="SSH 登录密码" />
          </div>

          <div className="flex gap-3 pt-2">
            <button type="submit" disabled={submitting}
              className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-all active:scale-[0.98]"
              style={{ backgroundColor: 'var(--primary)', color: 'var(--primary-foreground)', opacity: submitting ? 0.6 : 1 }}>
              <Icon icon={submitting ? 'ph:spinner-bold' : 'ph:plus-circle-bold'} className={`w-4 h-4 ${submitting ? 'animate-spin' : ''}`} />
              添加节点
            </button>
            <button type="button" onClick={onClose}
              className="px-4 py-2 rounded-lg text-sm font-medium transition-all"
              style={{ backgroundColor: 'var(--secondary)', color: 'var(--secondary-foreground)' }}>
              取消
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
