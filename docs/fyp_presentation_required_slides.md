# SmartDiet AI 答辯簡報必備頁面清單

這份清單是根據 [BSc(AI&EdTech) INT4104 Assessment Rubrics 2b - Final Presentation (Capstone Project) (2).pdf](../BSc(AI%26EdTech)%20INT4104%20Assessment%20Rubrics%202b%20-%20Final%20Presentation%20(Capstone%20Project)%20(2).pdf) 整理而成，目標不是把頁數做多，而是讓你的簡報內容能直接對應評分點。

Rubric 主要看六個方向：

- `Design Process`
- `Connections to Experience`
- `Connections to Discipline`
- `Transfer`
- `Integrated Communication`
- `Innovative Thinking`

如果你想衝高分，簡報不能只是展示功能，而要讓評審清楚看到：你解決了什麼問題、用了什麼方法、為什麼這樣設計、效果如何、限制在哪裡。

## 建議簡報結構

建議控制在 11 到 13 頁。少於 9 頁通常不夠完整，多於 15 頁容易失焦。

### 1. Title Slide

`目的`: 先把題目說成一個有明確問題意識的 Capstone Project。

`這頁要有`:

- Project title: `SmartDiet AI: An AI-Assisted Nutrition Logging and Dietary Guidance System`
- 你的姓名、學號、課程名稱、指導老師
- 一句話摘要

`一句話摘要建議`:

> SmartDiet AI is a mobile system that combines food image analysis, camera metadata, conversational nutrition support, and manual correction to reduce the friction and inaccuracy of daily diet logging.

`對應 rubric`:

- `Integrated Communication`

### 2. Problem and Motivation

`目的`: 交代你為什麼做這個題目，並把真實生活問題說清楚。

`這頁要有`:

- 現有飲食記錄方法的痛點
- 為什麼手動輸入麻煩
- 為什麼只靠照片估算不穩
- 為什麼一般 nutrition app 不夠智能或不夠方便

`建議用 3 個 bullet`:

- Manual food logging is time-consuming and discourages long-term use.
- Vision-only food analysis is often unreliable in real-world conditions.
- Users need both fast logging and interpretable nutrition support.

`對應 rubric`:

- `Connections to Experience`
- `Integrated Communication`

### 3. Project Goal and Contributions

`目的`: 讓評審知道你不只是做 app，而是提出一套 solution。

`這頁要有`:

- Overall project goal
- 3 到 5 個核心 contribution

`建議 contribution 寫法`:

- Developed a Flutter-based AI nutrition logging app for practical daily use.
- Integrated food image analysis with camera optics metadata to improve portion estimation context.
- Added conversational nutrition guidance with RAG-based food knowledge retrieval.
- Designed a human-in-the-loop correction flow through manual nutrition editing.
- Evaluated design trade-offs between automation, usability, and reliability.

`對應 rubric`:

- `Design Process`
- `Innovative Thinking`
- `Transfer`

### 4. System Overview / Architecture

`目的`: 清楚展示整個系統怎麼運作。

`這頁要有`:

- 一張 architecture diagram
- 前端、AI analysis、chat/RAG、database 的關係
- 使用者從拍照到保存記錄的完整 flow

`圖中建議包含`:

- Flutter mobile app
- Camera capture
- EXIF metadata extraction
- AI analysis service
- Chat service with RAG
- Supabase database
- Dashboard and food log storage

`對應 rubric`:

- `Design Process`
- `Connections to Discipline`
- `Integrated Communication`

### 5. Methodology and Design Decisions

`目的`: 這頁是高分關鍵，因為它最直接對應 `Design Process`。

`這頁要有`:

- 你如何定義問題
- 你如何拆解系統模組
- 為什麼採用現在的設計
- 你做過哪些迭代與取捨

`必講設計決策`:

- Why combine AI estimation with manual editing
- Why EXIF / FOV metadata was introduced
- Why conversational support is useful beyond static logging
- Why some methods were disabled, replaced, or treated as fallback

`評審想看到的不是功能表，而是 reasoning`。

`對應 rubric`:

- `Design Process`
- `Transfer`

### 6. Interdisciplinary Integration

`目的`: 明確把這個題目的跨領域性講出來，不要讓評審自己猜。

`這頁要有`:

- Mobile app development
- Computer vision / image understanding
- Camera optics metadata reasoning
- LLM / RAG-based conversational interaction
- Nutrition informatics / HCI / user-centered design

`建議講法`:

> This project is interdisciplinary because it does not treat food logging as a UI problem only. It combines computer vision, camera metadata reasoning, conversational AI, nutrition tracking, and mobile interaction design into one practical system.

`對應 rubric`:

- `Connections to Discipline`

### 7. Key Features Demo Slide

`目的`: 幫正式 demo 鋪路，先讓評審知道你要展示什麼。

`這頁要有`:

- Camera-based food analysis
- Nutrition result editing
- Dashboard tracking
- Chat nutrition assistant
- Practical error handling or fallback interaction

