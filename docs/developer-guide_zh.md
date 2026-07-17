# Anland: Termux 开发者文档

## 当前形态

- 基于 Anland
- Android 应用：`app/`
  - 包名：`com.anland.termux`
  - 应用名称：`Anland Termux`
  - 共享 UID：`com.termux`
  - 使用 `app/testkey_untrusted.jks` 签名
- Termux 守护程序：`termux/anland/`
  - 二进制名称：`anland`
  - 默认套接字：`$TMPDIR/anland/display_daemon.sock`

## 构建

### Android 显示应用

环境要求：

```text
Android Gradle Plugin 9.2.1
Gradle 9.6.0
Android NDK 29.0.14206865
minSdk 30
compileSdk 36
```

构建脚本：

```sh
tools/build-app.sh
```

构建产物：

```text
out/AnlandTermux-<version>.apk
```

### Anland 守护程序

构建脚本：

```sh
tools/build-termux-anland.sh
```

在 Termux 中运行时，输出文件是一个 Termux 可执行文件：

```text
out/anland
```

Termux 软件包的配方草稿位于：

```text
packages/anland/build.sh
```

关联的 Pull requests：https://github.com/lfdevs/termux-packages/pull/11
