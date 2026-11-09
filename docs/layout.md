# The layout

The living layout document: per host, its purposes, models, context, slots and load targets, each
figure citing its finding under `docs/findings/`. The answer task finalizes it.

## Hosts

What each host runs and serves. No placement is decided yet: "Serves now" is what the hosts task
left loaded, not a layout decision.

| Host | Stack | Engine and preset | Serves now | Parity | Finding |
| --- | --- | --- | --- | --- | --- |
| gb10-1 | DGX OS 7.6.0, kernel 7.0.0-1025-nvidia, driver 580.178.04, CUDA 13.0, Docker 29.6.2 | llama.cpp `server-cuda13-b12098`, spike-model-engines' shared preset at 3b60fa4 | nothing loaded | the reference GB10 | [hosts](findings/hosts.md): stack, sections A, B, D, E |
| gb10-2 | as gb10-1 | as gb10-1 | set A: gpt-oss-120b MXFP4 (131072 context, 4 slots), gemma-4-26B-A4B QAT, gemma-4-E4B Q8_0, granite-embedding | within run noise of gb10-1 on anchors A and B (means: A −1.37%, B −0.99% output tok/s); cells compare across the two GB10s | [hosts](findings/hosts.md): stack, sections A, B, D, E |
| framework | Omarchy, kernel 7.2.15-1-omarchy, Mesa 26.2.5, Docker 29.9.2 | llama.cpp `server-vulkan-b12098` (moved from b11960, no regression), the same shared preset | set A, as gb10-2 | not compared with the GB10s | [hosts](findings/hosts.md): stack, sections A, B, C |
