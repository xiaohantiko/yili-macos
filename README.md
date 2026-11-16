# 易历

易历是一款原生 macOS 应用。输入公历出生日期、当地出生时间和时区，即可查看年、月、日、时四柱、五行分布与命理解读。每日运势结合生辰八字与当天干支，提供工作、人际和生活节奏方面的提示，以及八卦象意和方位参考。

## 本地运行

应用支持 macOS 14 或更新版本。构建需要 Swift 5.9 或更新版本，安装 Xcode Command Line Tools 即可。

```bash
./scripts/build-app.sh
open "dist/易历.app"
```

也可以在 Finder 中双击 `dist/易历.app`。初次打开会显示示例命盘，录入自己的出生资料后即可切换为个人结果。测试需要 Swift 6 或更新版本，运行 `./scripts/test.sh` 可验证排盘与解读规则。

## 使用口径

- 出生日期采用公历，支持 1901–2099 年。按所选出生时区解释当时的钟表时间，采用该时区的历史时差和夏令时规则。遇到跳过的时刻需重新输入，遇到重复的时刻取第一次。排盘采用民用时间。
- 年柱在立春交节时换年，月柱按十二个「节」的交节时刻切换。日柱在本地午夜换日。子时始于 23:00，时干按当时所属民用日的日干推算。 [香港天文台关于立春与干支纪年的说明](https://www.hko.gov.hk/tc/education/astronomy-and-time/time-service/00506-what-year-is-it-today.html) · [天干和地支表](https://www.hko.gov.hk/tc/gts/time/stemsandbranches.htm)
- 节气交接时刻根据 JPL DE440 星历预先计算，使用 UT1 近似民用时间。出生时刻贴近交节边界时，输入精度与历史时差可能影响结果。 [JPL DE440 星历](https://ssd.jpl.nasa.gov/doc/de440_de441.html) · [2024 年天文年鉴](https://www.cwa.gov.tw/Data/service/notice/download/Publish_20231127145652.pdf)
- 今日以这台 Mac 的本地时区划分。出生资料保存在本机，排盘和日运均可离线使用。
- 日运比较当天的天干与本命日主的五行生克，按应用规则将当天的地支对应到一卦。卦象与后天方位参考《周易·说卦》及历代注解。 [《周易正义·说卦》](https://zh.wikisource.org/zh-hans/%E5%91%A8%E6%98%93%E6%AD%A3%E7%BE%A9/09.05) · [《周易集说》卷三十七](https://zh.wikisource.org/zh-hans/%E5%91%A8%E6%98%93%E9%9B%86%E8%AA%AC_%28%E5%9B%9B%E5%BA%AB%E5%85%A8%E6%9B%B8%E6%9C%AC%29/%E5%8D%B737)
- 命理与日运属于传统文化解读，宜忌与方位用于日常参考。
