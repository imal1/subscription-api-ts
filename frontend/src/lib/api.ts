const API_BASE_URL =
  process.env.NODE_ENV === "production"
    ? "" // 在生产环境中使用相对路径
    : "http://localhost:3000"; // 开发环境中使用完整URL

export interface ApiStatus {
  subscriptionExists: boolean;
  clashExists: boolean;
  rawExists: boolean;
  mihomoAvailable: boolean;
  singBoxAccessible: boolean;
  subscriptionLastUpdated?: string;
  subscriptionSize?: number;
  clashLastUpdated?: string;
  clashSize?: number;
  nodesCount?: number;
  uptime: number;
  version: string;
  mihomoVersion?: string;
}

export interface UpdateResult {
  success: boolean;
  message: string;
  timestamp: string;
  nodesCount: number;
  clashGenerated: boolean;
  backupCreated: string;
  warnings?: string[];
  errors?: string[];
}

export interface ApiResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
  timestamp: string;
}

export interface ConvertResult {
  success: boolean;
  data?: {
    clashConfig: string;
    originalLength: number;
    configLength: number;
  };
  error?: string;
  message?: string;
  timestamp: string;
}

class ApiService {
  private async request<T>(url: string, options?: RequestInit): Promise<T> {
    try {
      const response = await fetch(`${API_BASE_URL}${url}`, {
        headers: {
          "Content-Type": "application/json",
          ...options?.headers,
        },
        ...options,
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      console.error(`API请求失败: ${url}`, error);
      throw error;
    }
  }

  // 获取API状态
  async getStatus(): Promise<ApiStatus> {
    return this.request<ApiStatus>("/api/status");
  }

  // 更新订阅
  async updateSubscription(): Promise<UpdateResult> {
    return this.request<UpdateResult>("/api/update");
  }

  // 获取健康状态
  async getHealth(): Promise<{ status: string; timestamp: string }> {
    return this.request("/health");
  }

  // 获取配置列表
  async getConfigs(): Promise<string[]> {
    const response = await this.request<ApiResponse<string[]>>("/api/configs");
    return response.data || [];
  }

  // 诊断Clash生成
  async diagnoseClash(): Promise<any> {
    return this.request("/api/diagnose/clash");
  }

  // 下载文件URL生成器
  getDownloadUrl(filename: string): string {
    return `${API_BASE_URL}/${filename}`;
  }

  // 转换订阅内容为Clash配置
  async convertContent(content: string): Promise<ConvertResult> {
    return this.request<ConvertResult>("/api/convert", {
      method: "POST",
      body: JSON.stringify({ content }),
    });
  }
}

export const apiService = new ApiService();
