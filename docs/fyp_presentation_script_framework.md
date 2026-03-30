# SmartDiet AI 答辯講稿框架

這份講稿框架是給你答辯時直接使用的版本。不是逐字稿，但已經接近可以直接照著講。你可以按實際時間長度刪減內容。

建議用法：

- 如果你只有 `8 到 10 分鐘`，每頁抓 `40 到 60 秒`
- 如果你有 `12 到 15 分鐘`，可以在 methodology、evaluation、demo 三段多展開

整體節奏建議：

- 開場先講問題，不要先講功能
- 中段講方法與設計理由
- 後段講 demo、evidence、limitations
- 收尾強調 contribution，而不是再重複功能表

## Slide 1: Title

大家好，我的 capstone project 題目是 SmartDiet AI。這是一個以行動裝置為平台的 AI 輔助飲食記錄系統，但我這個 project 最核心的目的，不只是做出一個自動化 app。

我真正想研究的是兩個問題。第一，當大模型用來回答營養相關問題時，怎樣降低營養資訊出現幻覺的風險。第二，當大模型用來從照片估算食物份量時，怎樣改善份量估算不準確的問題。

所以這個 project 同時是一個可運作的系統，也是一個圍繞 nutrition hallucination 和 portion estimation accuracy 的研究導向 project。

## Slide 2: Problem and Motivation

我選這個題目的原因，是因為現有的飲食記錄方式雖然很多，但在真實使用中有兩個很明顯的技術問題。

第一個問題是營養幻覺。當使用大模型回答食物營養、熱量或飲食建議時，如果沒有可靠資料來源，模型很容易生成看起來合理、但實際上不準確的內容。這對 nutrition 場景來說是高風險問題。

第二個問題是分量估算不準確。只靠單張照片去估份量，在真實場景裡很容易受拍攝角度、距離、光線、食物遮擋、容器形狀和菜式複雜度影響。

因此，我這個 project 的動機不是單純把記錄流程自動化，而是研究在真實使用條件下，能不能用更可靠的 retrieval 機制去降低營養幻覺，以及用不同 estimation strategy 去改善份量估算的合理性。

## Slide 3: Project Goal and Contributions

這個 project 的整體目標，是建立一個 practical AI-assisted diet logging system，同時把它作為研究平台，去驗證兩個方向。

第一個方向，是利用 RAG 來降低營養知識生成時的 hallucination。第二個方向，是比較不同 food portion estimation 方法在真實情境下的表現與限制。

這個 project 有幾個主要 contribution。

第一，我開發了一個完整的 Flutter mobile app，支援 food logging、dashboard tracking 和 chat-based nutrition assistance。第二，我把 RAG 引入營養問答流程，並使用香港食物安全中心資料作為主要知識來源，降低模型自由生成造成的錯誤資訊。第三，我研究並測試了多種份量估算方向，包括 ARCore 手動量度、ARCore 結合 SAM 的自動量度、純大模型視覺估算，以及 EXIF 加大模型的方法。第四，我加入 manual nutrition editing，讓整個系統採用 human-in-the-loop 的方式，而不是假設 AI 一定正確。

## Slide 4: System Overview

這一頁是系統總覽。整個系統可以分成兩條主線。

第一條是 food logging line。使用者拍攝食物照片後，系統會先取得影像與部分 camera metadata，例如 EXIF 資訊。如果有額外量度資訊，例如 ARCore 或 optics context，也會一併進入分析流程。接著，系統不會直接產生最終營養結果，而是先用模型快速辨識食物名稱。得到食物名稱之後，系統會再用這些名稱去檢索香港食物安全中心的資料庫，找出最相關的官方營養資料。最後，系統才會把影像、本身的 camera context，以及這一輪 RAG 檢索出的 CFS 資料一起送進最後的 nutrition analysis，產生熱量與三大營養素估算。使用者之後可以在結果頁直接修正內容，再把資料存入 dashboard 與 food log。

第二條是 nutrition knowledge line。使用者可以透過 chat assistant 提問與食物和營養有關的問題，系統會先做 retrieval，從香港食物安全中心等資料來源找相關內容，再把結果提供給大模型生成答案。這樣做的目的，是讓回答建立在可追溯的資料上，而不是完全依賴模型記憶。

所以這個 system overview 不只是 app flow，也是在對應我研究的兩個核心問題。

## Slide 5: Methodology and Design Decisions

這個 project 其中一個重點，是我不是把 AI 當成一定正確的 black box，而是把它拆成兩個可以研究和比較的問題。

第一個問題是 nutrition hallucination。為了處理這個問題，我沒有直接讓大模型自由回答，而是加入 RAG，並使用香港食物安全中心資料作為核心知識來源。這樣的設計，是希望回答能更貼近本地、可信和可查證的營養資訊。

第二個問題是 portion estimation accuracy。這一部分我沒有只測一種方法，而是研究並比較多個方向，包括 ARCore 手動量度、ARCore 加上 SAM 的自動量度、純大模型估算，以及把 EXIF 和 field-of-view 資訊加入提示後再讓大模型估算。我的重點不是證明某一種方法永遠最好，而是分析不同方法在真實使用情境下的優勢、限制和適用條件。

