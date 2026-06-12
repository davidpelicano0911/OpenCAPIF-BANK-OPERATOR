https://labs.etsi.org/rep/ocf/capif.git



# Final Demo — OpenCAPIF (guia completo)

> Guia único para perceber, correr e apresentar a demo do OpenCAPIF.
> Tecnologia: **CAPIF — Common API Framework do 3GPP (TS 29.222)**, a norma que
> permite a uma operadora 5G expor APIs da sua rede a empresas externas com segurança.

## Índice
1. [A história (panorama geral)](#1-a-história)
2. [A SEGURANÇA explicada (certificados e tokens)](#2-a-segurança-explicada)
3. [O fluxo passo a passo](#3-o-fluxo-passo-a-passo)
4. [O que mostrar e dizer na apresentação](#4-o-que-mostrar-e-dizer)
5. [Perguntas prováveis do professor](#5-perguntas-prováveis)
6. [Como correr tudo + links](#6-como-correr-tudo)
7. [Resumo de segurança (cábula)](#7-resumo-de-segurança-cábula)

---

## 1. A história

Três protagonistas:

| Quem | Papel | O que faz |
|---|---|---|
| **Operadora** (Provider) | tem a API | publica a API de SIM Swap |
| **Banco** (Invoker) | quer a API | descobre-a e usa-a para evitar fraude |
| **CAPIF** | o porteiro | controla quem publica e quem acede |

**Caso de uso real:** o Banco vai aprovar uma transferência. Se o SIM do cliente foi
**trocado há pouco**, pode ser um burlão que clonou o número para receber os SMS de
confirmação. O Banco pergunta à API da Operadora: *"este número teve troca de SIM
recente?"* → se sim, **bloqueia**; se não, **aprova**. O CAPIF é o que permite ao
Banco aceder a essa informação da rede, de forma segura e controlada.

---

## 2. A SEGURANÇA explicada

Há **três camadas**, cada uma serve para uma coisa diferente e num momento diferente.

### Camada 1 — JWT (o crachá de entrada)
- **É** um crachá temporário (`eyJ...`) que prova *"fiz login, sou um utilizador válido"*.
- **Analogia:** mostras o BI na receção e dão-te um crachá de visitante.
- **Quando:** no início, quando a Operadora/Banco fazem login no **Register**.
- É temporário (expira) e assinado (não se falsifica).

### Camada 2 — Certificados / mTLS (o cartão de identidade)

Um certificado tem **duas peças em par**:

| Peça | É | Analogia |
|---|---|---|
| **Chave privada** (`.key`) | segredo que SÓ tu tens | a tua assinatura à mão |
| **Certificado** (`.crt`) | documento público, carimbado por uma autoridade | o cartão de cidadão |

**mTLS** = TLS mútuo: tal como um site HTTPS mostra certificado ao browser, no mTLS
**os dois lados** mostram certificado — o cliente também prova quem é.

**Como nasce o certificado (o passo que confunde):**
```
A entidade (na máquina dela)            O CAPIF
1. Gera a chave privada (.key)
   → fica SÓ na máquina, secreta
2. Cria um CSR (pedido de assinatura,
   só a parte PÚBLICA)
                  ── envia o CSR ──►
                                     3. Assina-o com a sua
                                        autoridade (o Vault)
                  ◄── devolve o .crt ─
5. Guarda o certificado assinado
```
- **A chave privada NUNCA sai da máquina.** Só se envia o pedido (parte pública).
- **Vault** = a autoridade certificadora do CAPIF (o "carimbo oficial").
- **ca.crt** = cópia do carimbo, usada para **verificar** que um certificado é autêntico.
- **Quando se usa:** em todas as ações de gestão (publicar, descobrir, pedir token).
- **Resumo:** mTLS prova **QUEM ÉS**, com certificado em vez de password.

### Camada 3 — Token OAuth2 (o bilhete para uma sala específica)
- O certificado prova **quem és**, mas não **a que tens direito**. Para isso, o token.
- **É** um bilhete de acesso temporário com um **scope** (ex: `SIM_Swap`).
- **Analogia:** tens o cartão de cidadão (mTLS), mas para o concerto precisas de um
  bilhete específico (OAuth2) que diz "válido para a sala SIM_Swap".
- **Quando:** o Banco pede o token ao CAPIF e mostra-o ao **chamar a API**.
- **Resumo:** OAuth2 prova **O QUE PODES FAZER**.

### As 3 camadas juntas
```
JWT (login) → mTLS (identidade) → OAuth2 (acesso) → chamada à API
```
| Camada | Prova... | Quando |
|---|---|---|
| JWT | "fiz login" | registo inicial |
| mTLS | "sou esta entidade" | publicar / descobrir |
| OAuth2 | "tenho direito a esta API" | cada chamada à API |

---

## 3. O fluxo passo a passo

### Lado da OPERADORA
**1 — Registar-se no CAPIF**
- Faz login (recebe **JWT** + `ca.crt`), gera 3 pares de chaves (APF=publica,
  AEF=expõe, AMF=gere) e envia 3 CSRs. O CAPIF assina e devolve **3 certificados**.
  → Camada 2 (mTLS) criada.

**2 — Publicar a API**
- Usa o certificado do **APF** e publica a ficha da API no catálogo: nome, onde está
  o servidor (`127.0.0.1:9200`), segurança exigida (OAuth2). Fica no catálogo.

### Lado do BANCO
**3 — Registar-se como Invoker** → recebe o seu certificado.

**4 — Descobrir APIs** → pergunta ao CAPIF "que APIs existem?" e encontra a SIM Swap
**sem nunca ter falado com a Operadora** (como a App Store).

**5 — Obter token** → pede um **token OAuth2** com scope `SIM_Swap`. → Camada 3 criada.
A verificação de fraude **desbloqueia** (antes estava trancada: sem token, sem acesso).

**6 — Verificar cliente** → chama o servidor da Operadora **diretamente** (não passa
pelo CAPIF), com o token:
- número sem troca → **APPROVE** (transação segura)
- número com SIM trocado → **BLOCK** (risco de fraude)

> **Importante:** o CAPIF **não transporta** a chamada final — só emitiu o token. A
> chamada vai direta do Banco à Operadora. O OpenCAPIF só faz a *gestão*, não faz
> proxy de tráfego — por isso o servidor da Operadora é simulado pelo `sim_swap_mock.py`.

---

## 4. O que mostrar e dizer

Três ecrãs lado a lado: **Operadora** | **CAPIF (MongoDB)** | **Banco**.

1. **Operadora → Register:** *"Regista-se e recebe 3 certificados. A partir daqui
   autentica-se por certificado, não por password — isto é mTLS."*
2. **Operadora → Publish:** *"Publica a API no catálogo, usando o certificado."*
   → mostra no **MongoDB** a API a aparecer em `serviceapidescriptions`.
3. **Banco → Register:** *"O Banco regista-se e recebe o seu certificado."*
4. **Banco → Discover:** *"Descobre a API que a Operadora publicou — sem falar com ela.
   O CAPIF é o intermediário."*
5. **Banco → Get token:** *"Pede um token OAuth2. A verificação estava trancada e
   desbloqueou — sem token não há acesso. Isto é o controlo de acesso do CAPIF."*
6. **Banco → caixa de texto:** `+351912345678` → **APPROVE**; `+351911111111` →
   **BLOCK**. *"Chama a API com o token. SIM intacto: aprova. SIM trocado ontem: bloqueia."*

**Frase de fecho:**
> *"Demonstrei o ciclo completo de uma API de rede 5G: publicar, descobrir, autorizar
> e aceder — com três camadas de segurança (JWT, mTLS, OAuth2). E o Banco nunca falou
> diretamente com a Operadora: tudo passou pelo CAPIF, o porteiro."*

---

## 5. Perguntas prováveis

1. **"Verificas a assinatura do token?"** → *"Valido o scope; numa operadora real
   verificaria também a assinatura do token contra a chave pública do CAPIF."*
2. **"Porque é que a chamada à API não passa pelo CAPIF?"** → *"O OpenCAPIF só
   implementa o plano de gestão, não faz proxy de tráfego."*
3. **"Qual é a utilidade?"** → *"Sem o CAPIF, cada operadora teria o seu próprio
   sistema de registo, segurança e catálogo. O CAPIF é o standard do 3GPP que unifica
   isto — a App Store das APIs de rede 5G."*

---

## 6. Como correr tudo

### Pré-requisito: o sistema CAPIF tem de estar de pé
```bash
cd ~/capif
./check_demo.sh        # arranca/repara o CAPIF; espera "✓ Sistema PRONTO"
```

### Opção A — Interface web (os 2 portais) — recomendada
```bash
# Terminal 1 — o servidor da Operadora (deixa a correr)
python3 sim_swap_mock.py

# Terminal 2 — os portais web
python3 web_demo/app.py
```
Depois abre no browser:

| Ecrã | Link |
|---|---|
| Página inicial (3 links) | http://localhost:8090 |
| Portal da Operadora | http://localhost:8090/operadora |
| **CAPIF — dados (MongoDB)** | http://localhost:8082  (login `admin` / `admin`) |
| Portal do Banco | http://localhost:8090/banco |

> Antes de cada apresentação corre `./reset_demo.sh` para limpar corridas anteriores.

### Opção B — Terminal (plano B, sempre funciona)
```bash
# Terminal 1
python3 sim_swap_mock.py
# Terminal 2
./reset_demo.sh && python3 demo_capif.py
```

### Se algo correr mal
- **"400 SSL certificate" ao publicar** (a CA dessincronizou, ex: o PC suspendeu):
  ```bash
  cd ~/capif/services && source ./variables.sh && ./clean_capif_docker_services.sh -a && ./run.sh && sleep 30 && docker restart register && sleep 15
  ```
- **"Connection refused"** → o sistema está em baixo: corre `./check_demo.sh`.
- **Regra de ouro:** desliga a suspensão automática do portátil antes de apresentar.

### Documentação detalhada (pasta `docs/`)
| Ficheiro | O que é |
|---|---|
| `docs/GUIA_DEMO.md` | Guia técnico completo (passo a passo detalhado) |
| `docs/GUIAO_DEMO_AO_VIVO.md` | Narração a ler durante a apresentação |
| `docs/NOTAS_PASSOS.md` | Notas + diagramas Mermaid de cada passo |
| `docs/PLANO_SLIDES.md` | Estrutura slide-a-slide para o PPT |
| `docs/APRESENTACAO_PROFESSOR.md` | Versão de leitura corrida |
| `docs/PLANO_UI_WEB.md` | Plano da interface web (os 2 portais) |

---

## 7. Resumo de segurança (cábula)

**A frase-mãe:** *mTLS prova QUEM ÉS; OAuth2 prova O QUE PODES FAZER.*

| Conceito | O que é (1 frase) | Para que serve na demo |
|---|---|---|
| **JWT** | crachá temporário que prova que fizeste login | registar a Operadora e o Banco no início |
| **Certificado** | cartão de identidade digital (`.crt` público + `.key` privada) | autenticar as entidades sem password |
| **mTLS** | TLS em que **os dois lados** mostram certificado | provar a identidade ao publicar/descobrir |
| **CSR** | pedido de assinatura (só a parte pública da chave) | é o que se envia ao CAPIF para ele assinar |
| **Vault (CA)** | autoridade certificadora — o "carimbo oficial" | assina todos os certificados do sistema |
| **ca.crt** | cópia do carimbo da CA | verificar que um certificado é autêntico |
| **OAuth2 token** | bilhete de acesso com um *scope* | autorizar a chamada à SIM Swap API |
| **scope** | o que o token autoriza (ex: `SIM_Swap`) | limita o token a uma API específica |

**O que o mTLS é, mesmo:** em vez de password, cada entidade tem um certificado
(emitido e assinado pelo CAPIF). Ao ligar-se, apresenta-o; o CAPIF verifica que foi
ele que o assinou (com o `ca.crt`). A chave privada nunca sai da máquina. É mais
seguro que passwords e é o que o 3GPP exige para estas APIs.

**O que o OAuth2 é, mesmo:** depois de identificada (mTLS), a entidade ainda precisa
de *autorização* para uma API concreta. Pede um token ao CAPIF com o scope dessa API.
O token é um JWT assinado pelo CAPIF. Ao chamar a API, mostra o token; o servidor
valida-o. Sem token válido → 401 (bloqueado). É isto que demonstras quando a
verificação de fraude só desbloqueia depois de obteres o token.

**Porque três camadas?** Cada uma resolve um problema diferente:
- JWT → "tens conta?" (entrada no sistema)
- mTLS → "és mesmo quem dizes?" (identidade forte por certificado)
- OAuth2 → "podes usar ESTA API?" (autorização por recurso)

Juntas, garantem que só entidades registadas, identificadas e autorizadas acedem às
APIs de rede 5G — que é exatamente o que o CAPIF promete.
