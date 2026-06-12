#!/usr/bin/env bash
#
# reset_demo.sh — Limpa os dados do CAPIF Core antes de uma demo.
#
# Apaga SÓ os documentos das corridas anteriores (providers, APIs publicadas,
# invokers, contextos de segurança). NÃO apaga containers, volumes nem os
# utilizadores do Register — por isso é rápido e seguro de correr antes de
# cada apresentação. O resultado: o Discovery passa a mostrar 1 API, não N.
#
# Correr:  ./reset_demo.sh
#
set -euo pipefail

MONGO_CONTAINER="services-mongo-1"
MONGO_URI="mongodb://root:example@localhost:27017/capif?authSource=admin"

echo "A limpar dados do CAPIF Core (corridas anteriores da demo)..."

docker exec "$MONGO_CONTAINER" mongosh "$MONGO_URI" --quiet --eval '
  ["providerenrolmentdetails","serviceapidescriptions","invokerdetails","serviceapisecurity"]
    .forEach(function (c) {
      var n = db.getCollection(c).deleteMany({}).deletedCount;
      print("  " + c + ": " + n + " documentos apagados");
    });
'

# Limpa também os certificados/chaves gerados pela demo anterior, para o
# Passo 3 voltar a gerar tudo do zero.
rm -rf /tmp/capif_demo
echo "  /tmp/capif_demo apagado (certificados da demo anterior)"

echo "Reset concluido. Discovery vai mostrar exatamente as APIs desta corrida."
