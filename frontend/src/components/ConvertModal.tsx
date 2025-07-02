"use client";

import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { apiService } from "@/lib/api";
import { Icon } from "@iconify/react";
import { Editor } from "@monaco-editor/react";
import { useState } from "react";

interface ConvertModalProps {
  isOpen: boolean;
  onClose: () => void;
}

const ConvertModal = ({ isOpen, onClose }: ConvertModalProps) => {
  const [inputText, setInputText] = useState("");
  const [outputYaml, setOutputYaml] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleConvert = async () => {
    if (!inputText.trim()) {
      setError("请输入原始订阅文本");
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const result = await apiService.convertContent(inputText);
      if (result.success && result.data?.clashConfig) {
        setOutputYaml(result.data.clashConfig);
      } else {
        setError(result.error || "转换失败");
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "转换失败");
    } finally {
      setLoading(false);
    }
  };

  const handleClearInput = () => {
    setInputText("");
    setError(null);
  };

  const handleClearOutput = () => {
    setOutputYaml("");
  };

  const handleCopyOutput = async () => {
    if (outputYaml) {
      try {
        await navigator.clipboard.writeText(outputYaml);
        // 简单的成功提示
        const button = document.querySelector("[data-copy-button]");
        if (button) {
          const originalText = button.textContent;
          button.textContent = "已复制!";
          setTimeout(() => {
            button.textContent = originalText;
          }, 2000);
        }
      } catch (err) {
        setError("复制失败");
      }
    }
  };

  const handleClose = () => {
    setInputText("");
    setOutputYaml("");
    setError(null);
    onClose();
  };

  return (
    <Dialog open={isOpen} onOpenChange={handleClose}>
      <DialogContent className="max-w-6xl max-h-[90vh] overflow-hidden">
        <DialogHeader>
          <DialogTitle className="flex items-center space-x-2">
            <Icon icon="mdi:code-braces" className="w-5 h-5" />
            <span>订阅内容转换</span>
          </DialogTitle>
          <DialogDescription>
            输入原始订阅文本（raw.txt 格式），转换为 Clash YAML 配置
          </DialogDescription>
        </DialogHeader>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 h-[600px]">
          {/* 输入区域 */}
          <div className="flex flex-col space-y-3">
            <div className="flex items-center justify-between">
              <label className="text-sm font-medium">原始订阅文本</label>
              <Button
                variant="outline"
                size="sm"
                onClick={handleClearInput}
                disabled={!inputText}
              >
                <Icon icon="mdi:eraser" className="w-4 h-4 mr-1" />
                清空
              </Button>
            </div>

            <div className="flex-1 border rounded-md overflow-hidden">
              <Editor
                height="100%"
                defaultLanguage="text"
                value={inputText}
                onChange={(value) => setInputText(value || "")}
                options={{
                  minimap: { enabled: false },
                  lineNumbers: "on",
                  wordWrap: "on",
                  scrollBeyondLastLine: false,
                  fontSize: 13,
                  tabSize: 2,
                  insertSpaces: true,
                  folding: false,
                  renderWhitespace: "boundary",
                  automaticLayout: true,
                }}
                theme="vs"
              />
            </div>

            <div className="text-xs text-muted-foreground">
              请粘贴包含节点链接的原始文本，支持 vmess://, ss://, trojan://
              等协议
            </div>
          </div>

          {/* 输出区域 */}
          <div className="flex flex-col space-y-3">
            <div className="flex items-center justify-between">
              <label className="text-sm font-medium">Clash YAML 配置</label>
              <div className="flex space-x-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleCopyOutput}
                  disabled={!outputYaml}
                  data-copy-button
                >
                  <Icon icon="mdi:content-copy" className="w-4 h-4 mr-1" />
                  复制
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleClearOutput}
                  disabled={!outputYaml}
                >
                  <Icon icon="mdi:eraser" className="w-4 h-4 mr-1" />
                  清空
                </Button>
              </div>
            </div>

            <div className="flex-1 border rounded-md overflow-hidden">
              <Editor
                height="100%"
                defaultLanguage="yaml"
                value={outputYaml}
                options={{
                  readOnly: true,
                  minimap: { enabled: false },
                  lineNumbers: "on",
                  wordWrap: "on",
                  scrollBeyondLastLine: false,
                  fontSize: 13,
                  tabSize: 2,
                  folding: true,
                  renderWhitespace: "boundary",
                  automaticLayout: true,
                }}
                theme="vs"
              />
            </div>

            <div className="text-xs text-muted-foreground">
              生成的 YAML 配置可直接用于 Clash 客户端
            </div>
          </div>
        </div>

        {/* 错误提示 */}
        {error && (
          <div className="bg-destructive/10 border border-destructive/20 rounded-md p-3">
            <div className="flex items-center space-x-2 text-destructive">
              <Icon icon="mdi:alert-circle" className="w-4 h-4" />
              <span className="text-sm font-medium">错误</span>
            </div>
            <p className="text-sm text-destructive mt-1">{error}</p>
          </div>
        )}

        <DialogFooter>
          <Button variant="outline" onClick={handleClose}>
            关闭
          </Button>
          <Button
            onClick={handleConvert}
            disabled={loading || !inputText.trim()}
          >
            {loading && (
              <Icon icon="mdi:loading" className="w-4 h-4 mr-2 animate-spin" />
            )}
            {loading ? "转换中..." : "转换"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
};

export default ConvertModal;
