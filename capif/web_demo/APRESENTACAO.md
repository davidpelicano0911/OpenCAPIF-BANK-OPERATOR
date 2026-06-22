# Guião de Apresentação — Demo CAPIF (Operadora + Banco)

Guião completo para apresentar a demo: o problema, os intervenientes, o passo-a-passo ao vivo
(com **o que clicar / o que dizer / o que mostrar**), a parte de segurança e a conclusão.

---

## 0. Antes de começar — CHECKLIST (faz isto 10 min antes)

Para a demo **não falhar ao vivo**:

```bash
# 0) DESLIGA a suspensão do portátil durante a apresentação
#    (suspender desliga containers e parte a stack — foi a causa de todos os erros)

# 1) VERIFICAÇÃO AUTOMÁTICA — diz "TUDO PRONTO" ou o que corrigir:
python3 capif/web_demo/check_demo.py

# 2) SE o check acusar containers em baixo (depois de um reboot):
cd capif/services && source variables.sh && export SERVICES_DIR="$(pwd)"
docker compose -f docker-compose-capif.yml up -d
docker restart register          # re-sincroniza o CA ; espera ~25s ; corre o check outra vez

# 3) SE o check acusar "MISMATCH de CA" (raro) — reset definitivo:
cd capif/services && ./clean_capif_docker_services.sh -a && ./run.sh

# 4) Limpar dados e arrancar (só quando o check der TUDO PRONTO):
bash capif/reset_demo.sh
python3 capif/sim_swap_mock.py        # Terminal 2 — deve dizer "verificação de assinatura ON"
python3 capif/web_demo/app.py         # Terminal 3 — deve dizer "mode: SECURE"
```

> **Nota:** todos os containers já têm `restart: unless-stopped`, por isso voltam sozinhos após
> um reboot/suspensão. Mesmo assim, **corre sempre o `check_demo.py`** antes de apresentar.

Abre **dois separadores** no browser, lado a lado:
- `http://localhost:8090/operadora`
- `http://localhost:8090/banco`

E carrega em **Reset system** uma vez, para começar limpo.

> Opcional: abre também o Mongo Express (`http://localhost:8082`) para mostrar os dados reais no CAPIF.

---

## 1. O Problema (30 segundos)

> "Um **Banco** vai aprovar uma transferência. Mas e se o cartão SIM do cliente foi **trocado/clonado**
> há pouco tempo? Isso é um sinal clássico de fraude. O Banco quer perguntar à **Operadora** móvel:
> *este número teve uma troca de SIM recente?*
>
> O problema: o Banco e a Operadora **não se conhecem** nem têm uma ligação direta. Como é que se ligam
> de forma **segura e padronizada**?"

**Resposta: o CAPIF.**

---

## 2. A Solução: CAPIF (1 minuto)

> "O **CAPIF** (Common API Framework, norma 3GPP/GSMA) é como uma **App Store de APIs**: um intermediário
> seguro onde a Operadora **publica** a sua API, o Banco a **descobre** e obtém **autorização** para a usar —
> tudo com **certificados** e **tokens**, sem trocarem passwords nem se conhecerem diretamente."

**Os intervenientes** (mostra a landing page `http://localhost:8090`):

| Ator | Papel | O que faz |
|------|-------|-----------|
| **Operadora** | Provider | Publica a API SIM Swap |
| **Banco** | Invoker (consumidor) | Descobre a API e chama-a |
| **CAPIF Core** | O "mercado" | Catálogo, validação, tokens |
| **Vault** | Autoridade Certificadora | Assina os certificados |

**Os 3 papéis da Operadora** (os 3 certificados) — explica a analogia do restaurante:
- **APF** = põe o prato no **menu** (publica a API)
- **AEF** = **empregado** que serve o prato e **anota** cada pedido (expõe a API + regista invocações)
- **AMF** = **dono** que à noite **lê o caderno** (audita quem usou a API)