`注意`: 這頁不是詳細解釋，是 demo 的導覽頁。

`對應 rubric`:

- `Integrated Communication`
- `Innovative Thinking`

### 8. Demo

`目的`: 直接展示完成度與實用性。

`建議 demo 流程`:

- 拍照
- 分析食物與營養
- 手動修正結果
- 儲存到 dashboard
- 開啟 chat 問與今天飲食相關的問題

`demo 時要刻意讓評審看到`:

- 系統不只是能分析，也能修正
- 結果有被保存和追蹤
- chat 不是獨立功能，而是整個系統的一部分

`對應 rubric`:

- `Integrated Communication`
- `Transfer`
- `Innovative Thinking`

### 9. Evaluation and Evidence

`目的`: 這頁是目前你最需要補強的地方之一。

`這頁要有`:

- 你如何評估系統
- 至少一個比較維度
- 至少一個真實樣例或 benchmark 結果
- 失敗案例或誤差分析

`建議可以放`:

- Visual-only estimation vs EXIF-enhanced prompting
- Different meal types and estimation quality
- Cases where manual correction was necessary
- Usability observations from actual usage

`如果數據未齊，至少要先有`:

- 測試案例數
- 比較方法
- 代表性結果
- 初步發現

`對應 rubric`:

- `Design Process`
- `Transfer`
- `Innovative Thinking`

### 10. Limitations and Trade-offs

`目的`: 顯示你有研究判斷，不是在過度包裝系統。

`這頁要有`:

- Occlusion, lighting, mixed dishes, container ambiguity
- Portion estimation uncertainty
- Local food coverage limitations
- LLM output reliability boundaries
- Why user correction remains necessary

`建議句型`:

> The project does not claim perfect nutrition estimation. Instead, it aims to improve practical usability by combining AI assistance with human correction.

`對應 rubric`:

- `Design Process`
- `Integrated Communication`

### 11. Future Work

`目的`: 告訴評審你清楚知道這個系統下一步能怎麼走。

`建議只放 3 到 4 點`:

- Barcode scanning for packaged food
- Personalized goal planning
- More local food database support
- Stronger quantitative evaluation or user study

`對應 rubric`:

- `Transfer`
- `Innovative Thinking`

### 12. Conclusion

`目的`: 收束全場，讓評審記住你的核心價值。

`這頁要回答 3 件事`:

- 你解決了什麼問題
- 你提出了什麼方法
- 這個系統有什麼實際價值

`建議結尾句`:

> In summary, SmartDiet AI is not just a calorie tracker. It is a practical AI-assisted system that explores how food image analysis, camera metadata, conversational guidance, and human correction can be combined for more usable diet logging.

`對應 rubric`:

- `Integrated Communication`
- `Innovative Thinking`

## 如果你想衝高分，這 5 頁不能弱

以下五頁最能直接拉高 rubric 表現：

- `Problem and Motivation`
- `Methodology and Design Decisions`
- `Interdisciplinary Integration`
- `Evaluation and Evidence`
- `Limitations and Trade-offs`

如果這五頁講得扎實，評審會更容易把你判定到 `Level 3` 以上，甚至部分面向接近 `Level 4`。

## 建議你在簡報中主動對位的評分訊號

### 對位 Design Process

- 不要只說做了什麼，要說為什麼這樣設計
- 要展示迭代與取捨，而不是只展示結果

### 對位 Connections to Experience

- 把真實生活中的 diet logging 痛點講出來
- 交代你如何從真實使用情境反推設計需求

### 對位 Connections to Discipline

- 明確講跨了哪些領域
- 說明這些領域怎麼互相支撐，而不是各自獨立存在

### 對位 Transfer

- 說明你如何把一個技術方法轉用到 nutrition logging 情境
- 強調 adaptation，而不只是 adoption

### 對位 Integrated Communication

- 全份簡報保持同一套視覺語言
- 每一頁只講一個核心訊息
- 圖表優先於大段文字

### 對位 Innovative Thinking

- 強調你提出的是 practical hybrid system
- 用 evidence 支撐創新，而不是只用形容詞

## 簡報常見失分點

- 只展示 UI，沒有 methodology
- 只說功能，沒有 problem statement
- 只講成功案例，沒有 limitations
- 只有系統流程，沒有 evaluation evidence
- Chat、camera、dashboard 各講各的，沒有整合成同一個 project story

## 最後檢查清單

答辯前，至少確認以下問題都能回答：

- 你的 project 具體解決什麼問題
- 為什麼這個問題值得做
- 你的方法與一般 app 有什麼不同
- 為什麼你選這些技術，而不是別的方法
- 你的系統在哪些情況有效，哪些情況不穩
- 你如何評估系統
- 你的主要 contribution 是什麼
- 如果多做一個月，你最優先會補什麼

如果這些問題你都能在簡報中自然回答出來，整體答辯會穩很多。