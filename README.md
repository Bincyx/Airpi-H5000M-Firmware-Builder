# AirPi H5000M 繁體中文韌體建置器

這是一個獨立的 Hiveton／AirPi H5000M 雲端韌體建置專案。它會從 PadavanOnly 的 MT7987／MT7992 閉源 Wi-Fi 驅動分支取得原始碼，建置帶有繁體中文 LuCI、5G 數據機工具及 H5000M 常用功能的韌體。

## 主要特色

- 管理介面預設為台灣繁體中文。
- 時區預設為 `Asia/Taipei`。
- 支援 QModem、MBIM、QMI 與常見 USB 5G 數據機。
- 使用 ccache、下載快取及工具鏈快取縮短後續建置時間。
- 每週一台灣時間凌晨 4 點自動建置，也可隨時手動執行。
- 每次發布保留韌體、完整建置設定及 SHA256 校驗檔。
- 不會自動刪除舊 Release，方便需要時回退。

## 下載韌體

進入 GitHub 專案右側的 **Releases**，下載檔名含有 `h5000m` 的韌體。刷寫前請先核對 `SHA256SUMS`。

## 手動建置

1. 開啟 GitHub 專案的 **Actions**。
2. 選擇「建置 H5000M 繁體中文韌體」。
3. 按下 **Run workflow**。
4. 一般情況不要勾選「忽略既有編譯快取」。

第一次完整建置需要建立工具鏈與 ccache，因此時間較長；後續建置通常會明顯加快。

## 安全與刷機提醒

- 本專案只負責自動化建置，不保證任何第三方韌體適用於所有硬體批次。
- 刷機前務必備份原廠韌體、EEPROM、分割區及目前設定。
- 請確認裝置型號確實是 Hiveton／AirPi H5000M。
- 不建議在 Release 中公開預設管理密碼；首次登入後請立即設定高強度密碼。
- 上游原始碼與附加套件各自適用其原有授權條款。

## 專案結構

```text
.github/workflows/build.yml   GitHub Actions 建置與發布流程
config/h5000m.config          可維護的最小韌體設定
overlay/                      首次開機的繁體中文與時區設定
scripts/prepare.sh            準備 feeds、主題與韌體設定
scripts/collect.sh            收集產物並建立 SHA256 校驗檔
```

## 上游來源

- [PadavanOnly ImmortalWrt MT798x](https://github.com/padavanonly/immortalwrt-mt798x-6.6)
- [QModem](https://github.com/FUjr/QModem)
- [Argon 主題](https://github.com/sbwml/luci-theme-argon)

本專案的建置腳本採用 MIT License；上游韌體原始碼、驅動程式與套件不因此改變授權。

