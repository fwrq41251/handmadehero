# Handmade Hero

## 开发工具版本

项目使用 mise 管理工具链，固定以下版本：

| 工具 | 版本 |
| --- | --- |
| Zig | 0.16.0 |
| ZLS | 0.16.0 |
| Raylib | 6.0，源码保存在 `vendor/` |

Raylib Zig 绑定的固定提交与许可证见 [vendor/README.md](vendor/README.md)。
升级时一起验证 Zig、ZLS 和依赖，再更新项目配置。

## 安装与构建

macOS 可以通过 `brew install mise` 安装 mise。Linux 安装方法见
[mise 官方文档](https://mise.jdx.dev/installing-mise.html)。

在项目根目录执行：

```sh
mise trust
mise install
mise exec -- zig build
mise exec -- zig build test
mise exec -- zig build run
```

`mise.toml` 指定精确版本，`mise.lock` 记录 macOS/Linux 的下载地址和校验值，
构建脚本也会拒绝使用其他 Zig 版本。CI 可使用 `mise install --locked`。

若使用 zsh，在 `~/.zshrc` 中添加以下内容，并重新打开终端：

```sh
eval "$(mise activate zsh)"
```

启用后，在项目目录可以直接使用 `zig build`；其他目录使用各自的工具版本。
已有的 Homebrew Zig/ZLS 可以保留，由 mise 在项目内选择固定版本。

## Zed

项目的 `.zed/settings.json` 通过 `mise exec -- zls` 启动语言服务器，
让 ZLS 和它调用的 Zig 都使用项目固定版本，同时开启保存时构建诊断。
Zed 的环境需要能找到 `mise`。首次配置后重启 Zed，使它重新获取 shell 环境。
