這是一份為你重新編排並簡化的講稿。

為符合你的要求，我做了以下調整：
1. **控制時間 (約15分鐘)**：刪減了原本過於冗長和重複的句子。以正常語速（每分鐘約 110-130 字）加上 Demo 時間與自然停頓，這份約 1500 字的講稿大約能順暢地在 12-15 分鐘內講完。
2. **簡單英語詞彙**：將原本複雜的長句（例如從句套從句）拆解為簡短、直接的短句（Active Voice），更適合口語表達，也讓聽眾更容易吸收。
3. **完美對齊 Level 4 評分標準 (Outstanding)**：
   * **Connections to Experience**：在 Slide 3 強調了這個研究源自你真實的個人體驗。
   * **Interdisciplinary Synthesis**：在 Slide 19-22 強烈凸顯你如何完美融合不同學科（NLP、光學、HCI），這是拿高分的關鍵。
   * **Improve Learning Quality (EdTech)**：在 Slide 8 與 Slide 18 強調了 "Human-in-the-loop" 與數據透明度如何提升使用者的批判性思考（Nutrition Literacy），完美扣合 EdTech 的核心價值。
   * **Audience Awareness**：使用清晰簡單的語言本身就是 Level 4 中「展現對受眾的理解，有效傳達複雜內容」的表現。

以下是修改後的講稿：

***

## Slide 1: Title
Hi everyone. Welcome to my presentation on SmartDiet AI. It is an AI-powered diet logging app, but its real purpose goes beyond just making an app. 

I am investigating two core research questions. First, how can we stop AI from making up wrong nutrition facts—a problem called "hallucination"? Second, when AI estimates food portions from photos, which method works best in real life? So, this project is both a working mobile app and a research platform.

## Slide 2: Agenda
Today, I will cover the problem, my research questions, the system design, and the methodology. I will also explain how different disciplines connect in this project. Then, I will show a quick demo, share my evaluation results, and discuss future work.

## Slide 3: The Problem I Noticed
This project started from a personal experience. I once asked different AI tools for the calories in food of the picture. The answers were completely different—ranging from 300 to over 700 calories. 

This made me realize that AI often generates answers without reliable data. It just guesses. As an AI and EdTech student, I know that a tool giving wrong facts cannot be a good learning tool. This inspired me to use RAG (Retrieval-Augmented Generation) to give AI reliable facts, making RAG a fundamental design principle, not just a technical choice.

## Slide 4: Two Core Technical Problems
The project solving two main technical problems.
First: Nutrition Hallucination. Language models often guess nutrition facts. In real life, wrong calorie numbers can mislead users, which is dangerous.
Second: Inaccurate Portion Estimation. Guessing food size from one photo is very hard. It is affected by lighting, camera angle, and plate shape. No single method is perfect for all conditions.

## Slide 5: Why This Matters
I want to emphasize that this is not just an app. It is a research project. I want to answer: Can RAG reduce AI hallucination? And how do different portion estimation methods compare? These two questions drive every design decision I made.

## Slide 6: Research Questions
Here are my formal research questions.
RQ1: Does using RAG with local, official nutrition data reduce hallucination in AI answers?
RQ2: How do different portion estimation methods compare in accuracy, stability, and usability?

## Slide 7: Project Goals
My project goals map directly to these questions. First, to reduce hallucination, I use RAG with the Hong Kong Centre for Food Safety (CFS) data. Second, I compare four portion estimation methods, including ARCore and camera EXIF data. Finally, to maintain reliability, I built a "human-in-the-loop" design, letting users actively correct the AI.

## Slide 8: Contributions
My project has four main contributions.
1. A fully working mobile app.
2. A novel RAG integration using local Hong Kong nutrition data.
3. A multi-method research comparing different portion estimation techniques.
4. An EdTech literacy framework. By showing data sources and letting users edit results, the app encourages users to think critically, rather than just passively accepting AI answers.

## Slide 9: System Architecture Overview
The system has three connected pipelines.
1. The Food Logging Line: It takes a photo, retrieves data, and analyzes it.
2. The Nutrition Knowledge Line: A smart chat assistant that knows your personal health goals and uses RAG to answer questions.
3. The Dashboard: It tracks your daily progress and feeds this data back to the chat assistant to give personalized advice. 
These form a closed, continuous loop.

## Slide 10: Food Logging Pipeline
Let’s look closely at the food logging pipeline. It has three steps.
Step 1: The AI quickly identifies the food name from the photo.
Step 2: The system searches the official CFS database using the food name. I used both text search and semantic search to handle different Chinese naming habits.
Step 3: The system gives the photo, camera data, and the official CFS data to the AI to calculate the final nutrition. 

## Slide 11: Source Transparency
Every result clearly shows its data source. If it matches the database, it says "CFS Official." If not, it says "AI Estimate." Users can also expand the details to see exactly how the AI got the answer. This transparency is crucial for user trust and learning.

## Slide 12: Nutrition Knowledge Line
The second part is the personalized chat assistant. It automatically loads your profile—your height, weight, goals, and recent meals. It uses this context to give you specific, personal advice. When you ask about a food, it also searches the official CFS database to guarantee accurate facts.

## Slide 13: Dashboard and Progress Tracking
The third part is the dashboard. It tracks your daily calories, macros, and meal history. The most important feature is that this dashboard data goes back into the chat assistant. So, the AI can tell you, "You are 400 calories under your target today, here is a dinner idea."

