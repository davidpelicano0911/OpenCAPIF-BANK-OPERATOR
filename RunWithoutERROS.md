O que tens de rodar AGORA (por ordem)
1º — tenta o rápido (~30s): muitas vezes basta re-sincronizar o register com o Vault:


docker restart register
Espera ~20 segundos, depois ./reset_demo.sh e testa o Register no portal. Se passar, está resolvido.

2º — se ainda falhar, o definitivo (~3-5 min) — foi este que funcionou ontem:

fazer ISTO PROVALVELMENTE O ERRO É DISTO SE DESLIGAR O PC O VAULT GERA UM ANOVA CA E TA DIFNETE DO NGNIX 


cd ~/Desktop/OpenCAPIF-BANK-OPERATOR/capif/services
source ./variables.sh
export SERVICES_DIR="$(pwd)"
./clean_capif_docker_services.sh -a && ./run.sh
sleep 30
docker restart register
sleep 20
Depois (em qualquer dos casos), arranca a demo:


cd ~/Desktop/OpenCAPIF-BANK-OPERATOR/capif
./check_demo.sh        # espera "✓ Sistema PRONTO"
./reset_demo.sh        # limpa para o Discovery mostrar 1 API
python3 sim_swap_mock.py     # terminal 1
python3 web_demo/app.py      # terminal 2
E faz um ensaio completo (register→publish, e do lado do banco register→discover→token→check). Se chegar ao fim, está garantido.