---

## 3. DEMO AO VIVO — passo a passo

### Parte A — A Operadora publica a API (separador Operadora)

**Passo 1 — clica "1 Register with CAPIF Core"**
- **Dizer:** "A Operadora regista-se no CAPIF. Gera 3 chaves privadas localmente — que **nunca saem da máquina** — e o CAPIF assina 3 certificados: APF, AEF, AMF."
- **Mostrar:** os 3 chips `APF / AEF / AMF certificate` e os códigos `200/200/201`. Aponta para o terminal: "a chave privada nunca sai daqui".

**Passo 2 — clica "2 Publish SIM Swap API"**
- **Dizer:** "Agora a Operadora publica a API no catálogo, autenticando-se com o **certificado APF** (mTLS), já não com password."
- **Mostrar:** o `201`, o **API ID**, e abre o Mongo Express → `capif > serviceapidescriptions` para ver a API publicada de verdade.

### Parte B — O Banco descobre e usa a API (separador Banco)

**Passo 3 — clica "1 Register as Invoker"**
- **Dizer:** "O Banco regista-se como consumidor. Também gera a sua chave e recebe um certificado do CAPIF."

**Passo 4 — clica "2 Discover APIs"**
- **Dizer:** "O Banco pergunta ao CAPIF que APIs existem — e **descobre a SIM Swap sem nunca ter falado diretamente com a Operadora**. É a magia do CAPIF."
- **Mostrar:** a API "SIM_Swap" encontrada.

**Passo 5 — clica "3 Get access token"**
- **Dizer:** "O Banco pede um **token OAuth2** ao CAPIF — a credencial que prova que está autorizado a usar a API."
- **Mostrar:** o token e o `200`.

**Passo 6 — escreve um número e clica "Check"** (o momento alto 🎯)
- Testa **`+351912345678`** → **TRANSACTION APPROVED** (SIM intacto, transação segura)
- Testa **`+351911111111`** → **TRANSACTION BLOCKED** (SIM trocado = possível fraude)
- **Dizer:** "O Banco chama a API com o token. A Operadora responde se houve troca de SIM, e o Banco **decide** aprovar ou bloquear. Foi assim que evitámos a fraude."

### Parte C — A Operadora audita o uso (separador Operadora)

**Passo 7 — clica "3 Audit invocations (AMF)"**
- **Dizer:** "Por fim, a Operadora usa o **terceiro certificado, o AMF**, para auditar o CAPIF: ver **quem** chamou a sua API, **quando**, e com que resultado. O AEF escreveu estes registos a cada chamada; o AMF agora lê-os."
- **Mostrar:** a lista de invocações (uma por cada Check) e o "Show raw data (JSON)".

---

## 4. Segurança — os 2 mecanismos (1 minuto)

> "Repararam que **nunca usámos passwords** depois do registo inicial? A segurança assenta em duas coisas:"

1. **mTLS (certificado)** — Operadora e Banco identificam-se com **certificados**, não passwords.
2. **OAuth2 (token)** — para chamar a API, é preciso um **token** emitido pelo CAPIF.

**Prova ao vivo — token forjado** (mostra que a API rejeita um token falso):
```bash
curl -s -X POST http://localhost:9200/sim-swap/check \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiJ9.eyJzY29wZSI6IjNncHAjYWVmOlNJTV9Td2FwIn0.AAAA" \
  -H "Content-Type: application/json" -d '{"phoneNumber":"+351912345678"}'
```
- **Resultado:** `401` "Assinatura do token inválida".
- **Dizer:** "A API verifica a **assinatura** do token contra a chave pública do CAPIF. Um token forjado é rejeitado — sem token válido, não há acesso."

---

## 5. A barra de estado partilhado (mostrar de passagem)

> "Reparem na barra no topo dos dois portais: quando a Operadora publica, o separador do Banco **também
> reflete** isso. É a prova de que ambos comunicam **através do CAPIF** — um estado partilhado, não uma
> ligação direta."

