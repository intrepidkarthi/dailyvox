---
slug: can-the-company-read-what-you-tell-its-ai
title: "Can the Company Read What You Tell Its AI?"
meta_description: "Dark, Eternal's new AI, promises it cannot read your chats. Here is how encrypted-server AI differs from on-device AI, and why it matters for a journal."
target_queries: ["Which AI apps cannot read what you tell them?", "Is it safe to tell ChatGPT personal things?", "Is there an AI journal that works without sending my entries to a server?"]
voice: karthik
cluster: privacy
---

# Can the company read what you tell its AI?

On 21 October 2026, Eternal announced an AI assistant called Dark with a one-line pitch: "We cannot read your conversations." Eternal is the company behind Zomato and Blinkit, and Deepinder Goyal named the problem plainly when he launched it. "The uncertainty and the lack of trust we have with large AI companies limits the power of AI in our lives."

He is right about the problem. People hold back with AI. They paste the work email and leave out the part about their manager, or ask about a symptom in the third person. An assistant you don't trust only ever hears an edited version of you.

A journal is the extreme case. It is the one place where the whole point is to say the unedited thing. So the question Dark raises is worth answering properly for journaling: when you tell an app something, which computers end up holding a copy someone can read?

There are three answers, and they are built very differently.

## Architecture one: the provider can read it

This is how most AI chat works today. Your message goes to the company's servers, the model runs there, and the conversation is stored there. Most services let you turn off training on your data.

Goyal made the sharpest point here himself. Opting out of training is a different thing from the company not keeping your conversations. A conversation you opted out of training can still be stored, retained under a policy, reviewed for abuse, handed over under a legal order, or used in some way the terms allow next year. The promise covers one use of the data. The data still exists, readable, on someone else's machine.

For most questions that is a fine trade. You get the largest models available and you pay with exposure.

## Architecture two: the provider holds it but says it can't read it

This is what Dark is selling, as announced. Conversations are end-to-end encrypted and the models run on Eternal's own servers rather than a third-party cloud. An encrypted memory layer that you control lets context carry across sessions. Eternal says it could not read your conversations even if it were forced to. The first users are founders, researchers, enterprises and governments, with a global rollout planned within 2026.

It is not alone. Confer, the encrypted AI chat from Signal's creator, makes a similar promise: it can't read your conversations, train on them or hand them over. Apple's Private Cloud Compute takes a related approach for the Apple Intelligence requests too large to run on an iPhone. Apple says that data is used only for the request and not stored, and it publishes the server software so researchers can inspect it.

This is a large improvement on architecture one, and it keeps the big models. It also moves the trust rather than removing it. Your words still travel to a company's hardware, and the guarantee rests on encryption done correctly, keys held correctly, and an operator that keeps behaving the way it says it will. Some of that can be audited. Some of it can only be believed. Dark has not shipped yet, so for now all of it is a promise.

## Architecture three: no company ever receives it

The third design has no server in the path. The model runs on the phone, the data stays on the phone, and there is nothing to encrypt in transit because nothing is in transit.

DailyVox is built this way, and I built it this way because of journaling specifically. Transcription happens on the device, using Apple's Speech framework on iPhone and the phone's own speech recogniser on Android. Mood tracking runs on the device. The Digital Twin, which learns your patterns from your entries, runs on the device. On iPhones with Apple Intelligence, Ask Your Twin answers questions with Apple's on-device foundation model, and every answer cites the entries it drew from.

There is no account and no backend. The one way an entry leaves your phone is iCloud sync between your own devices, which is off unless you turn it on and runs on Apple's CloudKit. The app's App Store privacy label says "Data Not Collected", and the code is open source under the MIT licence, so anyone can check those claims against what the app actually does.

The cost is real and you should know it before you choose. A model that fits on a phone is much smaller than the ones running in a data centre. DailyVox will not write your essay or debug your code. It is built to listen to you, transcribe you, and help you see your own patterns, and it does that without anyone else in the room.

## Which one should you use?

Match the architecture to what you are saying.

For work questions, research and code, architecture one is usually fine, and architecture two is better if what you paste is sensitive. A founder discussing an unannounced deal is exactly who Dark is aimed at, and an encrypted server is a sensible answer for that.

For the things you would only say to a diary, the bar is different. A journal accumulates years of your most private thinking in one place. Even a provider you trust today is one breach, one acquisition or one policy change away from being a provider you trust less. The only copy nobody can read is the copy nobody else has.

Before you speak into any app, ask where your text goes after you hit save. "Readable on our servers", "encrypted on our servers" and "it never leaves your phone" are three different answers, and the app should be able to tell you which one it is.

## Questions people ask

**Can Dark read my conversations?**
Eternal says it cannot. As announced on 21 October 2026, conversations are end-to-end encrypted and run on Eternal's own servers, and the company says it could not read them even if compelled. The product has not launched publicly yet, so the details of how that is verified are still to come.

**Is it safe to tell ChatGPT personal things?**
It depends on what you mean by safe. Mainstream AI chat services store your conversations on their servers. Turning off training stops one use of the data but does not stop the company keeping it. For anything you would not want stored by a company, use an encrypted service or an app that runs entirely on your device.

**Is there an AI journal that works without sending entries to a server?**
Yes. DailyVox runs transcription, mood tracking and its AI features on your phone, with no account and no backend. The only way an entry leaves the phone is optional iCloud sync between your own devices. It is free and open source on iPhone and Android.

**What is the difference between encrypted AI and on-device AI?**
Encrypted AI still sends your words to the company's servers but protects them so the company says it cannot read them. On-device AI never sends them anywhere. The first gives you larger models and asks you to trust the operator. The second gives you smaller models and asks you to trust nobody.
