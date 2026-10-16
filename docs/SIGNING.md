# 代码签名与更新体验

> 目的：让 App 在**本地构建和发布更新**时拥有稳定的签名身份，从而让 macOS 钥匙串授权一次长期有效；
> 并给出将来做 Developer ID 签名与公证的路径。
>
> 背景：ad-hoc 签名（`codesign --sign -`）的 designated requirement 基于**每次构建都不同的 cdhash**。
> 钥匙串条目的 ACL 记录的是旧 cdhash，于是每次重新构建/更新后，读取已保存的密码都会弹一次授权询问；
> 旧版本在主线程同步读取钥匙串，弹窗未处理时整个 App 会卡住。应用侧已改为“后台读取 + 5 秒超时”，
> 但要让弹窗**只出现一次**，需要稳定的签名证书。

## 1. 本地：自签名代码签名证书（已完成）

本机已创建并在登录钥匙串中导入一张自签名证书：

```sh
mkdir -p ~/.ginkgo-signing && chmod 700 ~/.ginkgo-signing
cd ~/.ginkgo-signing
openssl req -x509 -newkey rsa:2048 -keyout ginkgo-key.pem -out ginkgo-cert.pem \
  -days 3650 -nodes -subj "/CN=Ginkgo Local Signing/O=Ginkgo/C=CN" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:false"
# macOS 不认 OpenSSL 3 默认的 PKCS#12 算法，必须用传统算法导出
openssl pkcs12 -export -out ginkgo-signing.p12 -inkey ginkgo-key.pem -in ginkgo-cert.pem \
  -name "Ginkgo Local Signing" -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
  -passout pass:<本地口令>
security import ~/.ginkgo-signing/ginkgo-signing.p12 -k ~/Library/Keychains/login.keychain-db \
  -P <本地口令> -T /usr/bin/codesign -T /usr/bin/security
```

- 私钥与 p12 保存在 `~/.ginkgo-signing/`（权限 600，**不入库**）。
- 证书是自签名的，`security find-identity -v` 会显示 `CSSMERR_TP_NOT_TRUSTED`，但 `codesign` 可以正常使用；
  designated requirement 形如：

  ```
  identifier "com.buaaassistant.app" and certificate root = H"35ca49…"
  ```

  它与构建次数无关，因此钥匙串授权一次即可长期复用。

### 用证书签名本地构建

```sh
APP=~/Library/Developer/Xcode/DerivedData/.../BUAA-Assistant.app
codesign --force --sign "Ginkgo Local Signing" --timestamp=none "$APP"
```

未安装该证书时退回 `codesign --force --sign -` 也能运行，只是每次构建都会重新弹钥匙串授权。

### 在 Xcode 里使用（维护者操作，AI 不修改 .xcodeproj）

Xcode → target `BUAA-Assistant` → Signing & Capabilities → 取消 “Automatically manage signing”，
Signing Certificate 选择 **Ginkgo Local Signing**。这样 ⌘R 构建也使用稳定身份。

## 2. CI：发布包也使用同一张证书

GitHub Secrets 已配置（仓库 Settings → Secrets and variables → Actions）：

| Secret | 内容 |
|---|---|
| `MACOS_CERT_P12` | `ginkgo-signing.p12` 的 base64 |
| `MACOS_CERT_PASSWORD` | p12 口令 |

`.github/workflows/release.yml` 在打包前导入证书；能找到 `Ginkgo Local Signing` 就用它签名，
否则自动退回 ad-hoc 签名（不会让发布失败）。

> ⚠️ 请妥善保管 `~/.ginkgo-signing/`。证书或口令轮换后，用户需要**再授权一次**钥匙串（之后继续长期有效）。

## 3. 首次授权与常见问题

- 首次运行或更换签名身份后，macOS 会询问一次钥匙串访问：选择 **“始终允许”**。之后同一证书的构建不再询问。
- 弹窗未处理时应用不会卡住：5 秒超时后回到登录页并提示“钥匙串需要授权”。
- 如果不想保留已保存的密码：设置 → 退出登录（会删除钥匙串条目），或手动登录时不勾选“记住密码”。

## 4. 将来：Developer ID 签名与公证（需要 Apple Developer Program，$99/年）

1. 在 Apple Developer 后台创建 **Developer ID Application** 证书，导入登录钥匙串；
2. 发布工作流改为用该证书签名，并追加公证与装订：

   ```sh
   xcodebuild -exportArchive ... -exportOptionsPlist ExportOptions.plist   # teamID / signingCertificate
   xcrun notarytool submit Ginkgo-<tag>.dmg --apple-id <id> --team-id <team> --password <app-specific-password> --wait
   xcrun stapler staple Ginkgo-<tag>.dmg
   ```

3. 把证书 p12、`notarytool` 的 Apple ID / Team ID / App 专用密码写入 GitHub Secrets，
   在 `release.yml` 中替换第 2 节的本地证书导入步骤；
4. 公证通过后，用户下载 DMG 双击即可打开，不再需要“隐私与安全性 → 仍要打开”。

> 公证流程与 Apple 政策每年可能变化，届时以 Apple 官方文档为准，并在本文件记录变更日期。
