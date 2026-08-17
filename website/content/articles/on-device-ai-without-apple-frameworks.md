---
slug: on-device-ai-without-apple-frameworks
title: "What On-Device AI Actually Costs Without Apple's Frameworks"
meta_description: "We assumed porting on-device NLP to Android needed three models. Measured in August 2026, a heuristic matched Apple's NER, an MIT lexicon beat its sentiment, and 2.4 MB replaced NLEmbedding."
target_queries: ["on-device ai", "local ai on phone", "run ai locally on phone", "private ai without cloud"]
voice: karthik
cluster: twin
---

# What On-Device AI Actually Costs Without Apple's Frameworks

Apple gives you named-entity recognition, sentiment analysis and sentence embeddings for free, as OS services. Android gives you none of the three. For two years I used that asymmetry as the reason DailyVox would stay iPhone-only: a port "doubles the engineering surface."

In August 2026 I measured it instead of estimating it. The estimate was wrong, and not by a little.

Here is what each of the three actually cost to replace.

## Named entities: no model at all

`NLTagger` finds the people, places and organisations in a journal entry. That is what builds the Twin's knowledge graph, and it looked like the hardest of the three to replace, because NER usually means shipping a model.

It did not need one. A capitalisation-and-recurrence heuristic matched Apple's name detection on our corpus. Capitalised token that is not sentence-initial, appears more than once across entries, is not in a stoplist. That is the whole thing.

Journal text is why this works. A diary is not news copy. The same handful of names recur across weeks, they are capitalised, and there are perhaps thirty of them per person rather than thousands. Recurrence does most of the work a model would otherwise do, and it does it for zero bytes.

I would not ship this heuristic for newswire text. It would fall apart on a corpus of unfamiliar proper nouns appearing once each. Diaries are the friendly case, and knowing which case you are in is most of the engineering.

## Sentiment: the lexicon won

This is the result I did not expect. An MIT-licensed sentiment lexicon **beat** Apple's OS sentiment on our evaluation: r +0.663 against +0.594, correlated against human labels.

Apple's sentiment scorer is a black box tuned for general text. A lexicon is transparent, auditable, and adjustable. When it gets an entry wrong, I can see which word did it and decide whether to change the weight. When `NLTagger` gets one wrong, I can file feedback and wait for iOS 27.

Free and built-in is not the same as better. It took running the numbers to see that, because "Apple provides it" had been doing the work of an argument.

## Embeddings: 2.4 MB

`NLEmbedding` powers search-by-meaning: you type "the week I could not sleep" and get the entries about insomnia, whether or not they use the word. Replacing it looked like the one that genuinely required shipping a model.

A 2.4 MB static embedding table matched it on retrieval. Not a transformer, not runtime inference. A table.

Static embeddings lose to contextual ones on tasks where a word's meaning shifts with the sentence around it. Retrieval over a personal corpus is not that task. You are matching a short query against a few hundred of your own entries, and the vocabulary is small and stable.

2.4 MB is roughly one photograph.

## What this adds up to

The graph and retrieval code was already Foundation-only, so it ports unchanged. Three models became a heuristic, a lexicon and a lookup table. The engineering surface did not double.

None of this makes Android free.

The on-device LLM chat has no Android equivalent worth shipping yet. Apple Intelligence gives iPhones a 3B model in the OS; Android's landscape is fragmented enough that "on-device LLM chat" means different things on different handsets, so it is device-gated and later.

And sync is a real regression. iCloud gives iOS cross-device sync with no server on our side, which is the whole reason DailyVox can claim it runs no backend. Android has no equivalent that preserves that claim, so v1.0 is local-only with export. That is worse for the user, and naming it here is better than having it discovered in a review.

## Why this generalises

If you are deciding whether to build something on-device, the useful question is not "does the platform provide a model" but "what accuracy does my actual corpus need, and what is the cheapest thing that reaches it."

Three times in a row, the cheapest thing was much cheaper than a model, and once it was better. Not because the models are bad, but because a personal corpus is a narrow, repetitive, forgiving target, and general-purpose models are priced for the general case.

Measure your case. The estimate I carried for two years was wrong in the direction that cost the most: it kept a platform closed on the strength of a number nobody had checked.

DailyVox is a free, open-source voice journal that runs its AI entirely on the device. The iOS app is at v1.10; the Android port is in development. The engine measurements above are what changed that decision.
