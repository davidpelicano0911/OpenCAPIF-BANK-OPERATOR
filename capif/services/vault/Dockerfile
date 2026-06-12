FROM vault:1.13.2

# Instalar paquetes adicionales
RUN apk add --no-cache jq openssl

# Copiar archivos adicionales (si los tienes)
COPY ./vault_prepare_certs.sh /vault_prepare_certs.sh

RUN chmod a+x /vault_prepare_certs.sh


CMD sh -c "vault server -dev / & sleep 5 && /vault_prepare_certs.sh && tail -f /dev/null"
