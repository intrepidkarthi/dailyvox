---
slug: retrieval-that-worked-in-demos
title: "Our Retrieval Worked In Demos And Failed On Real Diaries"
meta_description: "v1.7 shipped semantic retrieval that scored 0.02-0.25 on real diary questions against a 0.37 abstention threshold. It abstained on almost everything. Here is how the eval missed it."
target_queries: ["on-device rag", "semantic search personal data", "local ai retrieval", "rag evaluation"]
voice: karthik
cluster: twin
---

# Our Retrieval Worked In Demos And Failed On Real Diaries

In v1.7 we shipped a Twin that could answer free-text questions about your journal using retrieval over your own entries. It demoed well. Then people asked it real questions and it said "I have not found anything about that" to almost all of them.

The retrieval was not broken. It was scoring correctly and the threshold was wrong, and the eval that should have caught it was testing the wrong thing.

## The numbers

Realistic diary questions scored cosine similarity 0.02 to 0.25 against the entries that actually answered them. The abstention threshold was 0.37.

So the system was working exactly as designed, and the design abstained on every real question. A user with three months of entries asking "how was I feeling before the interview" got told there was nothing about it, while the entry describing the interview sat two swipes away.

## Why the demo passed

Demo questions and diary questions are different objects, and we had only ever measured the first kind.

A demo question is written by someone who knows what is in the corpus. It reuses the corpus vocabulary: "what did I write about my anxiety at work". That phrasing shares words and structure with the entry, so the embeddings land close together and the score clears any reasonable threshold.

A real question is written by someone who does not remember what they wrote. "Have I been sleeping badly?" against an entry that says "woke up at 3 again, third time this week, did not mention it to anyone." Those mean the same thing and share almost no surface. Whole-entry cosine on a paragraph like that gets diluted by every sentence not about sleep.

Our eval was built from demo-shaped questions. It measured the case we already knew worked.

## What fixed it

Two changes, and the second one is the one that mattered.

Retrieval became hybrid. Per-sentence max cosine rather than whole-entry, plus content-word overlap. Per-sentence matters because a diary entry is not about one thing. It is about the commute, then a meeting, then not sleeping. Scoring the whole paragraph averages the sleep sentence away. Scoring the best sentence finds it.

Then the threshold was re-measured on a new eval leg authored from this exact failure, by someone who had not read the entries. Re-measured rather than re-tuned. τ landed at 0.29 with 98.2% balanced accuracy. Balanced, because both errors are real. Surfacing an unrelated entry is a Twin that makes things up. Abstaining on a journaled topic is a Twin that is useless. A metric that only counts one of those would have let us ship the same bug with a lower number.

## The part worth stealing

The eval leg is the artefact, not the threshold. 0.29 is specific to our embeddings and our corpus and will not transfer to yours.

What transfers is the method: **write your eval questions before you look at the corpus, or have someone write them who has not read it.** Every retrieval eval built by the person who built the index inherits their memory of what is in it, and that memory is the exact thing your users do not have.

We shipped a system that abstained on almost everything and did not find out from our own tests. We found out from people using it. The eval leg that would have caught it took an afternoon to write, after it was too late to matter.

DailyVox is a free, open-source voice journal that runs its AI on the device. The retrieval described here is what powers search-by-meaning and the Twin's answers, and it runs entirely on the phone.