另外，我也刻意保留 manual editing，因為不論是營養回答還是份量估算，只要面向真實使用，就一定存在不確定性。換句話說，這個系統的設計重點不是追求 fully automatic，而是追求更可靠、更可修正、也更有研究價值的 workflow。

## Slide 6: Interdisciplinary Integration

這個 project 是一個跨領域整合的題目。它不只是 mobile app development，也結合了 computer vision、camera metadata reasoning、LLM and retrieval-based interaction，以及 nutrition-oriented user experience design。

其中，RAG 和香港食物安全中心資料的結合，對應的是資訊可靠性問題。多種 portion estimation 方法的比較，對應的是電腦視覺與實際量度問題。最後，manual correction、dashboard 和 chat flow，則對應到真實使用中的 HCI 與 usability 問題。

所以這個 project 的價值，不只是把不同技術放在一起，而是讓每一個技術都對應到一個實際的研究問題。

## Slide 7: Key Features

在功能上，我想先強調四個最核心的部分，但這四個功能其實都服務於我的研究主軸。

第一是 RAG-based chat assistant，用來測試在營養問答中加入可靠知識來源後，能不能降低 hallucination。第二是 camera-based food analysis，用來承載不同 portion estimation 方法的比較。第三是 nutrition editing，因為這能反映 AI 在真實使用中仍然需要 human correction。第四是 dashboard tracking，讓整個系統不只是單次分析，而是完整的 diet logging workflow。

所以這些不是單純的 app features，而是研究問題在系統中的具體落地方式。

## Slide 8: Demo

接下來我會簡單 demo 一次完整流程。首先，使用者拍攝食物照片。之後系統會產生食物與營養估算結果。若結果有偏差，使用者可以直接在結果頁修正食物名稱、熱量或營養值。確認後，資料會被存入 dashboard。最後，我也可以用 chat assistant 針對這次或今天的飲食提出進一步問題。

在這個 demo 中，我想展示的不只是功能可以跑，而是整個系統如何支援從 capture、analysis、correction、storage 到 follow-up guidance 的完整過程。

如果時間允許，demo 後可以接一句：

> 接下來我會用兩組圖表展示這個系統背後兩個研究問題的評估結果，也就是 RAG 對 hallucination 的影響，以及不同分量估算方法的差異。

## Slide 9: Evaluation and Findings

在 evaluation 部分，我主要關心兩條研究問題。

第一條，是 RAG 是否能降低 nutrition hallucination。這部分我關注的是，當模型回答營養相關問題時，加入香港食物安全中心等檢索內容後，回答是否更穩定、更可追溯，也更接近可靠資料來源。

第二條，是不同 portion estimation 方法的表現差異。這部分我比較了 ARCore 手動量度、ARCore 加 SAM 自動量度、純大模型方法，以及 EXIF 加大模型的方法，並觀察它們在不同食物場景中的穩定性與偏差情況。

目前我的 evaluation 方式包括 benchmark comparison、代表性案例分析，以及失敗情況觀察。從結果來看，我發現純大模型方法雖然方便，但在份量判斷上容易不穩。ARCore 類方法能提供較明確的幾何量度基礎，但在操作性或自動化程度上有不同 trade-off。EXIF 加大模型的方法不能完全解決問題，但能提供額外拍攝幾何上下文，讓模型推理更有依據。

整體來說，我的結論不是某個方法完勝，而是不同方法各有成本與限制，而 human correction 仍然是實際系統中不可少的一環。

### 這裡建議插入圖表 1: RAG Before/After Comparison

`建議標題`:

`Comparison of Nutrition Answers Before and After RAG`

`你可以這樣講`:

這張圖展示的是在沒有 RAG 與加入 RAG 之後，模型在營養相關回答上的差異。重點不是只看答案長短，而是看回答是否更接近可信來源、是否更穩定，以及是否更容易追溯到資料依據。

如果你的圖表有量化指標，這裡可以補：

- hallucination rate
- factual consistency
- source grounding
- answer relevance

`這張圖講解重點`:

- 沒有 RAG 時，模型較容易依賴內部記憶生成看似合理的內容
- 加入 RAG 後，回答更接近香港食物安全中心等資料來源
- RAG 不能保證完全正確，但能降低自由生成造成的風險

### 這裡建議插入圖表 2: Portion Estimation Methods Comparison

`建議標題`:

`Comparison of Portion Estimation Methods`

`建議圖表包含的方法`:

- ARCore manual measurement
- ARCore + SAM automatic measurement
- Pure LLM-based estimation
- EXIF + LLM estimation

`你可以這樣講`:

這張圖展示的是我比較不同分量估算方法後的結果。這裡我關心的不只是準確度，還包括操作成本、自動化程度、對場景條件的依賴，以及整體穩定性。

`這張圖講解重點`:

