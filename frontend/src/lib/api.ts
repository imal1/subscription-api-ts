import ky, { HTTPError } from 'ky';

const API_BASE_URL =
  process.env.NODE_ENV === "production"
    ? "" // 在生产环境中使用相对路径
    : "http://localhost:3000"; // 开发环境中使用完整URL

// 创建 ky 实例
const apiClient = ky.create({
  prefixUrl: API_BASE_URL,
  timeout: 30000,
  retry: {
    limit: 3,
    methods: ['get', 'post'],
    statusCodes: [408, 413, 429, 500, 502, 503, 504],
  },
  hooks: {
    beforeError: [
      (error) => {
        console.error('API 请求失败:', error);
        return error;
      }
    ]
  }
});

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

// 自定义错误类
export class ApiError extends Error {
  constructor(
    public status: number,
    public statusText: string,
    public data?: any
  ) {
    super(`API Error ${status}: ${statusText}`);
    this.name = 'ApiError';
  }
}

class ApiService {
  // 处理 API 错误
  private async handleError(error: unknown): Promise<never> {
    if (error instanceof HTTPError) {
      const status = error.response.status;
      const statusText = error.response.statusText;
      
      let errorData;
      try {
        errorData = await error.response.json();
      } catch {
        errorData = null;
      }

      throw new ApiError(status, statusText, errorData);
    }

    throw error;
  }

  // 获取API状态
  async getStatus(): Promise<ApiStatus> {
    try {
      return await apiClient.get('api/status').json<ApiStatus>();
    } catch (error) {
      return this.handleError(error);
    }
  }

  // 更新订阅
  async updateSubscription(): Promise<UpdateResult> {
    try {
      return await apiClient.get('api/update').json<UpdateResult>();
    } catch (error) {
      return this.handleError(error);
    }
  }

  // 获取健康状态
  async getHealth(): Promise<{ status: string; timestamp: string }> {
    try {
      return await apiClient.get('health').json();
    } catch (error) {
      return this.handleError(error);
    }
  }

  // 获取配置列表
  async getConfigs(): Promise<string[]> {
    try {
      const response = await apiClient.get('api/configs').json<ApiResponse<string[]>>();
      return response.data || [];
    } catch (error) {
      return this.handleError(error);
    }
  }

  // 诊断Clash生成
  async diagnoseClash(): Promise<any> {
    try {
      return await apiClient.get('api/diagnose/clash').json();
    } catch (error) {
      return this.handleError(error);
    }
  }

  // 下载文件URL生成器
  getDownloadUrl(filename: string): string {
    return `${API_BASE_URL}/${filename}`;
  }

  // 转换订阅内容为Clash配置
  async convertContent(content: string): Promise<ConvertResult> {
    try {
      return await apiClient.post('api/convert', { json: { content } }).json<ConvertResult>();
    } catch (error) {
      return this.handleError(error);
    }
  }
}

export const apiService = new ApiService();