## Slide 14: Methodology — RAG for Hallucination
Now, let's talk about my methodology. I chose RAG based on research papers. Fine-tuning a model bakes the knowledge inside it, which is hard to update and cannot show its sources. RAG is different. It keeps knowledge in an external database. It is easy to update, and you can trace exactly where the facts came from. This is clearly better for nutrition facts.

## Slide 15: RAG Implementation Details
For the RAG database, I used the official Hong Kong Centre for Food Safety data. It covers over 6500 local food items. Using a local, authoritative source is the key to grounding the AI's answers and reducing hallucination.

## Slide 16: Multiple Portion Estimation Methods
For portion estimation research, I tested four approaches.
1. ARCore manual: Gives good 3D data but requires user effort.
2. ARCore plus SAM: More automated, but complex.
3. EXIF plus LLM: Uses camera metadata to calculate real-world size automatically.
4. Pure LLM: Gives the AI no context; it just guesses visually.
My goal is not to find a "perfect" method, but to understand their trade-offs.

## Slide 17: EXIF FOV Calibration
The EXIF method is a very original application. I extract the camera's focal length from the photo's metadata. I use physics formulas to calculate how many centimeters each pixel represents. I then insert this math into the AI prompt. So, instead of purely guessing, the AI now has a quantitative spatial baseline to work with.

## Slide 18: Human-in-the-Loop Design
I deliberately did not make the system 100% automatic. Based on HCI (Human-Computer Interaction) research, a good AI system should maintain human control. In SmartDiet AI, users can manually edit the nutrition results. Showing data sources and allowing manual corrections are core architectural decisions because food analysis is always uncertain.

## Slide 19: Interdisciplinary Integration Overview
This is the parts of how it combines different academic disciplines. As you can see, I synthesized knowledge across NLP, Nutrition Science, Camera Optics, Computer Vision, and HCI to make my design decisions. 

## Slide 20: Integration 1 — NLP × Nutrition Science
First: NLP and Nutrition. Someone with only NLP knowledge wouldn't know which Hong Kong nutrition database to trust. Someone with only nutrition knowledge wouldn't know the difference between RAG and fine-tuning. Combining both allowed me to build a highly traceable, updateable nutrition system.

## Slide 21: Integration 2 — Camera Optics × AI
Second: Camera Optics and AI. Taking geometric formulas from camera EXIF data and converting them into text prompts for a language model is a highly novel idea. It required understanding both physics and prompt engineering to give the AI real spatial context.

## Slide 22: Integration 3 — HCI × Computer Vision
Third: HCI and Computer Vision. Computer Vision find out that estimating food portions is highly uncertain. HCI teaches us that users need control. Synthesizing both led me to the conclusion that "not pursuing full automation" is actually the smartest and safest design choice here.

## Slides 23–28: Key Features
To summarize the key features:
1. The 3-Step RAG pipeline ensures reliable data.
2. Multi-method portion estimation compares different AI techniques.
3. The human-in-the-loop design allows manual editing to fix AI mistakes.
4. The personalized chat gives context-aware advice.
5. The dashboard tracks progress.
6. Finally, my built-in benchmark tool lets me test and compare all these AI methods scientifically.

## Slide 29: Demo
Now, let me show you a quick demo of the complete workflow. 
*(Live Demo)*
Notice how the system handles the full cycle: taking a photo, showing the exact data source, letting the user correct it, saving it to the dashboard, and then using the chat for follow-up guidance. It is a complete, practical loop.

## Slide 30: Evaluation — RQ1
Let's look at the evaluation. For RQ1: Did RAG reduce hallucination? 
Yes. Without RAG, the AI gives generic, sometimes inconsistent answers based on its memory. With RAG, answers are strongly grounded in the official CFS database. It does not eliminate hallucination entirely, but it significantly reduces the risk by making answers traceable and verifiable.

## Slide 31: Evaluation — RQ2
For RQ2: How did the portion estimation methods compare?
My benchmark tool showed that no single method is perfect. ARCore provides a great geometric basis but demands user effort. EXIF is fully automatic and helpful, but depends on device support. Pure LLM is the most convenient but the least stable. The key finding is that human correction is always necessary.

## Slide 32: Representative Cases
When we look at success and failure cases, success usually happens with simple, well-lit foods on plain backgrounds. Failure happens with overlapping dishes, extreme angles, or foods not in the database. This pattern proves why my human-in-the-loop design is a necessity, not just a preference.

## Slide 33: Limitations and Trade-offs
There are limitations. RAG quality depends entirely on the database coverage. Portion estimation always struggles with occlusion and lighting. However, this trade-off is deliberate. The system is designed to be AI-assisted and human-correctable, prioritizing real-world reliability over surface-level automation.

## Slide 34: Future Work
For future work, I plan to expand the RAG sources to more databases. I also want to add barcode scanning for packaged foods and conduct a formal user study to see how this human-in-the-loop workflow improves the educational experience for real users.

## Slide 35: Conclusion
To conclude, SmartDiet AI goes far beyond basic food logging. It successfully mitigates nutrition hallucination using RAG and investigates portion accuracy through multi-method comparison. Most importantly, it shows how we can make AI more reliable, correctable, and suitable for high-uncertainty scenarios in a real working system. 

Thank you. I am happy to take questions.