- ARCore 手動量度通常幾何基礎較清楚，但需要較多人工操作
- ARCore 加 SAM 可以提高自動化，但流程更複雜，也受 segmentation 品質影響
- 純大模型方法最方便，但在份量估算上較容易不穩
- EXIF 加大模型方法提供額外相機幾何資訊，對推理有幫助，但不是完整解法

### 如果你還有第三張圖，可以留作案例分析

`建議標題`:

`Representative Success and Failure Cases`

`你可以這樣講`:

除了整體比較之外，我也挑了幾個代表性案例來看不同方法在哪些食物上表現較好，哪些情況下容易失敗。這能幫助我理解不是哪個方法絕對最好，而是哪一種方法在什麼條件下更適合。

如果你有實際數據，這裡直接插入：測試數量、案例類型、每種方法的代表性表現、誤差比較與失敗案例。

## Slide 10: Limitations and Trade-offs

這個 project 當然也有明確限制。首先，RAG 可以降低 hallucination 風險，但前提是資料來源本身要足夠完整，而且 retrieval 命中內容要真的 relevant，所以它是風險降低，不是風險消失。第二，food portion estimation 仍然會受到遮擋、光線、混合菜式和容器形狀影響，沒有任何一種方法可以在所有情況下都穩定準確。第三，不同 estimation 方法之間存在明顯 trade-off，例如操作成本、自動化程度、對場景條件的依賴，以及結果穩定性。

所以我對這個系統的定位不是 perfect nutrition estimator，也不是保證零幻覺的 nutrition assistant，而是一個 AI-assisted、evidence-aware、human-correctable system。這個 trade-off 是刻意的，因為在真實使用中，可靠性和可修正性比表面上的全自動更重要。

## Slide 11: Future Work

如果未來繼續發展，我認為有幾個方向最值得做。第一，是擴充 RAG 的營養知識來源與檢索策略，進一步降低 hallucination 風險。第二，是把 portion estimation evaluation 做得更完整，包括更多真實食物類型、更標準化的 ground truth，和更系統化的誤差分析。第三，是加入 barcode scanning 和更完整的 local food database，補足 packaged food 和本地餐飲場景。第四，是進行更正式的 user study，驗證這套 human-in-the-loop workflow 是否真的提升實際使用體驗。

## Slide 12: Conclusion

最後總結一下。SmartDiet AI 嘗試解決的，不只是日常飲食記錄流程麻煩這件事，而是兩個更核心的問題：第一，營養相關回答如何降低 hallucination；第二，食物份量估算如何在真實情境下變得更合理。

為了處理這兩個問題，我提出了一個結合 RAG、香港食物安全中心知識來源、多種 portion estimation 方法比較、food image analysis、camera metadata，以及 manual correction 的 mobile system。

我認為這個 project 的價值，不只是做出一個 app，而是在實際使用情境下，研究如何把 AI 做得更可靠、更可修正，也更適合 nutrition logging 這個高不確定性的場景。

謝謝各位，接下來歡迎提問。

## 可臨場補充的句子

如果評審追問，你可以補這幾類句子。

### 當評審問為什麼不完全自動化

我刻意沒有把系統設計成 fully automatic，因為在 food analysis 這類 real-world task 中，不確定性很高。與其假設模型永遠正確，我更重視讓使用者能快速修正結果，這樣整體 usability 會更高。

### 當評審問你的創新在哪裡

我的創新不只是在於使用 AI，而是在於把兩個常被忽略的問題具體化並落到系統中。第一是用 RAG 和香港食物安全中心資料去降低 nutrition hallucination。第二是把多種 portion estimation 方法放在同一個 project 中研究和比較，而不是只展示一種看起來最好的方法。重點是 reliability-oriented integration，而不是單一模型本身。

### 當評審問你做了什麼研究成分

研究成分主要體現在兩部分。第一，是營養知識生成的可靠性研究，也就是 RAG 是否能降低 hallucination。第二，是 portion estimation 方法比較，包括 ARCore 手動量度、ARCore 加 SAM 自動量度、純大模型，以及 EXIF 加大模型等方法的比較、取捨和失敗案例分析。所以我不是只做功能實作，而是有意識地評估哪些方法在真實情境下更合理。

### 當評審問這個 project 最大限制是什麼

最大的限制有兩個。第一，RAG 可以降低 hallucination，但不能保證所有 nutrition 回答都完全正確，因為它仍受資料覆蓋度和 retrieval quality 影響。第二，food portion estimation 在真實環境中仍然高度不確定，特別是複合食物、遮擋和拍攝條件不理想的情況。因此我把系統定位成 AI-assisted logging，而不是 fully automatic diagnosis or measurement system。

## 你答辯前一定要替換的內容

以下內容請在正式答辯前填上你的真實資料：

- 你的正式 project title
- 指導老師姓名
- 你的實際 benchmark / evaluation 數據
- 你的 RAG 前後對比 chart
- 你的各種分量估算方法比較 chart
- 你最想展示的 1 到 2 個代表性案例
- 你目前 app 的最終 feature scope
- 你最終要強調的 3 個 contribution

把這些補上後，這份框架就可以直接轉成你的正式講稿。