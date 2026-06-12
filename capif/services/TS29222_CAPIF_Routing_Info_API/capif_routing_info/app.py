#!/usr/bin/env python3

import connexion
import encoder

app = connexion.App(__name__, specification_dir='openapi/')
app.app.json_encoder = encoder.CustomJSONEncoder
app.add_api('openapi.yaml',
            arguments={'title': 'CAPIF_Routing_Info_API'},
            pythonic_params=True)
