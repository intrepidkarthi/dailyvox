---
slug: llm-that-cannot-cite-what-it-did-not-read
title: "Building An On-Device LLM That Cannot Cite What It Did Not Read"
meta_description: "Prompting a local model to avoid hallucinating is a request. We made it structurally impossible instead, with a deterministic audit that rejects any answer before it renders."
target_queries: ["on-device llm", "local llm hallucination", "private ai personal data", "apple foundation models app"]
voice: karthik
cluster: twin
---

# Building An On-Device LLM That Cannot Cite What It Did Not Read

Apple Intelligence puts a 3B model on the phone, which means an app can run a real conversation over your private data with nothing leaving the device. We used it to let people ask their journal questions in their own words.

The privacy problem is solved by the architecture. The honesty problem is not. A local model invents things at roughly the rate a hosted one does, and it invents them about your life, which is worse than inventing them about the world. You can check a wrong claim about the boiling point of water. You cannot easily check "you have seemed more anxious since March" when you do not remember March.

Prompting the model to be careful is a request. We wanted a property.

## Citation as a structural constraint

The answer is not free text that we then inspect. It is assembled from units, and every factual sentence must attach to either a retrieved entry or a measured Twin signal. A sentence with nothing to attach to cannot be emitted, because there is no slot for it.

That is the difference between "the model was told not to make things up" and "there is no path by which a claim reaches the screen without a source." The first is a prompt. The second is a shape.

The visible result is the citation chips under each answer — tap one and it opens the exact entry. Those are not decoration added afterward. They are the thing the sentence was built from.

## The audit runs on every answer

Structure is not enough on its own, because a structure can have a bug. So a deterministic audit checks every answer before it renders: does every claim cite something, does every cited ID exist in what was actually retrieved this turn, does every number appear verbatim in the source it points at.

Deterministic matters. It is not a second model grading the first, which would just be two things that can both be wrong in correlated ways. It is a check with a yes and a no.

An answer that fails never appears. The app falls back to the older template chat, which is less impressive and cannot lie. A user sees a slightly worse answer; they do not see a confident wrong one.

## Numbers are copied, never generated

Any figure in an answer is copied verbatim from the data it cites. The model is not permitted to compute, round, or restate a number.

This sounds over-strict until you watch a language model round "eleven entries in fourteen days" to "almost every day." Both describe the same fortnight. One of them is a claim about your life that your data does not support, and it is the kind of error nobody catches, because it reads more naturally than the truth.

## What it is tested against

An adversarial battery, and the release had to pass it twice consecutively before shipping: grounding, tone, false-premise resistance, prompt-injection resistance.

False premise is the interesting one for personal data. Ask "why have I been so angry lately" when the entries show nothing of the kind, and the accommodating answer is to explain an anger that does not exist. The model has to decline the premise, which is exactly the behaviour a helpful-sounding assistant is worst at.

Prompt injection matters because the corpus is user-authored. If someone writes instructions into their own diary, or pastes something that contains them, those words arrive in the context window like any other entry.

## The honest limit

Every one of these constraints costs range. The Twin will not speculate, will not synthesise across entries in ways it cannot cite, and abstains often enough that some people find it terse.

That is the deal. For an app whose whole claim is that your journal is private and the model is local, a system that occasionally makes something up about your inner life would cost more than it returns. The interesting engineering was not making the model smarter. It was removing the paths by which it could be wrong.

DailyVox is a free, open-source voice journal for iPhone. Conversational answers run on Apple's on-device foundation model where available, and every mechanism described here runs on the phone.
