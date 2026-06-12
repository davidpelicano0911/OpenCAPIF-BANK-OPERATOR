# Plano v2 — UI Web da Demo CAPIF (DOIS PORTAIS separados)

> Visão correta: **um portal para a Operadora**, **um portal para o Banco**, e o
> **CAPIF é o Mongo Express que já existe** (8082/8083). Cada portal mostra só a
> perspetiva desse ator. Os dois só comunicam através do CAPIF (backend partilhado).

---

## Ecrãs (3 janelas lado a lado na apresentação)

```
 PORTAL OPERADORA          CAPIF (já tens)         PORTAL BANCO
 localhost:8090/operadora  Mongo Express :8082     localhost:8090/banco
 ─────────────────         ─────────────────       ─────────────────
 [Registar no CAPIF]       providerenrolment...    [Registar-me]
 [Publicar SIM Swap]       serviceapidescript...   [Descobrir APIs]
                           invokerdetails          [Obter token]
 vê: certificados,         serviceapisecurity      [Verificar cliente]
     API publicada                                 vê: APIs, token, decisão
```

---

## O que se mantém e o que muda

| Ficheiro | Decisão |
|---|---|
| `web_demo/capif_flow.py` | **MANTÉM-SE** (refatorado em ações mais pequenas, uma por botão) |
| `web_demo/app.py` | **ATUALIZA-SE** (serve 2 páginas + endpoints por ator) |
| `web_demo/static/index.html, app.js` | **SUBSTITUÍDOS** por `operadora.html` e `banco.html` |
| `web_demo/static/style.css` | **REAPROVEITADO** (mesmo visual) |
| `demo_capif.py`, `sim_swap_mock.py` | **INTACTOS** (nunca se tocam) |

> Não apago a lógica do backend (`capif_flow.py`) porque é o trabalho que faz os
> pedidos reais ao CAPIF — é a parte valiosa. Só troco a apresentação (frontend).

---

## Backend — ações por portal (endpoints)

Estado partilhado no servidor (um `CapifFlow`) — é isto que liga os dois portais
através do CAPIF, tal como na realidade.

**Portal Operadora:**
- `POST /api/op/register` → cria conta + regista-se no CAPIF + recebe 3 certificados
- `POST /api/op/publish`  → publica a SIM Swap API

**Portal Banco:**
- `POST /api/bk/register` → cria conta + onboard como Invoker (recebe certificado)
- `POST /api/bk/discover` → Discovery (encontra a SIM Swap no catálogo)
- `POST /api/bk/token`    → contexto de segurança + token OAuth2
- `POST /api/bk/check`    → chama o AEF (corpo: número de telefone) → APROVAR/BLOQUEAR
- `POST /api/bk/check-notoken` → mostra o 401 sem token

**Comum:**
- `POST /api/reset` → limpa estado + reset_demo.sh

---

## Fases

### FASE A — Backend refatorado (≈1h)
- Partir os 6 passos do `capif_flow.py` em ações pequenas (register, publish,
  discover, token, check). Cada uma devolve JSON simples para o portal mostrar.
- Testar via curl.

### FASE B — Portal Operadora (≈1h)
- `operadora.html` + JS: dois botões (Registar / Publicar), e um painel que mostra
  em linguagem simples o que aconteceu ("Recebi 3 certificados do CAPIF", "API
  publicada — ID xxx"). Cor azul.

### FASE C — Portal Banco (≈1.5h)
- `banco.html` + JS: botões Registar / Descobrir / Token / Verificar cliente.
- No "Verificar cliente": dois botões (cliente seguro / cliente suspeito) que
  mostram **✅ APROVAR** ou **❌ BLOQUEAR** em grande. Mais "tentar sem token → 401".
- Cor laranja.

### FASE D — Polish (≈1h, opcional)
- Cada portal tem um botão "Abrir CAPIF (MongoDB)" que abre a aba certa do Mongo
  Express, para mostrares onde o dado ficou.
- Mensagens de erro claras (ex: "o CAPIF está em baixo", "a Operadora ainda não
  publicou — não há nada para descobrir").

---

## Como se apresenta (o guião)

1. Abres 3 janelas: **Operadora** | **Mongo Express (CAPIF)** | **Banco**.
2. No portal **Operadora**: clicas "Registar" → "Publicar". Mostras no Mongo Express
   (CAPIF) que a API apareceu.
3. Mudas para o portal **Banco**: "Registar" → "Descobrir" (aparece a API que a
   Operadora publicou!) → "Obter token" → "Verificar cliente".
4. Frase-chave: *"Reparem — o Banco nunca falou com a Operadora. Tudo passou pelo
   CAPIF, que está aqui no meio (Mongo Express)."*

---

## Decisões antes de começar

1. **"Verificar cliente"**: dois botões fixos (seguro / suspeito) ou uma **caixa de
   texto** onde escreves o número? (botões = mais simples para apresentar)
2. **Visual**: mantenho o tema escuro atual (azul/verde/laranja) — confirmas?
3. Apago já os ficheiros antigos (`index.html`, `app.js`) ou deixo-os como estavam?

Assim que confirmares, faço a **Fase A + B** (backend + portal Operadora) para veres
o primeiro portal a funcionar, e depois o do Banco.