---

## 5b. Provas de segurança (scripts opcionais, para "mostrar a sério")

Para além da demo nos portais, há **3 scripts** que provam a segurança ao nível dos bytes.
Correm contra o **stack real** (precisam do CAPIF de pé; a PROVA 3 precisa do mock na :9200).

```bash
python3 capif/web_demo/provas_seguranca.py        # as 3 provas juntas
# (ou individualmente:)
python3 capif/web_demo/verify_tls_demo.py         # o "diálogo" TLS
python3 capif/web_demo/verify_signature_debug.py  # os 2 hashes da assinatura
```

**O que o `provas_seguranca.py` deve dar:**

| Prova | O que mostra | Resultado esperado |
|---|---|---|
| **1 — TLS** | valida o cert do `capifcore` (nome + cadeia) | TESTE 1 ✅ passa; TESTE 2 (nome errado) ❌; TESTE 3 (sem CA) ❌ |
| **2 — Assinatura** | os 2 hashes (calculado vs aberto da assinatura) | `hash A == hash B → True ✅` |
| **3 — Token forjado** | o mock rejeita um token com assinatura inválida | **HTTP 401** ✅ |

**O que dizer:**
> "Estes scripts abrem a 'caixa preta' da segurança: a PROVA 1 mostra que mudar o nome ou tirar o CA
> faz a validação do certificado falhar; a PROVA 2 mostra os dois hashes a serem comparados na
> verificação da assinatura; e a PROVA 3 mostra a API a rejeitar um token forjado com 401."

> ⚠️ A PROVA 3 só corre com o `sim_swap_mock.py` ligado. Sem ele, aparece "[saltado]".

---

## 6. Conclusão (30 segundos)

> "Resumindo, demonstrámos o **ciclo de vida completo de uma API no CAPIF**:
> 1. A Operadora **publica** (APF)
> 2. O Banco **descobre** e **autoriza-se** (token OAuth2)
> 3. O Banco **consome** a API e o **AEF regista** a invocação
> 4. A Operadora **audita** o uso (AMF)
>
> Tudo de forma segura (mTLS + OAuth2), padronizada (3GPP), e **sem que Banco e Operadora se conheçam
> diretamente**. Aplicámos isto a um caso real e útil: **prevenção de fraude bancária por SIM swap**."

---

## Mapa rápido do fluxo (para um slide)

```
OPERADORA                         CAPIF Core                          BANCO
─────────                         ──────────                          ─────
1. Register ───3 CSRs───────────► assina APF/AEF/AMF
2. Publish (APF cert) ──────────► catálogo  ◄──── 4. Discover ─────── 3. Register (invoker)
                                  emite token OAuth2 ───────────────► 5. Get token
                                                                       6. Check (número)
   Mock :9200 ◄──── chama a API (token OAuth2) ──────────────────────┘
   AEF escreve log ───────────► invocation logs
7. Audit (AMF cert) ───────────► lê os logs
```

---

## Perguntas que te podem fazer (e respostas curtas)

- **"Porque é que o número bloqueado também dá HTTP 200 no log?"**
  Porque `result` é o **código HTTP** (a chamada funcionou), não a decisão. APPROVE/BLOCK é decisão do
  banco com base na resposta (`swapped`), não um erro HTTP.

- **"O AMF tem de estar na Operadora?"**
  Sim — APF/AEF/AMF são funções do **Provider** (dono da API). Quem quer auditar o uso é o dono, não o consumidor.

- **"Inventaram os papéis APF/AEF/AMF?"**
  Não. São definidos pela norma CAPIF (`ApiProviderFuncRole` no servidor). O nosso código só os **pede** e **usa**.

- **"A chave privada vai para o CAPIF?"**
  Nunca. Só enviamos o CSR (chave pública). A privada fica sempre na máquina.
