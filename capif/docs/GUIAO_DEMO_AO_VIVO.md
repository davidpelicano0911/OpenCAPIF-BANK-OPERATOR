# Guião da Demo ao Vivo — o que dizer em cada passo

> Lê isto enquanto a demo corre ao lado. Para cada passo: **o que dizer** + **o que mostrar**.
> Slides em inglês, narração em português (mistura normal na academia).

---

## ANTES de começar (preparação)

```bash
cd ~/capif
./check_demo.sh                 # espera "✓ Sistema PRONTO"
# Terminal 1:
python3 sim_swap_mock.py        # deixa a correr
# Terminal 2:
./reset_demo.sh                 # limpa corridas anteriores
python3 demo_capif.py           # corre a demo (pára em cada passo)
```

Ecrã: **slide à esquerda**, **terminal + browser MongoDB (http://localhost:8082, admin/admin) à direita**.

**Frase de abertura (antes do Passo 1):**
> "Vou demonstrar o OpenCAPIF — a implementação oficial da ETSI do framework 3GPP que permite a uma operadora 5G expor APIs da sua rede a empresas externas, de forma segura. A história: uma Operadora publica uma API de deteção de fraude (SIM Swap), e o Banco Itaú usa-a para proteger transações. O CAPIF é o porteiro. Vou fazer o ciclo completo em 6 passos."

---

## PASSO 1 — Verificar o sistema

**O que dizer:**
> "O sistema tem duas portas de entrada: o **Register**, na porta 8084, que é o balcão onde se criam contas; e o **CAPIF Core**, na porta 443, que é o porteiro que faz todo o trabalho — registos, catálogo, segurança e tokens. São 23 containers Docker, todos imagens oficiais da ETSI. Faço dois pings para confirmar que está tudo vivo."

**O que mostrar:** o terminal com os dois ✓; depois o browser do MongoDB **vazio** — "começamos do zero".

---

## PASSO 2 — Criar utilizadores

**O que dizer:**
> "Crio as duas personagens: a Operadora, que vai publicar a API, e o Banco, que a vai consumir. Como sou uma pessoa só, simulo as duas — mas as mensagens são exatamente as que duas empresas reais trocariam. Primeiro faço login como admin e recebo um token JWT; com ele crio as duas contas. Esta é a primeira camada de segurança: o JWT."

**O que mostrar:** terminal (201, 201); browser → BD `capif_users` → coleção `user` → os 2 utilizadores.

---

## PASSO 3 — Operadora regista-se (mTLS)

**O que dizer:**
> "A Operadora regista-se no CAPIF. O ponto importante: ela gera as chaves privadas no próprio computador — nunca saem da máquina. Só envia pedidos de assinatura. O CAPIF assina-os com a sua autoridade certificadora, o Vault, e devolve-lhe certificados. Isto é a segunda camada de segurança: mTLS. A partir daqui a Operadora prova quem é com um certificado, não com password. Ela recebe três certificados — um por cada função: publicar, expor e gerir."

**O que mostrar:** terminal (201 + 3 certificados); browser → BD `capif` → `providerenrolmentdetails`.

---

## PASSO 4 — Publicar a API

**O que dizer:**
> "Agora a Operadora publica a API SIM Swap no catálogo, autenticando-se com o certificado que acabou de receber — mTLS em ação. Ela diz ao CAPIF o nome da API, onde está o servidor e que segurança exige. O CAPIF guarda esta ficha. É como pôr uma app na loja: a partir de agora a API está no catálogo, à espera de ser descoberta."

**O que mostrar:** terminal (201 + api_id); browser → `capif` → `serviceapidescriptions` → a SIM Swap.

---

## PASSO 5 — Banco regista-se e descobre a API (Discovery)

**O que dizer:**
> "Mudo de personagem: agora sou o Banco. Faço o mesmo registo e recebo o meu certificado. Depois a parte mais interessante: o Discovery. Pergunto ao CAPIF 'que APIs existem?' e encontro a SIM Swap — sem nunca ter falado com a Operadora. O CAPIF é o intermediário, como uma App Store que liga quem oferece a quem procura."

**O que mostrar:** terminal (201 + Discovery 200, "APIs encontradas: 1"); browser → `capif` → `invokerdetails`.

---

## PASSO 6 — Token OAuth2 e decisão de negócio (o ponto alto)

**O que dizer:**
> "O passo final. O Banco pede ao CAPIF um token OAuth2 — a terceira camada de segurança — com âmbito só para esta API. Recebe um token assinado pelo CAPIF, o 'bilhete'. Depois chama o servidor da Operadora diretamente. E vejam o impacto real:
> — O primeiro cliente tem o SIM intacto → a API responde 'não houve troca' → o banco **APROVA** a transação.
> — O segundo cliente teve o SIM trocado ontem → a API responde 'cuidado' → o banco **BLOQUEIA**, porque pode ser um fraudador a clonar o número.
> — E se eu tentar chamar **sem token** → **401**, barrado.
> Isto é o controlo de acesso do CAPIF a funcionar, a proteger uma transação bancária real com informação da rede 5G."

**O que mostrar:** terminal (token 200; cliente seguro → APROVAR; cliente suspeito → BLOQUEAR; sem token → 401); browser → `capif` → `serviceapisecurity`. **Mostra também o terminal do mock** (os logs 200/200/401).

---

## FECHO

**O que dizer:**
> "Em resumo: demonstrei o ciclo de vida completo de uma API de rede 5G no CAPIF — registar, publicar, descobrir, autorizar e chamar — com três camadas de segurança empilhadas: JWT no login, mTLS com certificados nos registos, e OAuth2 em cada chamada. Tudo contra a implementação oficial da ETSI, e a resolver um problema real de prevenção de fraude. O CAPIF é o standard do 3GPP que torna isto possível de forma segura e uniforme entre qualquer operadora e qualquer empresa. Obrigado."

---

## Se algo correr mal (plano B)

- **Erro "400 SSL certificate" no Passo 4** → a CA dessincronizou (suspensão do PC). Corre:
  ```bash
  cd ~/capif/services && source ./variables.sh && ./clean_capif_docker_services.sh -a && ./run.sh && sleep 30 && docker restart register && sleep 15
  ```
- **"Connection refused" no Passo 1** → sistema em baixo. Corre `./check_demo.sh`.
- **Discovery mostra a API várias vezes** → esqueceste o `./reset_demo.sh`. Corre-o e repete.

**Regra de ouro:** desliga a suspensão automática do portátil ANTES da apresentação.

---

## As 3 perguntas prováveis do professor

1. **"Validas a assinatura do token?"** → "Valido o scope; numa operadora real verificaria também a assinatura do JWT contra a chave pública do CAPIF. Documentei isso no código."
2. **"Porque é que a chamada à API não passa pelo CAPIF?"** → "O OpenCAPIF community implementa só o plano de gestão, não faz proxy de tráfego. Por isso o servidor da operadora é uma peça separada, que eu simulo com um mock."
3. **"Qual é a utilidade disto?"** → "Sem o CAPIF, cada operadora teria o seu próprio sistema de registo, segurança e catálogo. O CAPIF é o standard do 3GPP que unifica isso — a 'App Store' das APIs de rede 5G. As entidades eu simulo; o CAPIF é real e é a estrela."
