#!/usr/bin/env bash
#
# check_demo.sh — Verifica e recupera o sistema CAPIF antes de uma demo.
#
# Arranca quaisquer containers da stack que estejam parados (sem usar
# docker compose, por isso NÃO mostra os WARN de variáveis), reinicia o
# nginx por último (precisa dos outros serviços de pé) e confirma que a
# porta 443 responde.
#
# Correr:  ./check_demo.sh
#
set -uo pipefail

echo "==> A verificar a stack CAPIF..."

# 1. Arranca todos os containers parados da stack (services-*, register, helper)
parados=$(docker ps -aq --filter "status=exited" --filter "name=services-")
parados="$parados $(docker ps -aq --filter status=exited --filter name=register) $(docker ps -aq --filter status=exited --filter name=helper)"
parados=$(echo $parados | xargs)   # limpa espaços

if [ -n "$parados" ]; then
    echo "==> A arrancar containers parados..."
    docker start $parados >/dev/null 2>&1
    sleep 5
else
    echo "    Nenhum container parado."
fi

# 2. Reinicia o nginx por último (precisa de resolver os upstreams)
echo "==> A reiniciar o nginx..."
docker restart services-nginx-1 >/dev/null 2>&1

# 3. Espera a porta 443 responder (até ~60s — o restart do nginx volta a
#    buscar certificados ao helper, por isso demora mais que um arranque normal)
echo -n "==> A aguardar a porta 443"
for i in $(seq 1 30); do
    # NOTA: curl já imprime "000" via -w quando falha a ligar; NÃO acrescentar
    # outro "|| echo 000", senão o resultado fica "000000" e nunca dá match.
    code=$(curl -sk -o /dev/null -w "%{http_code}" https://localhost:443/test 2>/dev/null)
    code=${code:-000}
    if [ "$code" = "200" ] || [ "$code" = "404" ]; then
        echo " — OK (HTTP $code)"
        break
    fi
    echo -n "."
    sleep 2
done

# 4. Relatório final
up=$(docker ps -q | wc -l)
reg=$(curl -sk -o /dev/null -w "%{http_code}" https://localhost:8084/ 2>/dev/null)
reg=${reg:-000}
echo
echo "==================== ESTADO ===================="
echo "  Containers UP : $up   (esperado: 24)"
echo "  CAPIF :443     : HTTP $code"
echo "  Register :8084 : HTTP $reg"
if [ "$up" -ge 23 ] && { [ "$code" = "200" ] || [ "$code" = "404" ]; }; then
    echo "  ✓ Sistema PRONTO para a demo."
else
    echo "  ✗ Algo ainda não está bem. Vê:  docker ps -a | grep services-"
fi
echo "================================================"
