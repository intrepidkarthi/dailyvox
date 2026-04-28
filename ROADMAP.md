# DailyVox Roadmap

This roadmap outlines the planned evolution of DailyVox. Contributions are welcome for any upcoming version — check [open issues](https://github.com/intrepidkarthi/dailyvox/issues) or propose your own.

## Shipped

### v1.0 — Core Voice Journal
- Voice journaling with fully on-device transcription (SFSpeechRecognizer)
- Digital Twin personality model (communication style, emotional signature, knowledge graph)
- NLP analysis via NLTagger (sentiment, named entities, topics)
- Core Data storage with optional iCloud sync
- Biometric security (Face ID / Touch ID)
- Widgets (Home Screen & Lock Screen)
- Siri Shortcuts via AppIntents
- AES-256-GCM encrypted exports
- 8 themes, photo attachments, journaling goals

### v1.1 — Twin Predictions
- Twin Predictions: mood forecasting, trigger anticipation, temporal patterns
- Shareable Personality Card for social media
- Weekly Insight Cards
- Improved NLP keyword extraction

### v1.2 — Ask Your Twin *(current)*
- Ask Your Twin: conversational chat with your Digital Twin
- Shareable Personality Cards (Instagram Stories + Twitter/X formats)
- Smarter App Store review prompts

## Planned

### v1.3 — Semantic Search & Proactive Insights
- NLEmbedding for 512-dimensional sentence embeddings
- Semantic search via cosine similarity
- K-means clustering for thematic discovery
- Z-score anomaly detection for unusual entries
- Graph-based semantic indexing (text chunks + knowledge graph entities unified)
- Foundation for on-device RAG pipeline (inspired by [MiniRAG](https://github.com/HKUDS/MiniRAG) architecture)

### v1.4 — Multi-Language & Apple Watch
- Multi-language UI via String Catalogs
- Apple Watch companion app (WatchKit)
- WatchConnectivity for iPhone-Watch sync
- Watch Complications for quick access

### v2.0 — Foundation Models *(iOS 26, iPhone 15 Pro+)*
- Apple Foundation Models integration (on-device 3B LLM)
- LanguageModelSession for multi-turn conversations
- Tool calling for autonomous Core Data queries
- @Generable for type-safe structured outputs
- Multi-tier personality conditioning for Twin conversations (demographic + behavioral + psychometric prompts, inspired by [PersonaTwin](https://arxiv.org/abs/2508.10906))
- SpeechAnalyzer replaces SFSpeechRecognizer
- Zero network calls — entire pipeline on-device

### v2.5 — LoRA Fine-Tuning
- Personal LoRA adapter training on Mac
- ~160 MB adapter delivered via Background Assets
- Train the Twin to sound and think like you
- Export entries as JSONL for training
- Validated Big Five personality scoring from journal narratives (Openness, Conscientiousness, Extraversion, Agreeableness, Neuroticism)
- Scientific personality profile based on [language-based personality modeling research](https://arxiv.org/abs/2506.19258)

### v3.0 — True Digital Self *(vision)*
- Full RAG implementation with personal knowledge base
- Personal LoRA adapter loaded at runtime
- Autonomous tool calling for data access
- Context condensation for long conversations
- Exportable digital self-preservation

---

For technical details, see [ARCHITECTURE.md](ARCHITECTURE.md) and the [Technology page](https://getdailyvox.com/technology.html).
