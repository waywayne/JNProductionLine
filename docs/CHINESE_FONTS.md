# Linux 中文字体支持

## 问题说明

在 Linux 系统上运行应用时，中文可能显示为乱码（方块 □）或问号（?），这是因为系统缺少中文字体。

## 解决方案

### 方法 1: 运行安装脚本（推荐）

安装脚本会自动安装中文字体：

```bash
sudo ./scripts/install-linux.sh
```

### 方法 2: 单独安装中文字体

如果应用已经安装，可以单独安装字体：

```bash
sudo ./scripts/install-chinese-fonts.sh
```

### 方法 3: 手动安装

```bash
sudo apt-get update
sudo apt-get install -y \
    fonts-noto-cjk \
    fonts-noto-cjk-extra \
    fonts-wqy-microhei \
    fonts-wqy-zenhei
```

## 安装的字体

脚本会安装以下中文字体：

1. **Noto Sans CJK (思源黑体)**
   - Google 和 Adobe 联合开发的开源字体
   - 支持简体中文、繁体中文、日文、韩文
   - 包含多种字重（Thin, Light, Regular, Medium, Bold, Black）

2. **Noto Serif CJK (思源宋体)**
   - 思源黑体的宋体版本
   - 适合正文阅读

3. **WenQuanYi Micro Hei (文泉驿微米黑)**
   - 开源中文黑体
   - 包含完整的 GB18030 字符集

4. **WenQuanYi Zen Hei (文泉驿正黑)**
   - 开源中文黑体
   - 字形更加规范

## 应用字体配置

应用已配置字体回退机制，会按以下顺序尝试使用字体：

1. Roboto（英文默认字体）
2. Noto Sans CJK SC（思源黑体简体中文）
3. Noto Sans CJK（思源黑体）
4. WenQuanYi Micro Hei（文泉驿微米黑）
5. WenQuanYi Zen Hei（文泉驿正黑）
6. Droid Sans Fallback（Android 默认中文字体）

参见 `lib/main.dart`:

```dart
theme: ThemeData(
  fontFamily: 'Roboto',
  fontFamilyFallback: const [
    'Noto Sans CJK SC',
    'Noto Sans CJK',
    'WenQuanYi Micro Hei',
    'WenQuanYi Zen Hei',
    'Droid Sans Fallback',
  ],
),
```

## 验证字体安装

### 检查已安装的字体

```bash
fc-list :lang=zh
```

应该能看到类似以下输出：

```
/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc: Noto Sans CJK SC:style=Regular
/usr/share/fonts/truetype/wqy/wqy-microhei.ttc: WenQuanYi Micro Hei:style=Regular
/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc: WenQuanYi Zen Hei:style=Regular
```

### 更新字体缓存

如果手动安装了字体，需要更新字体缓存：

```bash
sudo fc-cache -fv
```

### 测试应用

安装字体后，重启应用：

```bash
sudo jn-production-line
```

中文应该能正常显示。

## 常见问题

### Q: 安装字体后仍然显示乱码？

**A**: 请确保：
1. 字体已正确安装：`fc-list :lang=zh`
2. 字体缓存已更新：`sudo fc-cache -fv`
3. 应用已重启

### Q: 某些中文字符仍然显示为方块？

**A**: 可能是字体不包含该字符。尝试安装更多字体：

```bash
sudo apt-get install -y fonts-noto fonts-noto-extra
```

### Q: 不同的 Linux 发行版字体包名称不同？

**A**: 是的，以下是常见发行版的字体包名称：

**Ubuntu/Debian:**
```bash
sudo apt-get install fonts-noto-cjk fonts-wqy-microhei
```

**Fedora/RHEL:**
```bash
sudo dnf install google-noto-sans-cjk-fonts wqy-microhei-fonts
```

**Arch Linux:**
```bash
sudo pacman -S noto-fonts-cjk wqy-microhei
```

### Q: 字体文件太大，能只安装简体中文吗？

**A**: 可以，只安装简体中文字体：

```bash
sudo apt-get install fonts-noto-cjk-sc
```

但 `fonts-noto-cjk` 包含所有 CJK 字符，更加完整。

## 支持的系统

已测试的 Linux 发行版：
- ✅ Ubuntu 20.04+
- ✅ Debian 11+
- ✅ Linux Mint 20+
- ✅ Fedora 35+（使用 dnf 安装）
- ✅ Arch Linux（使用 pacman 安装）

## 相关文档

- [LINUX_BUILD_GUIDE.md](LINUX_BUILD_GUIDE.md) - Linux 构建指南
- [Noto Fonts](https://www.google.com/get/noto/) - Google Noto 字体官网
- [WenQuanYi](http://wenq.org/) - 文泉驿字体项目

## 技术参考

- [Flutter Font Configuration](https://docs.flutter.dev/cookbook/design/fonts)
- [Linux Font Configuration](https://www.freedesktop.org/wiki/Software/fontconfig/)
- [fc-list Manual](https://linux.die.net/man/1/fc-list)
